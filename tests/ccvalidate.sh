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
exec "$REAL_GIT" "\$@"
EOF_GIT
chmod 700 "$TEST_DIR/bin/git-fixture"

export CCVALIDATE_TEST_MODE=1
export CCVALIDATE_CC_BIN="$TEST_DIR/bin/cc-fixture"
export CCVALIDATE_GIT_BIN="$TEST_DIR/bin/git-fixture"
export CCVALIDATE_CC_LOG="$TEST_DIR/cc.log"
export CCVALIDATE_GIT_LOG="$TEST_DIR/git.log"
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

new_fixture() {
    local name="$1" repo origin
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
    git_in "$repo" switch -q -c feature/work
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
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|verify' 'full mode omitted verify'
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|selftest' 'full mode omitted selftest'
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|docs lint' 'full mode omitted docs lint'
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|docs check' 'full mode omitted docs check'
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|audit --strict' 'full mode omitted strict audit'

run_validation "$validation_repo" "$TEST_DIR/fast.out" fast
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|verify' 'fast mode omitted verify'
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|audit --strict' 'fast mode omitted strict audit'
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|docs lint' 'fast mode omitted docs lint'
if grep -Fq '|selftest' "$CCVALIDATE_CC_LOG"; then
    fail 'fast mode ran the expensive selftest'
fi

run_validation "$validation_repo" "$TEST_DIR/full.out" full
[ "$(wc -l <"$CCVALIDATE_CC_LOG")" -eq 5 ] || fail 'full mode command coverage changed unexpectedly'

run_validation "$validation_repo" "$TEST_DIR/release.out" release
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|selftest' 'release mode omitted selftest coverage'
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|release check' 'release mode omitted the release gate'
[ "$(wc -l <"$CCVALIDATE_CC_LOG")" -eq 2 ] || fail 'release mode duplicated checks owned by the release gate'

export CCVALIDATE_FAIL_MATCH=verify
: >"$CCVALIDATE_CC_LOG"
# shellcheck disable=SC2016
assert_failure 'required validation failure returned zero' \
    bash -c 'cd "$1"; source "$2/bash/bash_functions"; ccvalidate fast' bash "$validation_repo" "$PROJECT_ROOT" \
    >"$TEST_DIR/failure.out" 2>&1
unset CCVALIDATE_FAIL_MATCH
assert_contains "$TEST_DIR/failure.out" 'Repository verification' 'failure result was not rendered'
assert_contains "$TEST_DIR/failure.out" 'Overall Status:  FAIL' 'aggregate failure was not reported'
assert_contains "$CCVALIDATE_CC_LOG" 'feature/work|docs lint' 'independent checks did not continue after failure'

ccvalidate help >"$TEST_DIR/help.out"
ccvalidate --help >>"$TEST_DIR/help.out"
ccvalidate -h >>"$TEST_DIR/help.out"
assert_contains "$TEST_DIR/help.out" 'finish' 'help omitted finish mode'
assert_failure 'unknown mode returned zero' ccvalidate foo >"$TEST_DIR/unknown.out" 2>&1
assert_contains "$TEST_DIR/unknown.out" 'unknown mode: foo' 'unknown-mode help lacked context'

[ "$(git_in "$validation_repo" rev-parse HEAD)" = "$validation_head" ] || fail 'validation mode changed HEAD'
[ "$(git_in "$validation_repo" show-ref)" = "$validation_refs" ] || fail 'validation mode changed refs'
[ "$(git_in "$validation_repo" status --porcelain)" = "$validation_status" ] || fail 'validation mode changed the worktree'
if LC_ALL=C grep -q $'\033' "$TEST_DIR/bare.out" "$TEST_DIR/fast.out" "$TEST_DIR/full.out" "$TEST_DIR/release.out"; then
    fail 'redirected validation output contained ANSI escapes'
fi

run_finish_failure() {
    local repo="$1" output="$2"
    set_fixture_contract "$repo"
    : >"$CCVALIDATE_CC_LOG"
    : >"$CCVALIDATE_GIT_LOG"
    if (cd "$repo" && ccvalidate finish) >"$output" 2>&1; then
        fail "finish unexpectedly succeeded for $(basename "$repo")"
    fi
    git_in "$repo" show-ref --verify --quiet refs/heads/feature/work ||
        fail "feature branch was removed after failure in $(basename "$repo")"
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
assert_contains "$TEST_DIR/finish-success.out" 'Remote verification' 'finish did not report remote verification'
assert_contains "$TEST_DIR/finish-success.out" 'Overall Status:  PASS' 'successful finish did not return PASS'
while IFS='|' read -r directory arguments; do
    case "$arguments" in
        switch\ *|pull\ *|merge\ *|push\ *|branch\ -d\ *)
            case "$directory" in "$success_repo"*) ;; *) fail 'Git mutation escaped the disposable fixture' ;; esac
            ;;
    esac
done <"$CCVALIDATE_GIT_LOG"

main_repo="$(new_fixture finish-main)"
git_in "$main_repo" switch -q main
run_finish_failure "$main_repo" "$TEST_DIR/refuse-main.out"
assert_contains "$TEST_DIR/refuse-main.out" 'Feature branch' 'main-branch refusal was not explained'

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
assert_contains "$TEST_DIR/refuse-diverged-main.out" 'updated main diverged from feature' 'updated-main divergence was not reported'

feature_fail_repo="$(new_fixture finish-feature-validation-fail)"
export CCVALIDATE_FAIL_BRANCH='feature/work'
export CCVALIDATE_FAIL_BRANCH_COMMAND='selftest'
run_finish_failure "$feature_fail_repo" "$TEST_DIR/feature-validation-fail.out"
unset CCVALIDATE_FAIL_BRANCH CCVALIDATE_FAIL_BRANCH_COMMAND
[ "$(git_in "$feature_fail_repo" branch --show-current)" = feature/work ] || fail 'feature validation failure switched branches'
assert_contains "$TEST_DIR/feature-validation-fail.out" 'Feature validation' 'feature validation failure was not reported'

post_fail_repo="$(new_fixture finish-post-validation-fail)"
post_fail_origin="$(git_in "$post_fail_repo" remote get-url origin)"
post_fail_remote_before="$(git_in "$post_fail_origin" rev-parse refs/heads/main)"
export CCVALIDATE_FAIL_BRANCH=main
export CCVALIDATE_FAIL_BRANCH_COMMAND=selftest
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

if grep -Eq '_ccvalidate_git[[:space:]]+(reset|stash)|_ccvalidate_git[[:space:]]+push[^\n]*--force|_ccvalidate_git[[:space:]]+branch[[:space:]]+-D' \
    "$PROJECT_ROOT/bash/bash_functions"; then
    fail 'unsafe force/reset/stash path is reachable from ccvalidate'
fi
if grep -Eq 'sudo|apt-get|dnf|pacman|systemctl|grub|bootloader|browser' "$CCVALIDATE_GIT_LOG"; then
    fail 'finish attempted an external system mutation'
fi
if LC_ALL=C grep -q $'\033' "$TEST_DIR/finish-success.out" "$TEST_DIR/refuse-"*.out "$TEST_DIR/"*-fail.out; then
    fail 'redirected finish output contained ANSI escapes'
fi

printf 'Local validation workflow tests: PASS\n'
