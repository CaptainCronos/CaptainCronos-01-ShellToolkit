#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_DIR="$(mktemp -d)"
REAL_GIT="$(command -v git)"

cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    local file="$1" expected="$2" message="$3"
    grep -Fq -- "$expected" "$file" || fail "$message"
}

assert_failure() {
    local message="$1"
    shift
    if "$@"; then
        fail "$message"
    fi
}

git_in() {
    local directory="$1"
    shift
    "$REAL_GIT" -C "$directory" "$@"
}

commit_all() {
    local directory="$1" message="$2"
    git_in "$directory" add .
    git_in "$directory" -c user.name='CC Fixture' -c user.email='fixture@example.invalid' commit -q -m "$message"
}

mkdir -p "$TEST_DIR/bin" "$TEST_DIR/tmp"
cat >"$TEST_DIR/bin/cc-fixture" <<'EOF_CC'
#!/usr/bin/env bash
set -u
printf '%s|%s\n' "$(git branch --show-current 2>/dev/null || true)" "$*" >>"$CCVALIDATE_CC_LOG"
[ "${CC_SELFTEST_SKIP_RELEASE_CHECK:-0}" != 1 ] || : >"$CCVALIDATE_RELEASE_DELEGATED_MARKER"
case "${CCVALIDATE_FAIL_MATCH:-}" in
    "") ;;
    *)
        if [ "$*" = "$CCVALIDATE_FAIL_MATCH" ]; then
            exit 9
        fi
        ;;
esac
if [ -n "${CCVALIDATE_FAIL_BRANCH:-}" ] &&
   [ "$(git branch --show-current 2>/dev/null || true)" = "$CCVALIDATE_FAIL_BRANCH" ] &&
   [ "$*" = "${CCVALIDATE_FAIL_BRANCH_COMMAND:-selftest}" ]; then
    exit 8
fi
if [ "${CCVALIDATE_ADVANCE_REMOTE_ON_VALIDATE:-0}" = 1 ] &&
   [ ! -e "$CCVALIDATE_REMOTE_ADVANCED_MARKER" ]; then
    : >"$CCVALIDATE_REMOTE_ADVANCED_MARKER"
    git -C "$CCVALIDATE_REMOTE_ADVANCE_PEER" push -q origin main
fi
exit 0
EOF_CC
chmod 700 "$TEST_DIR/bin/cc-fixture"

cat >"$TEST_DIR/bin/git-fixture" <<EOF_GIT
#!/usr/bin/env bash
printf '%s|%s\n' "\$PWD" "\$*" >>"\${CCVALIDATE_GIT_LOG:-/dev/null}"
if [ "\${CCVALIDATE_FAIL_REMOTE_VERIFY:-0}" = 1 ] &&
   [ "\${1:-}" = ls-remote ]; then
    exit 1
fi
if [ "\${CCVALIDATE_FAIL_BRANCH_CLEANUP:-0}" = 1 ] &&
   [ "\${1:-}" = branch ] && [ "\${2:-}" = -d ]; then
    exit 7
fi
exec "$REAL_GIT" "\$@"
EOF_GIT
chmod 700 "$TEST_DIR/bin/git-fixture"

export CCVALIDATE_TEST_MODE=1
export CCVALIDATE_CC_BIN="$TEST_DIR/bin/cc-fixture"
export CCVALIDATE_GIT_BIN="$TEST_DIR/bin/git-fixture"
export CCVALIDATE_CC_LOG="$TEST_DIR/cc.log"
export CCVALIDATE_GIT_LOG="$TEST_DIR/git.log"
export CCVALIDATE_RELEASE_DELEGATED_MARKER="$TEST_DIR/release-delegated"
export CCVALIDATE_REMOTE_ADVANCED_MARKER="$TEST_DIR/remote-advanced"
export TMPDIR="$TEST_DIR/tmp"

alias functions=: funcs=: showfunc=:
# shellcheck disable=SC1090
if ! source "$PROJECT_ROOT/bash/bash_functions"; then
    fail 'could not source shell functions'
fi
# Repeated sourcing must remain safe and idempotent.
alias functions=: funcs=: showfunc=:
# shellcheck disable=SC1090
if ! source "$PROJECT_ROOT/bash/bash_functions"; then
    fail 'could not source shell functions repeatedly'
fi
declare -F ccvalidate >/dev/null || fail 'ccvalidate was not defined after repeated sourcing'

default_selftest_count="$(bash -c '
    source "$1/tools/commands/selftest"
    SELFTEST_TOTAL=0
    selftest_suite selftest_count
    printf "%s\n" "$SELFTEST_TOTAL"
' bash "$PROJECT_ROOT")"
delegated_selftest_count="$(CC_SELFTEST_SKIP_RELEASE_CHECK=1 bash -c '
    source "$1/tools/commands/selftest"
    SELFTEST_TOTAL=0
    selftest_suite selftest_count
    printf "%s\n" "$SELFTEST_TOTAL"
' bash "$PROJECT_ROOT")"
[ "$default_selftest_count" -eq $((delegated_selftest_count + 1)) ] ||
    fail 'release delegation changed default selftest authority or test accounting'

new_fixture() {
    local name="$1" work_branch="${2:-feature/work}" repo origin
    repo="$TEST_DIR/$name"
    origin="$TEST_DIR/$name-origin.git"
    "$REAL_GIT" init -q --bare "$origin"
    "$REAL_GIT" init -q -b main "$repo"
    mkdir -p "$repo/tools" "$repo/bash"
    printf 'status: stable\n' >"$repo/manifest.yml"
    printf '#!/usr/bin/env bash\n' >"$repo/tools/cc"
    printf '# fixture\n' >"$repo/bash/bash_functions"
    chmod 700 "$repo/tools/cc"
    commit_all "$repo" 'initial main'
    git_in "$repo" remote add origin "$origin"
    git_in "$repo" push -q -u origin main
    git_in "$repo" switch -q -c "$work_branch"
    printf '%s\n' "$name" >"$repo/feature.txt"
    commit_all "$repo" 'feature work'
    printf '%s\n' "$repo"
}

set_fixture_contract() {
    local repo="$1"
    export CCVALIDATE_EXPECTED_REPOSITORY_NAME
    export CCVALIDATE_EXPECTED_ORIGIN
    CCVALIDATE_EXPECTED_REPOSITORY_NAME="$(basename "$repo")"
    CCVALIDATE_EXPECTED_ORIGIN="$(git_in "$repo" remote get-url origin 2>/dev/null || true)"
}

run_validation() {
    local repo="$1" output="$2"
    shift 2
    : >"$CCVALIDATE_CC_LOG"
    : >"$CCVALIDATE_GIT_LOG"
    (cd "$repo" && ccvalidate "$@") >"$output" 2>&1
}

validation_repo="$(new_fixture validation-repo)"
set_fixture_contract "$validation_repo"
validation_head="$(git_in "$validation_repo" rev-parse HEAD)"
validation_refs="$(git_in "$validation_repo" show-ref)"
validation_status="$(git_in "$validation_repo" status --porcelain)"

run_validation "$validation_repo" "$TEST_DIR/bare.out"
assert_contains "$TEST_DIR/bare.out" 'Mode: full' 'bare ccvalidate did not default to full'
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|selftest' 'full mode omitted selftest'
[ "$(wc -l <"$CCVALIDATE_CC_LOG")" -eq 1 ] || fail 'full mode duplicated selftest-owned acceptance gates'
engineering_evidence="$validation_repo/.git/ccvalidate/validation-engineering"
[ -f "$engineering_evidence" ] || fail 'successful full did not create engineering evidence'
[ "$(stat -c %a "$validation_repo/.git/ccvalidate")" = 700 ] || fail 'validation state directory is not private'
[ "$(stat -c %a "$engineering_evidence")" = 600 ] || fail 'engineering evidence is not private'
assert_contains "$engineering_evidence" 'mode=engineering' 'full evidence recorded the wrong mode'
assert_contains "$engineering_evidence" 'result=PASS' 'full evidence omitted its authoritative result'
[ ! -e "$validation_repo/.git/ccvalidate/validation-release" ] ||
    fail 'full evidence falsely represented release readiness'
if grep -Fq -- "$validation_repo" "$engineering_evidence" ||
   grep -Fq -- "$CCVALIDATE_EXPECTED_ORIGIN" "$engineering_evidence"; then
    fail 'validation evidence exposed a repository path or origin'
fi
if [ -n "$(git_in "$validation_repo" status --porcelain)" ]; then
    fail 'Git-private validation evidence appeared in repository status'
fi

run_validation "$validation_repo" "$TEST_DIR/full.out" full
assert_contains "$TEST_DIR/full.out" 'reused exact-state engineering PASS' 'full did not reuse exact engineering evidence'
if grep -Fq '|selftest' "$CCVALIDATE_CC_LOG"; then
    fail 'unchanged full repeated the expensive selftest'
fi

run_validation "$validation_repo" "$TEST_DIR/fast.out" fast
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|verify' 'fast mode omitted verify'
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|audit --strict' 'fast mode omitted strict audit'
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|docs lint' 'fast mode omitted docs lint'
if grep -Fq '|selftest' "$CCVALIDATE_CC_LOG"; then
    fail 'fast mode ran the expensive selftest'
fi

rm -f "$CCVALIDATE_RELEASE_DELEGATED_MARKER"
run_validation "$validation_repo" "$TEST_DIR/release.out" release
assert_contains "$TEST_DIR/release.out" 'reused exact-state engineering PASS' 'release did not reuse engineering coverage'
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|release check' 'release mode omitted the release gate'
[ "$(wc -l <"$CCVALIDATE_CC_LOG")" -eq 1 ] || fail 'release mode repeated reusable engineering coverage'
[ ! -e "$CCVALIDATE_RELEASE_DELEGATED_MARKER" ] || fail 'reused release mode invoked delegated selftest'
[ -f "$validation_repo/.git/ccvalidate/validation-release" ] || fail 'release did not create distinct release evidence'
assert_contains "$validation_repo/.git/ccvalidate/validation-release" 'mode=release' 'release evidence recorded the wrong mode'
# shellcheck disable=SC2031
[ "${CC_SELFTEST_SKIP_RELEASE_CHECK+x}" != x ] || fail 'release delegation leaked into caller environment'

export CCVALIDATE_FAIL_MATCH='release check'
# shellcheck disable=SC2016
assert_failure 'failed release returned zero' \
    bash -c 'cd "$1"; source "$2/bash/bash_functions"; ccvalidate release' bash "$validation_repo" "$PROJECT_ROOT" \
    >"$TEST_DIR/release-failure.out" 2>&1
unset CCVALIDATE_FAIL_MATCH
[ ! -e "$validation_repo/.git/ccvalidate/validation-release" ] ||
    fail 'failed release retained reusable release PASS evidence'

delegated_repo="$(new_fixture validation-release-delegated)"
set_fixture_contract "$delegated_repo"
rm -f "$CCVALIDATE_RELEASE_DELEGATED_MARKER"
run_validation "$delegated_repo" "$TEST_DIR/release-delegated.out" release
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|selftest' 'uncached release omitted engineering coverage'
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|release check' 'uncached release omitted its unique readiness gate'
[ -f "$CCVALIDATE_RELEASE_DELEGATED_MARKER" ] || fail 'uncached release did not delegate the nested selftest release gate'

failed_state_repo="$(new_fixture validation-failed-state)"
set_fixture_contract "$failed_state_repo"
export CCVALIDATE_FAIL_MATCH=selftest
: >"$CCVALIDATE_CC_LOG"
: >"$CCVALIDATE_GIT_LOG"
# shellcheck disable=SC2016
assert_failure 'required validation failure returned zero' \
    bash -c 'cd "$1"; source "$2/bash/bash_functions"; ccvalidate full' bash "$failed_state_repo" "$PROJECT_ROOT" \
    >"$TEST_DIR/failure.out" 2>&1
unset CCVALIDATE_FAIL_MATCH
assert_contains "$TEST_DIR/failure.out" 'Engineering selftest' 'failure result was not rendered'
assert_contains "$TEST_DIR/failure.out" 'Overall Status:  FAIL' 'aggregate failure was not reported'
assert_contains "$CCVALIDATE_GIT_LOG" 'diff --check' 'independent checks did not continue after failure'
[ ! -e "$failed_state_repo/.git/ccvalidate/validation-engineering" ] || fail 'failed full produced reusable PASS evidence'

incomplete_repo="$(new_fixture validation-incomplete-state)"
set_fixture_contract "$incomplete_repo"
mkdir -p "$incomplete_repo/.git/ccvalidate"
chmod 700 "$incomplete_repo/.git/ccvalidate"
printf 'version=1\nresult=PASS\n' >"$incomplete_repo/.git/ccvalidate/.validation-engineering.incomplete"
chmod 600 "$incomplete_repo/.git/ccvalidate/.validation-engineering.incomplete"
run_validation "$incomplete_repo" "$TEST_DIR/incomplete.out" full
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|selftest' 'incomplete state was reused'

corrupt_repo="$(new_fixture validation-corrupt-state)"
set_fixture_contract "$corrupt_repo"
mkdir -p "$corrupt_repo/.git/ccvalidate"
chmod 700 "$corrupt_repo/.git/ccvalidate"
printf 'version=corrupt\nmode=engineering\nresult=PASS\n' >"$corrupt_repo/.git/ccvalidate/validation-engineering"
chmod 600 "$corrupt_repo/.git/ccvalidate/validation-engineering"
run_validation "$corrupt_repo" "$TEST_DIR/corrupt.out" full
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|selftest' 'corrupt state was reused'

changed_head_repo="$(new_fixture validation-changed-head)"
set_fixture_contract "$changed_head_repo"
run_validation "$changed_head_repo" "$TEST_DIR/changed-head-first.out" full
printf 'next\n' >"$changed_head_repo/next.txt"
commit_all "$changed_head_repo" 'advance validation HEAD'
run_validation "$changed_head_repo" "$TEST_DIR/changed-head-second.out" full
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|selftest' 'changed HEAD inherited validation evidence'

dirty_state_repo="$(new_fixture validation-dirty-state)"
set_fixture_contract "$dirty_state_repo"
run_validation "$dirty_state_repo" "$TEST_DIR/dirty-state-first.out" full
printf 'dirty\n' >>"$dirty_state_repo/feature.txt"
run_validation "$dirty_state_repo" "$TEST_DIR/dirty-state-second.out" full
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|selftest' 'dirty tracked worktree inherited validation evidence'
if (cd "$dirty_state_repo" && _ccvalidate_validation_evidence_read engineering); then
    fail 'dirty tracked worktree accepted clean validation evidence'
fi

staged_state_repo="$(new_fixture validation-staged-state)"
set_fixture_contract "$staged_state_repo"
run_validation "$staged_state_repo" "$TEST_DIR/staged-state-first.out" full
printf 'staged\n' >>"$staged_state_repo/feature.txt"
git_in "$staged_state_repo" add feature.txt
run_validation "$staged_state_repo" "$TEST_DIR/staged-state-second.out" full
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|selftest' 'staged index inherited validation evidence'
if (cd "$staged_state_repo" && _ccvalidate_validation_evidence_read engineering); then
    fail 'staged index accepted clean validation evidence'
fi

untracked_state_repo="$(new_fixture validation-untracked-state)"
set_fixture_contract "$untracked_state_repo"
run_validation "$untracked_state_repo" "$TEST_DIR/untracked-state-first.out" full
printf 'untracked\n' >"$untracked_state_repo/untracked.txt"
run_validation "$untracked_state_repo" "$TEST_DIR/untracked-state-second.out" full
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|selftest' 'untracked state inherited validation evidence'
if (cd "$untracked_state_repo" && _ccvalidate_validation_evidence_read engineering); then
    fail 'untracked state accepted clean validation evidence'
fi

ccvalidate help >"$TEST_DIR/help.out"
ccvalidate --help >>"$TEST_DIR/help.out"
ccvalidate -h >>"$TEST_DIR/help.out"
assert_contains "$TEST_DIR/help.out" 'finish' 'help omitted finish mode'
assert_contains "$TEST_DIR/help.out" 'publish' 'help omitted publish mode'
set +e
ccvalidate foo >"$TEST_DIR/unknown.out" 2>&1
unknown_status=$?
set -e
[ "$unknown_status" -eq 2 ] || fail 'unknown mode did not return status 2'
assert_contains "$TEST_DIR/unknown.out" 'unknown mode: foo' 'unknown-mode help lacked context'

[ "$(git_in "$validation_repo" rev-parse HEAD)" = "$validation_head" ] || fail 'validation mode changed HEAD'
[ "$(git_in "$validation_repo" show-ref)" = "$validation_refs" ] || fail 'validation mode changed refs'
[ "$(git_in "$validation_repo" status --porcelain)" = "$validation_status" ] || fail 'validation mode changed the worktree'
if LC_ALL=C grep -q $'\033' "$TEST_DIR/bare.out" "$TEST_DIR/fast.out" "$TEST_DIR/full.out" "$TEST_DIR/release.out"; then
    fail 'redirected validation output contained ANSI escapes'
fi

run_finish_failure() {
    local repo="$1" output="$2" retained_branch="${3:-feature/work}"
    set_fixture_contract "$repo"
    : >"$CCVALIDATE_CC_LOG"
    : >"$CCVALIDATE_GIT_LOG"
    if (cd "$repo" && ccvalidate finish) >"$output" 2>&1; then
        fail "finish unexpectedly succeeded for $(basename "$repo")"
    fi
    git_in "$repo" show-ref --verify --quiet "refs/heads/$retained_branch" ||
        fail "work branch was removed after failure in $(basename "$repo")"
}

# Successful completion: full validation on feature, release-equivalent
# post-merge validation on main, one fast-forward push, verified remote, and
# safe local feature deletion.
success_repo="$(new_fixture finish-success)"
success_origin="$(git_in "$success_repo" remote get-url origin)"
success_head="$(git_in "$success_repo" rev-parse HEAD)"
set_fixture_contract "$success_repo"
: >"$CCVALIDATE_CC_LOG"
: >"$CCVALIDATE_GIT_LOG"
(cd "$success_repo" && ccvalidate finish) >"$TEST_DIR/finish-success.out" 2>&1 ||
    fail 'clean fast-forward finish workflow failed'
[ "$(git_in "$success_repo" branch --show-current)" = main ] || fail 'finish did not leave local main checked out'
[ "$(git_in "$success_repo" rev-parse main)" = "$success_head" ] || fail 'main did not fast-forward to feature HEAD'
[ "$(git_in "$success_origin" rev-parse refs/heads/main)" = "$success_head" ] || fail 'origin/main did not receive feature HEAD'
if git_in "$success_repo" show-ref --verify --quiet refs/heads/feature/work; then
    fail 'successful finish retained the local feature branch'
fi
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|selftest' 'feature full validation did not run'
assert_contains "$CCVALIDATE_CC_LOG" 'main|release check' 'post-merge release gate did not run on main'
if [ "$(grep -Fc '|selftest' "$CCVALIDATE_CC_LOG")" -ne 1 ]; then
    fail 'finish duplicated expensive engineering validation across the fast-forward'
fi
assert_contains "$TEST_DIR/finish-success.out" 'Remote verification' 'finish did not report remote verification'
assert_contains "$TEST_DIR/finish-success.out" 'Overall Status:  PASS' 'successful finish did not return PASS'
while IFS='|' read -r directory arguments; do
    case "$arguments" in
        switch\ *|pull\ *|merge\ *|push\ *|branch\ -d\ *)
            case "$directory" in "$success_repo"*) ;; *) fail 'Git mutation escaped the disposable fixture' ;; esac
            ;;
    esac
done <"$CCVALIDATE_GIT_LOG"

# The measured operator sequence leaves exact-state full and release evidence.
# Finish reuses it before the merge, then still runs the release-specific gate
# on main without repeating engineering selftest coverage.
prevalidated_repo="$(new_fixture finish-prevalidated)"
set_fixture_contract "$prevalidated_repo"
run_validation "$prevalidated_repo" "$TEST_DIR/prevalidated-full.out" full
run_validation "$prevalidated_repo" "$TEST_DIR/prevalidated-release.out" release
: >"$CCVALIDATE_CC_LOG"
: >"$CCVALIDATE_GIT_LOG"
(cd "$prevalidated_repo" && ccvalidate finish) >"$TEST_DIR/finish-prevalidated.out" 2>&1 ||
    fail 'finish rejected authoritative unchanged validation evidence'
assert_contains "$TEST_DIR/finish-prevalidated.out" 'reused exact-state release PASS' \
    'finish did not report pre-merge release evidence reuse'
assert_contains "$CCVALIDATE_CC_LOG" 'main|release check' \
    'prevalidated finish omitted the post-merge release-readiness gate'
if grep -Fq '|selftest' "$CCVALIDATE_CC_LOG"; then
    fail 'prevalidated finish repeated expensive engineering selftest coverage'
fi

release_repo="$(new_fixture finish-release release/1.3.0-beta2)"
release_head="$(git_in "$release_repo" rev-parse HEAD)"
release_origin="$(git_in "$release_repo" remote get-url origin)"
set_fixture_contract "$release_repo"
: >"$CCVALIDATE_CC_LOG"
: >"$CCVALIDATE_GIT_LOG"
(cd "$release_repo" && ccvalidate finish) >"$TEST_DIR/finish-release.out" 2>&1 ||
    fail 'finish rejected a supported release work branch'
[ "$(git_in "$release_repo" rev-parse main)" = "$release_head" ] || fail 'release finish did not fast-forward main'
[ "$(git_in "$release_origin" rev-parse refs/heads/main)" = "$release_head" ] || fail 'release finish did not publish main'
assert_contains "$TEST_DIR/finish-release.out" 'Work branch' 'release finish used incorrect branch terminology'

_ccvalidate_branch_allowed feature/example || fail 'feature branch class was rejected'
_ccvalidate_branch_allowed release/1.3.0 || fail 'release branch class was rejected'
if _ccvalidate_branch_allowed 'release/'; then fail 'malformed release branch was accepted'; fi
if _ccvalidate_branch_allowed main; then fail 'main was accepted as a work branch'; fi

main_repo="$(new_fixture finish-main)"
git_in "$main_repo" switch -q main
run_finish_failure "$main_repo" "$TEST_DIR/refuse-main.out"
assert_contains "$TEST_DIR/refuse-main.out" 'Work branch' 'main-branch refusal was not explained'

detached_repo="$(new_fixture finish-detached)"
git_in "$detached_repo" checkout -q --detach
run_finish_failure "$detached_repo" "$TEST_DIR/refuse-detached.out"
assert_contains "$TEST_DIR/refuse-detached.out" 'detached HEAD' 'detached-HEAD refusal was not explained'

unrelated_repo="$(new_fixture finish-unrelated)"
git_in "$unrelated_repo" branch -m experiment/work
run_finish_failure "$unrelated_repo" "$TEST_DIR/refuse-unrelated.out" experiment/work
assert_contains "$TEST_DIR/refuse-unrelated.out" 'Work branch' 'unrelated branch refusal was not explained'

no_work_repo="$(new_fixture finish-no-committed-work)"
git_in "$no_work_repo" switch -q main
git_in "$no_work_repo" merge -q --ff-only feature/work
git_in "$no_work_repo" switch -q feature/work
run_finish_failure "$no_work_repo" "$TEST_DIR/refuse-no-work.out"
assert_contains "$TEST_DIR/refuse-no-work.out" 'no committed work beyond main' 'empty feature branch was not refused'

missing_main_repo="$(new_fixture finish-no-main)"
git_in "$missing_main_repo" branch -d main >/dev/null
run_finish_failure "$missing_main_repo" "$TEST_DIR/refuse-no-main.out"
assert_contains "$TEST_DIR/refuse-no-main.out" 'local main is missing' 'missing-main refusal was not explained'

dirty_repo="$(new_fixture finish-dirty)"
printf 'dirty\n' >>"$dirty_repo/feature.txt"
run_finish_failure "$dirty_repo" "$TEST_DIR/refuse-dirty.out"
assert_contains "$TEST_DIR/refuse-dirty.out" 'unstaged changes present' 'dirty-tree refusal was not explained'

staged_repo="$(new_fixture finish-staged)"
printf 'staged\n' >>"$staged_repo/feature.txt"
git_in "$staged_repo" add feature.txt
run_finish_failure "$staged_repo" "$TEST_DIR/refuse-staged.out"
assert_contains "$TEST_DIR/refuse-staged.out" 'staged changes present' 'staged-change refusal was not explained'

untracked_repo="$(new_fixture finish-untracked)"
printf 'implementation\n' >"$untracked_repo/untracked.sh"
run_finish_failure "$untracked_repo" "$TEST_DIR/refuse-untracked.out"
assert_contains "$TEST_DIR/refuse-untracked.out" 'untracked files present' 'untracked-file refusal was not explained'

missing_origin_repo="$(new_fixture finish-no-origin)"
git_in "$missing_origin_repo" remote remove origin
run_finish_failure "$missing_origin_repo" "$TEST_DIR/refuse-origin.out"
assert_contains "$TEST_DIR/refuse-origin.out" 'missing or suspicious' 'missing-origin refusal was not explained'

suspicious_repo="$(new_fixture finish-suspicious-origin)"
git_in "$suspicious_repo" remote set-url origin "$TEST_DIR/not-the-authorized-origin.git"
CCVALIDATE_EXPECTED_ORIGIN="$TEST_DIR/different-authorized-origin.git"
export CCVALIDATE_EXPECTED_ORIGIN
: >"$CCVALIDATE_CC_LOG"
# shellcheck disable=SC2016
assert_failure 'suspicious origin was accepted' bash -c \
    'cd "$1"; source "$2/bash/bash_functions"; ccvalidate finish' bash "$suspicious_repo" "$PROJECT_ROOT" \
    >"$TEST_DIR/refuse-suspicious.out" 2>&1
git_in "$suspicious_repo" show-ref --verify --quiet refs/heads/feature/work || fail 'suspicious-origin failure removed feature branch'

wrong_repo="$(new_fixture finish-wrong-repository)"
set_fixture_contract "$wrong_repo"
export CCVALIDATE_EXPECTED_REPOSITORY_NAME='CaptainCronos-01-ShellToolkit'
# shellcheck disable=SC2016
assert_failure 'wrong repository was accepted' bash -c \
    'cd "$1"; source "$2/bash/bash_functions"; ccvalidate finish' bash "$wrong_repo" "$PROJECT_ROOT" \
    >"$TEST_DIR/refuse-wrong-repo.out" 2>&1
git_in "$wrong_repo" show-ref --verify --quiet refs/heads/feature/work || fail 'wrong-repository failure removed feature branch'

nonff_repo="$(new_fixture finish-nonff)"
git_in "$nonff_repo" switch -q main
printf 'local-main\n' >"$nonff_repo/main-only.txt"
commit_all "$nonff_repo" 'diverge local main'
git_in "$nonff_repo" switch -q feature/work
run_finish_failure "$nonff_repo" "$TEST_DIR/refuse-nonff.out"
assert_contains "$TEST_DIR/refuse-nonff.out" 'non-fast-forward merge' 'non-fast-forward refusal was not explained'

conflict_repo="$(new_fixture finish-conflict)"
git_in "$conflict_repo" switch -q main
printf 'main\n' >"$conflict_repo/feature.txt"
commit_all "$conflict_repo" 'conflicting main edit'
git_in "$conflict_repo" switch -q feature/work
run_finish_failure "$conflict_repo" "$TEST_DIR/refuse-conflict.out"
assert_contains "$TEST_DIR/refuse-conflict.out" 'non-fast-forward merge' 'merge-conflict topology was not refused before merge'

# Main advances remotely after the feature fork. Preflight passes against local
# main, then updated main is correctly refused before any feature merge.
diverged_repo="$(new_fixture finish-diverged-main)"
diverged_origin="$(git_in "$diverged_repo" remote get-url origin)"
peer="$TEST_DIR/diverged-peer"
git_in "$TEST_DIR" clone -q "$diverged_origin" "$peer"
printf 'remote-main\n' >"$peer/remote-main.txt"
commit_all "$peer" 'advance remote main'
git_in "$peer" push -q origin main
run_finish_failure "$diverged_repo" "$TEST_DIR/refuse-diverged-main.out"
assert_contains "$TEST_DIR/refuse-diverged-main.out" 'updated main diverged from work branch' 'updated-main divergence was not reported'

feature_fail_repo="$(new_fixture finish-feature-validation-fail)"
feature_fail_head="$(git_in "$feature_fail_repo" rev-parse HEAD)"
feature_fail_main="$(git_in "$feature_fail_repo" rev-parse main)"
feature_fail_origin="$(git_in "$feature_fail_repo" remote get-url origin)"
feature_fail_remote="$(git_in "$feature_fail_origin" rev-parse refs/heads/main)"
export CCVALIDATE_FAIL_BRANCH='feature/work'
export CCVALIDATE_FAIL_BRANCH_COMMAND='selftest'
run_finish_failure "$feature_fail_repo" "$TEST_DIR/feature-validation-fail.out"
unset CCVALIDATE_FAIL_BRANCH CCVALIDATE_FAIL_BRANCH_COMMAND
[ "$(git_in "$feature_fail_repo" branch --show-current)" = feature/work ] || fail 'feature validation failure switched branches'
[ "$(git_in "$feature_fail_repo" rev-parse HEAD)" = "$feature_fail_head" ] || fail 'feature validation failure changed feature HEAD'
[ "$(git_in "$feature_fail_repo" rev-parse main)" = "$feature_fail_main" ] || fail 'feature validation failure changed main'
[ "$(git_in "$feature_fail_origin" rev-parse refs/heads/main)" = "$feature_fail_remote" ] || fail 'feature validation failure pushed origin/main'
assert_contains "$TEST_DIR/feature-validation-fail.out" 'Work validation' 'work validation failure was not reported'

post_fail_repo="$(new_fixture finish-post-validation-fail)"
post_fail_origin="$(git_in "$post_fail_repo" remote get-url origin)"
post_fail_remote_before="$(git_in "$post_fail_origin" rev-parse refs/heads/main)"
export CCVALIDATE_FAIL_BRANCH=main
export CCVALIDATE_FAIL_BRANCH_COMMAND='release check'
run_finish_failure "$post_fail_repo" "$TEST_DIR/post-validation-fail.out"
unset CCVALIDATE_FAIL_BRANCH CCVALIDATE_FAIL_BRANCH_COMMAND
[ "$(git_in "$post_fail_repo" branch --show-current)" = main ] || fail 'post-merge failure did not preserve exact local main state'
[ "$(git_in "$post_fail_origin" rev-parse refs/heads/main)" = "$post_fail_remote_before" ] || fail 'post-merge validation failure pushed main'
assert_contains "$TEST_DIR/post-validation-fail.out" 'Post-merge validation' 'post-merge failure boundary was not reported'

push_fail_repo="$(new_fixture finish-push-fail)"
push_fail_origin="$(git_in "$push_fail_repo" remote get-url origin)"
cat >"$push_fail_origin/hooks/pre-receive" <<'EOF_HOOK'
#!/usr/bin/env bash
exit 1
EOF_HOOK
chmod 700 "$push_fail_origin/hooks/pre-receive"
run_finish_failure "$push_fail_repo" "$TEST_DIR/push-fail.out"
assert_contains "$TEST_DIR/push-fail.out" 'Push origin/main' 'push failure was not reported'

verify_fail_repo="$(new_fixture finish-verify-fail)"
export CCVALIDATE_FAIL_REMOTE_VERIFY=1
run_finish_failure "$verify_fail_repo" "$TEST_DIR/remote-verify-fail.out"
unset CCVALIDATE_FAIL_REMOTE_VERIFY
assert_contains "$TEST_DIR/remote-verify-fail.out" 'Remote verification' 'remote verification failure was not reported'

run_publish_failure() {
    local repo="$1" output="$2"
    set_fixture_contract "$repo"
    : >"$CCVALIDATE_CC_LOG"
    : >"$CCVALIDATE_GIT_LOG"
    if (cd "$repo" && ccvalidate publish) >"$output" 2>&1; then
        fail "publish unexpectedly succeeded for $(basename "$repo")"
    fi
}

make_interrupted_finish() {
    local repo="$1" output="$2"
    export CCVALIDATE_FAIL_BRANCH=main
    export CCVALIDATE_FAIL_BRANCH_COMMAND='release check'
    run_finish_failure "$repo" "$output"
    unset CCVALIDATE_FAIL_BRANCH CCVALIDATE_FAIL_BRANCH_COMMAND
    [ "$(git_in "$repo" branch --show-current)" = main ] ||
        fail 'interrupted finish did not leave main checked out'
    [ -f "$repo/.git/ccvalidate/finish-state" ] ||
        fail 'interrupted finish did not record continuation state'
}

# Publish resumes the exact post-merge/pre-push state left by finish, validates
# main, pushes only main, verifies local/tracking/live equality, and deletes the
# locally retained feature with -d. Remote feature refs are never deleted.
publish_repo="$(new_fixture publish-success)"
publish_origin="$(git_in "$publish_repo" remote get-url origin)"
git_in "$publish_repo" push -q origin feature/work:feature/work
publish_head="$(git_in "$publish_repo" rev-parse feature/work)"
make_interrupted_finish "$publish_repo" "$TEST_DIR/publish-interrupted.out"
set_fixture_contract "$publish_repo"
: >"$CCVALIDATE_CC_LOG"
: >"$CCVALIDATE_GIT_LOG"
(cd "$publish_repo" && ccvalidate publish) >"$TEST_DIR/publish-success.out" 2>&1 ||
    fail 'publish did not resume an interrupted finish'
[ "$(git_in "$publish_repo" rev-parse main)" = "$publish_head" ] || fail 'publish changed local main unexpectedly'
[ "$(git_in "$publish_repo" rev-parse origin/main)" = "$publish_head" ] || fail 'publish did not update origin/main tracking'
[ "$(git_in "$publish_origin" rev-parse refs/heads/main)" = "$publish_head" ] || fail 'publish did not update live main'
git_in "$publish_origin" show-ref --verify --quiet refs/heads/feature/work || fail 'publish deleted a remote feature branch'
if git_in "$publish_repo" show-ref --verify --quiet refs/heads/feature/work; then
    fail 'publish retained a known, unchanged, fully merged local feature branch'
fi
[ ! -e "$publish_repo/.git/ccvalidate/finish-state" ] ||
    fail 'successful publish retained workflow state after branch cleanup'
assert_contains "$TEST_DIR/publish-success.out" 'Release validation' 'publish omitted release validation'
assert_contains "$TEST_DIR/publish-success.out" 'Remote unchanged' 'publish omitted remote stability verification'
assert_contains "$TEST_DIR/publish-success.out" 'Remote verification' 'publish omitted live remote verification'
assert_contains "$TEST_DIR/publish-success.out" 'Work branch cleanup' 'publish omitted retained-work cleanup'
assert_contains "$TEST_DIR/publish-success.out" 'Overall Status:  PASS' 'publish success did not report PASS'
assert_contains "$CCVALIDATE_GIT_LOG" 'push origin refs/heads/main:refs/heads/main' 'publish used an unexpected main refspec'
if grep -E '\|push .*feature|\|push .*tags|\|push .*force' "$CCVALIDATE_GIT_LOG"; then
    fail 'publish attempted a non-main, tag, or force push'
fi

# A post-merge validation repair legitimately advances local main beyond the
# recorded feature tip.  Publication pushes and verifies the repaired main,
# then proves the unchanged feature tip is merged before safe -d cleanup.
publish_repair_repo="$(new_fixture publish-repaired-main)"
publish_repair_origin="$(git_in "$publish_repair_repo" remote get-url origin)"
make_interrupted_finish "$publish_repair_repo" "$TEST_DIR/publish-repair-interrupted.out"
publish_repair_feature="$(git_in "$publish_repair_repo" rev-parse feature/work)"
printf 'post-merge repair\n' >"$publish_repair_repo/repair.txt"
commit_all "$publish_repair_repo" 'fix: post-merge validation repair'
publish_repair_main="$(git_in "$publish_repair_repo" rev-parse main)"
[ "$publish_repair_main" != "$publish_repair_feature" ] || fail 'repair did not advance main beyond the feature tip'
set_fixture_contract "$publish_repair_repo"
: >"$CCVALIDATE_CC_LOG"
: >"$CCVALIDATE_GIT_LOG"
(cd "$publish_repair_repo" && ccvalidate publish) >"$TEST_DIR/publish-repair.out" 2>&1 \
    || fail 'publish rejected a repaired-main continuation'
[ "$(git_in "$publish_repair_origin" rev-parse refs/heads/main)" = "$publish_repair_main" ] \
    || fail 'repaired-main publish did not publish repair commit'
if git_in "$publish_repair_repo" show-ref --verify --quiet refs/heads/feature/work; then
    fail 'repaired-main publish retained the unchanged merged feature branch'
fi
assert_contains "$CCVALIDATE_GIT_LOG" 'push origin refs/heads/main:refs/heads/main' \
    'repaired-main publish used an unexpected main refspec'
assert_contains "$CCVALIDATE_GIT_LOG" 'branch -d feature/work' \
    'repaired-main publish did not use safe feature cleanup'

# Repetition after publication is safe: validate and verify, but do not push or
# recreate commits/refs. Unknown cleanup ownership is reported conservatively.
published_refs="$(git_in "$publish_repo" show-ref)"
set_fixture_contract "$publish_repo"
: >"$CCVALIDATE_GIT_LOG"
(cd "$publish_repo" && ccvalidate publish) >"$TEST_DIR/publish-repeat.out" 2>&1 ||
    fail 'repeated publish was not idempotent'
[ "$(git_in "$publish_repo" show-ref)" = "$published_refs" ] || fail 'repeated publish changed refs'
assert_contains "$TEST_DIR/publish-repeat.out" 'no unpublished commits' 'repeated publish did not explain equal state'
assert_contains "$TEST_DIR/publish-repeat.out" 'already published' 'repeated publish did not skip push'
assert_contains "$TEST_DIR/publish-repeat.out" 'Overall Status:  PASS' 'repeated publish did not report a clean idempotent result'
if grep -Fq '|push ' "$CCVALIDATE_GIT_LOG"; then fail 'repeated publish issued a push'; fi

publish_branch_repo="$(new_fixture publish-feature-branch)"
run_publish_failure "$publish_branch_repo" "$TEST_DIR/publish-refuse-branch.out"
assert_contains "$TEST_DIR/publish-refuse-branch.out" 'Current branch' 'publish did not refuse a feature checkout'
if grep -Eq '\|(fetch|push|branch -d) ' "$CCVALIDATE_GIT_LOG"; then fail 'branch refusal mutated Git'; fi

publish_dirty_repo="$(new_fixture publish-dirty)"
git_in "$publish_dirty_repo" switch -q main
git_in "$publish_dirty_repo" merge -q --ff-only feature/work
printf 'dirty\n' >>"$publish_dirty_repo/feature.txt"
run_publish_failure "$publish_dirty_repo" "$TEST_DIR/publish-refuse-dirty.out"
assert_contains "$TEST_DIR/publish-refuse-dirty.out" 'unstaged changes present' 'publish accepted a dirty worktree'

publish_staged_repo="$(new_fixture publish-staged)"
git_in "$publish_staged_repo" switch -q main
git_in "$publish_staged_repo" merge -q --ff-only feature/work
printf 'staged\n' >>"$publish_staged_repo/feature.txt"
git_in "$publish_staged_repo" add feature.txt
run_publish_failure "$publish_staged_repo" "$TEST_DIR/publish-refuse-staged.out"
assert_contains "$TEST_DIR/publish-refuse-staged.out" 'staged changes present' 'publish accepted staged changes'

publish_untracked_repo="$(new_fixture publish-untracked)"
git_in "$publish_untracked_repo" switch -q main
git_in "$publish_untracked_repo" merge -q --ff-only feature/work
printf 'implementation\n' >"$publish_untracked_repo/untracked.sh"
run_publish_failure "$publish_untracked_repo" "$TEST_DIR/publish-refuse-untracked.out"
assert_contains "$TEST_DIR/publish-refuse-untracked.out" 'untracked files present' 'publish accepted an untracked file'

publish_no_origin_repo="$(new_fixture publish-no-origin)"
git_in "$publish_no_origin_repo" switch -q main
git_in "$publish_no_origin_repo" merge -q --ff-only feature/work
git_in "$publish_no_origin_repo" remote remove origin
CCVALIDATE_EXPECTED_REPOSITORY_NAME="$(basename "$publish_no_origin_repo")"
CCVALIDATE_EXPECTED_ORIGIN="$TEST_DIR/missing-origin.git"
export CCVALIDATE_EXPECTED_REPOSITORY_NAME CCVALIDATE_EXPECTED_ORIGIN
: >"$CCVALIDATE_GIT_LOG"
# shellcheck disable=SC2016
assert_failure 'publish accepted a missing origin' bash -c \
    'cd "$1"; source "$2/bash/bash_functions"; ccvalidate publish' bash "$publish_no_origin_repo" "$PROJECT_ROOT" \
    >"$TEST_DIR/publish-refuse-origin.out" 2>&1
assert_contains "$TEST_DIR/publish-refuse-origin.out" 'missing or suspicious' 'publish did not explain missing origin'

publish_wrong_origin_repo="$(new_fixture publish-wrong-origin)"
git_in "$publish_wrong_origin_repo" switch -q main
git_in "$publish_wrong_origin_repo" merge -q --ff-only feature/work
set_fixture_contract "$publish_wrong_origin_repo"
CCVALIDATE_EXPECTED_ORIGIN="$TEST_DIR/not-authorized.git"
export CCVALIDATE_EXPECTED_ORIGIN
# shellcheck disable=SC2016
assert_failure 'publish accepted a wrong origin' bash -c \
    'cd "$1"; source "$2/bash/bash_functions"; ccvalidate publish' bash "$publish_wrong_origin_repo" "$PROJECT_ROOT" \
    >"$TEST_DIR/publish-refuse-wrong-origin.out" 2>&1

# Behind and diverged topologies are refused after a real fetch from a local
# bare remote; publish never integrates, rebases, resets, or force-pushes.
publish_behind_repo="$(new_fixture publish-behind)"
publish_behind_origin="$(git_in "$publish_behind_repo" remote get-url origin)"
publish_behind_peer="$TEST_DIR/publish-behind-peer"
git_in "$TEST_DIR" clone -q "$publish_behind_origin" "$publish_behind_peer"
printf 'remote\n' >"$publish_behind_peer/remote.txt"
commit_all "$publish_behind_peer" 'remote advance'
git_in "$publish_behind_peer" push -q origin main
git_in "$publish_behind_repo" switch -q main
run_publish_failure "$publish_behind_repo" "$TEST_DIR/publish-refuse-behind.out"
assert_contains "$TEST_DIR/publish-refuse-behind.out" 'local main is behind' 'publish accepted main behind origin/main'

publish_diverged_repo="$(new_fixture publish-diverged)"
publish_diverged_origin="$(git_in "$publish_diverged_repo" remote get-url origin)"
publish_diverged_peer="$TEST_DIR/publish-diverged-peer"
git_in "$TEST_DIR" clone -q "$publish_diverged_origin" "$publish_diverged_peer"
printf 'remote\n' >"$publish_diverged_peer/remote.txt"
commit_all "$publish_diverged_peer" 'remote advance'
git_in "$publish_diverged_peer" push -q origin main
git_in "$publish_diverged_repo" switch -q main
git_in "$publish_diverged_repo" merge -q --ff-only feature/work
run_publish_failure "$publish_diverged_repo" "$TEST_DIR/publish-refuse-diverged.out"
assert_contains "$TEST_DIR/publish-refuse-diverged.out" 'diverged' 'publish accepted divergent main'

# A validation failure leaves both the remote and retained local feature intact.
publish_validation_repo="$(new_fixture publish-validation-fail)"
publish_validation_origin="$(git_in "$publish_validation_repo" remote get-url origin)"
publish_validation_remote="$(git_in "$publish_validation_origin" rev-parse refs/heads/main)"
make_interrupted_finish "$publish_validation_repo" "$TEST_DIR/publish-validation-interrupted.out"
export CCVALIDATE_FAIL_BRANCH=main CCVALIDATE_FAIL_BRANCH_COMMAND='release check'
run_publish_failure "$publish_validation_repo" "$TEST_DIR/publish-validation-fail.out"
unset CCVALIDATE_FAIL_BRANCH CCVALIDATE_FAIL_BRANCH_COMMAND
[ "$(git_in "$publish_validation_origin" rev-parse refs/heads/main)" = "$publish_validation_remote" ] ||
    fail 'publish validation failure changed remote main'
git_in "$publish_validation_repo" show-ref --verify --quiet refs/heads/feature/work ||
    fail 'publish validation failure deleted retained feature'

# A remote update occurring during validation is detected by the second fetch,
# even though initial topology was acceptable.
publish_changed_repo="$(new_fixture publish-remote-changed)"
publish_changed_origin="$(git_in "$publish_changed_repo" remote get-url origin)"
publish_changed_peer="$TEST_DIR/publish-changed-peer"
git_in "$TEST_DIR" clone -q "$publish_changed_origin" "$publish_changed_peer"
printf 'remote change\n' >"$publish_changed_peer/remote-change.txt"
commit_all "$publish_changed_peer" 'advance during validation'
make_interrupted_finish "$publish_changed_repo" "$TEST_DIR/publish-changed-interrupted.out"
export CCVALIDATE_ADVANCE_REMOTE_ON_VALIDATE=1
export CCVALIDATE_REMOTE_ADVANCE_PEER="$publish_changed_peer"
rm -f "$CCVALIDATE_REMOTE_ADVANCED_MARKER"
run_publish_failure "$publish_changed_repo" "$TEST_DIR/publish-remote-changed.out"
unset CCVALIDATE_ADVANCE_REMOTE_ON_VALIDATE CCVALIDATE_REMOTE_ADVANCE_PEER
assert_contains "$TEST_DIR/publish-remote-changed.out" 'Remote unchanged' 'publish did not detect a remote change during validation'
git_in "$publish_changed_repo" show-ref --verify --quiet refs/heads/feature/work ||
    fail 'remote-change refusal deleted retained feature'

publish_push_fail_repo="$(new_fixture publish-push-fail)"
publish_push_fail_origin="$(git_in "$publish_push_fail_repo" remote get-url origin)"
make_interrupted_finish "$publish_push_fail_repo" "$TEST_DIR/publish-push-interrupted.out"
cat >"$publish_push_fail_origin/hooks/pre-receive" <<'EOF_PUBLISH_HOOK'
#!/usr/bin/env bash
exit 1
EOF_PUBLISH_HOOK
chmod 700 "$publish_push_fail_origin/hooks/pre-receive"
run_publish_failure "$publish_push_fail_repo" "$TEST_DIR/publish-push-fail.out"
assert_contains "$TEST_DIR/publish-push-fail.out" 'Push origin/main' 'publish push failure was not reported'
git_in "$publish_push_fail_repo" show-ref --verify --quiet refs/heads/feature/work || fail 'push failure deleted feature'

publish_verify_fail_repo="$(new_fixture publish-verify-fail)"
make_interrupted_finish "$publish_verify_fail_repo" "$TEST_DIR/publish-verify-interrupted.out"
export CCVALIDATE_FAIL_REMOTE_VERIFY=1
run_publish_failure "$publish_verify_fail_repo" "$TEST_DIR/publish-verify-fail.out"
unset CCVALIDATE_FAIL_REMOTE_VERIFY
assert_contains "$TEST_DIR/publish-verify-fail.out" 'Remote verification' 'publish verification failure was not reported'
git_in "$publish_verify_fail_repo" show-ref --verify --quiet refs/heads/feature/work || fail 'verification failure deleted feature'

# Without valid ownership state, publication may succeed but branch cleanup is
# a warning and no local branch is guessed. A moved/unmerged retained branch is
# likewise preserved despite a valid original marker.
publish_unknown_repo="$(new_fixture publish-unknown-feature)"
git_in "$publish_unknown_repo" switch -q main
git_in "$publish_unknown_repo" merge -q --ff-only feature/work
mkdir -p "$publish_unknown_repo/.git/ccvalidate"
printf 'version=corrupt\nfeature_branch=feature/work\n' >"$publish_unknown_repo/.git/ccvalidate/finish-state"
set_fixture_contract "$publish_unknown_repo"
(cd "$publish_unknown_repo" && ccvalidate publish) >"$TEST_DIR/publish-unknown.out" 2>&1 ||
    fail 'publication with unknown cleanup ownership failed'
git_in "$publish_unknown_repo" show-ref --verify --quiet refs/heads/feature/work || fail 'publish guessed and deleted an unknown branch'
assert_contains "$TEST_DIR/publish-unknown.out" 'retained work branch is unknown' 'unknown cleanup was not reported'

publish_unmerged_repo="$(new_fixture publish-unmerged-feature)"
make_interrupted_finish "$publish_unmerged_repo" "$TEST_DIR/publish-unmerged-interrupted.out"
git_in "$publish_unmerged_repo" switch -q feature/work
printf 'later\n' >"$publish_unmerged_repo/later.txt"
commit_all "$publish_unmerged_repo" 'unmerged later work'
git_in "$publish_unmerged_repo" switch -q main
set_fixture_contract "$publish_unmerged_repo"
(cd "$publish_unmerged_repo" && ccvalidate publish) >"$TEST_DIR/publish-unmerged.out" 2>&1 ||
    fail 'publication should succeed while unsafe cleanup warns'
git_in "$publish_unmerged_repo" show-ref --verify --quiet refs/heads/feature/work || fail 'publish deleted an altered feature branch'
assert_contains "$TEST_DIR/publish-unmerged.out" 'no longer matches recorded work HEAD' 'altered work cleanup was not refused'

publish_cleanup_fail_repo="$(new_fixture publish-cleanup-fail)"
publish_cleanup_fail_origin="$(git_in "$publish_cleanup_fail_repo" remote get-url origin)"
make_interrupted_finish "$publish_cleanup_fail_repo" "$TEST_DIR/publish-cleanup-interrupted.out"
export CCVALIDATE_FAIL_BRANCH_CLEANUP=1
run_publish_failure "$publish_cleanup_fail_repo" "$TEST_DIR/publish-cleanup-fail.out"
unset CCVALIDATE_FAIL_BRANCH_CLEANUP
[ "$(git_in "$publish_cleanup_fail_origin" rev-parse refs/heads/main)" = \
   "$(git_in "$publish_cleanup_fail_repo" rev-parse main)" ] ||
    fail 'cleanup failure obscured or prevented successful publication'
git_in "$publish_cleanup_fail_repo" show-ref --verify --quiet refs/heads/feature/work ||
    fail 'cleanup failure removed the retained branch'
assert_contains "$TEST_DIR/publish-cleanup-fail.out" 'Push origin/main' 'cleanup failure output omitted successful push stage'
assert_contains "$TEST_DIR/publish-cleanup-fail.out" 'Remote verification' 'cleanup failure output omitted successful verification stage'

publish_wrong_repo="$(new_fixture publish-wrong-repository)"
git_in "$publish_wrong_repo" switch -q main
git_in "$publish_wrong_repo" merge -q --ff-only feature/work
set_fixture_contract "$publish_wrong_repo"
CCVALIDATE_EXPECTED_REPOSITORY_NAME='CaptainCronos-01-ShellToolkit'
export CCVALIDATE_EXPECTED_REPOSITORY_NAME
# shellcheck disable=SC2016
assert_failure 'publish accepted the wrong repository' bash -c \
    'cd "$1"; source "$2/bash/bash_functions"; ccvalidate publish' bash "$publish_wrong_repo" "$PROJECT_ROOT" \
    >"$TEST_DIR/publish-refuse-wrong-repo.out" 2>&1
assert_contains "$TEST_DIR/publish-refuse-wrong-repo.out" 'Repository context' 'wrong publish repository was not explained'

assert_contains "$TEST_DIR/finish-success.out" 'Remote refresh' 'finish did not use shared publication refresh logic'
assert_contains "$CCVALIDATE_CC_LOG" 'main|release check' 'publish did not run the release gate on main'

if grep -Eq '_ccvalidate_git[[:space:]]+(reset|stash)|_ccvalidate_git[[:space:]]+push[^\n]*--force|_ccvalidate_git[[:space:]]+branch[[:space:]]+-D' \
    "$PROJECT_ROOT/bash/bash_functions"; then
    fail 'unsafe force/reset/stash path is reachable from ccvalidate'
fi
if grep -Eq '_ccvalidate_validation[[:space:]]+publish|ccvalidate[[:space:]]+publish' \
    <(sed -n '/^_ccvalidate_publish()/,/^}/p' "$PROJECT_ROOT/bash/bash_functions"); then
    fail 'publish validation recursively invoked publish'
fi
if grep -Eq 'sudo|apt-get|dnf|pacman|systemctl|grub|bootloader|browser' "$CCVALIDATE_GIT_LOG"; then
    fail 'finish attempted an external system mutation'
fi
if LC_ALL=C grep -q $'\033' "$TEST_DIR/finish-success.out" "$TEST_DIR/publish-"*.out "$TEST_DIR/refuse-"*.out "$TEST_DIR/"*-fail.out; then
    fail 'redirected ccvalidate workflow output contained ANSI escapes'
fi

printf 'Local validation workflow tests: PASS\n'
