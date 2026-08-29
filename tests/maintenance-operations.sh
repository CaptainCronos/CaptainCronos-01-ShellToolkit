#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_DIR="$(mktemp -d)"

cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_contains() {
    local file="$1" expected="$2" label="$3"
    grep -Fq -- "$expected" "$file" || fail "$label"
}
assert_matches() {
    local file="$1" pattern="$2" label="$3"
    grep -Eq -- "$pattern" "$file" || fail "$label"
}

init_repo() {
    local repo="$1"
    git init -q -b main "$repo"
    git -C "$repo" config user.name "Maintenance Fixture"
    git -C "$repo" config user.email "maintenance@example.invalid"
    printf 'fixture\n' >"$repo/README.md"
    git -C "$repo" add README.md
    git -C "$repo" commit -qm "test: initialize fixture"
}

run_cc_in() {
    local repo="$1"
    shift
    (cd "$repo" && CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" bash "$PROJECT_ROOT/tools/cc" "$@")
}

# Current-repository commands distinguish clean, dirty, detached, missing-origin,
# and non-repository contexts without contacting a remote.
state_root="$TEST_DIR/state"
mkdir -p "$state_root"
init_repo "$state_root/repo"
run_cc_in "$state_root/repo" status >"$TEST_DIR/status-clean"
assert_contains "$TEST_DIR/status-clean" clean "cc status did not report a clean repository"
printf 'dirty\n' >>"$state_root/repo/README.md"
run_cc_in "$state_root/repo" status >"$TEST_DIR/status-dirty"
assert_contains "$TEST_DIR/status-dirty" ' M README.md' "cc status did not report a dirty repository"
git -C "$state_root/repo" restore README.md
git -C "$state_root/repo" switch -q --detach
run_cc_in "$state_root/repo" repo >"$TEST_DIR/repo-detached"
assert_contains "$TEST_DIR/repo-detached" 'detached at ' "cc repo did not identify detached HEAD"
assert_contains "$TEST_DIR/repo-detached" 'Origin:        none' "cc repo did not report a missing origin"
mkdir -p "$state_root/not-git"
if run_cc_in "$state_root/not-git" repo >"$TEST_DIR/repo-invalid" 2>&1; then
    fail "cc repo accepted a non-Git directory"
fi
assert_contains "$TEST_DIR/repo-invalid" 'Not a Git repository' "cc repo did not explain invalid repository context"

# Cached ahead/behind state is accurate and explicitly identified as not
# refreshed. The read-only dashboard leaves refs and FETCH_HEAD unchanged.
sync_root="$TEST_DIR/sync-root"
remote="$TEST_DIR/origin.git"
git init -q --bare "$remote"
git clone -q "$remote" "$sync_root" 2>/dev/null
git -C "$sync_root" config user.name "Maintenance Fixture"
git -C "$sync_root" config user.email "maintenance@example.invalid"
printf 'base\n' >"$sync_root/base"
git -C "$sync_root" add base
git -C "$sync_root" commit -qm "test: base"
git -C "$sync_root" push -qu origin main
git -C "$remote" symbolic-ref HEAD refs/heads/main
peer="$TEST_DIR/peer"
git clone -q "$remote" "$peer"
git -C "$peer" config user.name "Maintenance Fixture"
git -C "$peer" config user.email "maintenance@example.invalid"
printf 'remote\n' >"$peer/remote"
git -C "$peer" add remote
git -C "$peer" commit -qm "test: remote advance"
git -C "$peer" push -q origin main
git -C "$sync_root" fetch -q origin
printf 'local\n' >"$sync_root/local"
git -C "$sync_root" add local
git -C "$sync_root" commit -qm "test: local advance"
git -C "$sync_root" for-each-ref --format='%(refname) %(objectname)' >"$TEST_DIR/refs-before"
fetch_before="$(sha256sum "$sync_root/.git/FETCH_HEAD")"
bash "$PROJECT_ROOT/tools/commands/repos" status --root "$TEST_DIR" >"$TEST_DIR/repos-status" || true
git -C "$sync_root" for-each-ref --format='%(refname) %(objectname)' >"$TEST_DIR/refs-after"
fetch_after="$(sha256sum "$sync_root/.git/FETCH_HEAD")"
cmp -s "$TEST_DIR/refs-before" "$TEST_DIR/refs-after" || fail "repos status changed Git refs"
[ "$fetch_before" = "$fetch_after" ] || fail "repos status changed FETCH_HEAD"
assert_contains "$TEST_DIR/repos-status" 'cached local state; no network refresh performed' \
    "repos status overstated remote freshness"
assert_contains "$TEST_DIR/repos-status" 'ahead:1 behind:1' "repos status lost cached divergence"

# Invalid Git candidates fail instead of being classified clean.
invalid_root="$TEST_DIR/invalid-root"
mkdir -p "$invalid_root/broken/.git"
if bash "$PROJECT_ROOT/tools/commands/repos" status --root "$invalid_root" >"$TEST_DIR/repos-invalid" 2>&1; then
    fail "repos status accepted an invalid Git candidate"
fi
assert_contains "$TEST_DIR/repos-invalid" 'FAIL:0' "invalid Git candidate was not classified as failed"
assert_contains "$TEST_DIR/repos-invalid" unavailable "invalid Git candidate was misreported as clean"

# Batch diagnostic failures aggregate, remain nonzero, and do not prevent a
# later safe repository from running.
batch_root="$TEST_DIR/batch-root"
init_repo "$batch_root/general"
init_repo "$batch_root/one"
init_repo "$batch_root/two"
mkdir -p "$batch_root/one/tools" "$batch_root/two/tools"
printf '#!/usr/bin/env bash\nexit 7\n' >"$batch_root/one/tools/cc"
# The marker is expanded by the generated child command.
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\nprintf continued >"${CC_MAINTENANCE_MARK:?}"\nexit 0\n' >"$batch_root/two/tools/cc"
chmod 755 "$batch_root/one/tools/cc" "$batch_root/two/tools/cc"
if CC_MAINTENANCE_MARK="$TEST_DIR/continued" bash "$PROJECT_ROOT/tools/commands/repos" \
    verify --root "$batch_root" >"$TEST_DIR/repos-verify" 2>&1; then
    fail "repos verify hid a child failure"
fi
[ -f "$TEST_DIR/continued" ] || fail "repos verify stopped before the later repository"
assert_contains "$TEST_DIR/repos-verify" 'cc verify failed with status 7' "repos verify lost the child status"
assert_matches "$TEST_DIR/repos-verify" '^FAIL:[[:space:]]+1$' "repos verify failure aggregation was incorrect"
if grep -Fq '[general] cc verify' "$TEST_DIR/repos-verify"; then
    fail "repos verify treated an ordinary non-toolkit repository as a toolkit failure"
fi

# Mutating batch fetch remains confined to fixtures, continues after failure,
# and returns nonzero for the aggregate.
fetch_root="$TEST_DIR/fetch-root"
init_repo "$fetch_root/a-fail"
init_repo "$fetch_root/z-pass"
git -C "$fetch_root/a-fail" remote add origin "$TEST_DIR/missing-origin.git"
fetch_remote="$TEST_DIR/fetch-origin.git"
git init -q --bare "$fetch_remote"
git -C "$fetch_root/z-pass" remote add origin "$fetch_remote"
if bash "$PROJECT_ROOT/tools/commands/repos" fetch --apply --root "$fetch_root" \
    >"$TEST_DIR/repos-fetch" 2>&1; then
    fail "repos fetch hid a partial failure"
fi
assert_contains "$TEST_DIR/repos-fetch" 'a-fail' "repos fetch omitted the failed repository"
assert_contains "$TEST_DIR/repos-fetch" 'z-pass' "repos fetch did not continue to the later repository"
assert_contains "$TEST_DIR/repos-fetch" 'fetched all remotes' "repos fetch did not complete the independent repository"

# Doctor remains read-only in a disposable home. Child diagnostics map
# WARN/FAIL truthfully and continue.
doctor_home="$TEST_DIR/doctor-home"
mkdir -p "$doctor_home"
find "$doctor_home" -mindepth 1 -printf '%P|%y|%s|%T@\n' | LC_ALL=C sort >"$TEST_DIR/doctor-before"
HOME="$doctor_home" CC_DOCTOR_SKIP_KERNEL=1 bash "$PROJECT_ROOT/tools/commands/doctor" \
    >"$TEST_DIR/doctor-read-only" 2>&1 || fail "doctor read-only fixture failed"
find "$doctor_home" -mindepth 1 -printf '%P|%y|%s|%T@\n' | LC_ALL=C sort >"$TEST_DIR/doctor-after"
cmp -s "$TEST_DIR/doctor-before" "$TEST_DIR/doctor-after" || fail "doctor changed the disposable home"

source "$PROJECT_ROOT/tools/commands/doctor"
doctor_fixture="$TEST_DIR/doctor-toolkit"
mkdir -p "$doctor_fixture/tools"
# The arguments and marker are expanded by the generated child command.
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\ncase "$1" in drives) exit 9 ;; smart) printf checked >"${CC_DOCTOR_MARK:?}"; exit 10 ;; esac\n' \
    >"$doctor_fixture/tools/cc"
TOOLKIT_ROOT="$doctor_fixture"
WARNINGS=0
FAILURES=0
CC_DOCTOR_MARK="$TEST_DIR/doctor-continued" run_cc "Storage inventory" drives >"$TEST_DIR/doctor-child" 2>&1
CC_DOCTOR_MARK="$TEST_DIR/doctor-continued" run_cc "SMART summary" smart >>"$TEST_DIR/doctor-child" 2>&1
[ "$FAILURES" -eq 1 ] || fail "doctor did not aggregate a child failure"
[ "$WARNINGS" -eq 1 ] || fail "doctor did not aggregate a child warning"
[ -f "$TEST_DIR/doctor-continued" ] || fail "doctor did not continue after a child failure"
assert_contains "$TEST_DIR/doctor-child" 'Storage inventory' "doctor omitted the failed child result"
assert_contains "$TEST_DIR/doctor-child" 'SMART summary' "doctor omitted the warning child result"
unset TOOLKIT_ROOT CURRENT_REPO

# Strict audit warnings and detail-mode syntax failures are authoritative.
audit_root="$TEST_DIR/audit-root"
cp -a "$PROJECT_ROOT/." "$audit_root"
rm -rf "$audit_root/.git"
rm -f "$audit_root/config/programs.conf"
if (cd "$audit_root" && TOOLKIT_ROOT="$audit_root" CURRENT_REPO="$audit_root" \
    bash tools/commands/verify >"$TEST_DIR/verify-failure" 2>&1); then
    fail "verify hid a required repository failure"
fi
assert_contains "$TEST_DIR/verify-failure" 'Overall Status:' "verify failure omitted the overall result"
cp "$PROJECT_ROOT/config/programs.conf" "$audit_root/config/programs.conf"
chmod -x "$audit_root/tools/commands/about"
if (cd "$audit_root" && TOOLKIT_ROOT="$audit_root" CURRENT_REPO="$audit_root" \
    bash tools/commands/audit --strict >"$TEST_DIR/audit-strict" 2>&1); then
    fail "strict audit accepted a required metadata/permission defect"
fi
assert_contains "$TEST_DIR/audit-strict" 'Strict compliance' "strict audit omitted compliance result"
printf 'this is not valid bash (\n' >"$audit_root/tools/commands/about"
chmod +x "$audit_root/tools/commands/about"
if (cd "$audit_root" && TOOLKIT_ROOT="$audit_root" CURRENT_REPO="$audit_root" \
    bash tools/commands/audit commands >"$TEST_DIR/audit-commands" 2>&1); then
    fail "audit commands hid a syntax failure"
fi
assert_matches "$TEST_DIR/audit-commands" '^about[[:space:]]+[0-9]+[[:space:]]+skip[[:space:]]+fail' \
    "audit commands did not report the syntax failure"

printf 'Maintenance operation tests: PASS\n'
