#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-diagnostics.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

TEST_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

cc_debug_disable
cc_progress_terminal_available() { return 1; }
cc_progress_init 'Noninteractive test' 2 0
cc_progress_start 'First operation' 2>"$TEST_DIR/noninteractive.err"
cc_progress_finish PASS 2>>"$TEST_DIR/noninteractive.err"
[ ! -s "$TEST_DIR/noninteractive.err" ] || fail 'non-TTY progress emitted terminal presentation'
[ "$CC_PROGRESS_COMPLETED" -eq 1 ] || fail 'completed count was incorrect'
[ "$CC_PROGRESS_TOTAL" -eq 2 ] || fail 'total count was incorrect'

cc_progress_terminal_available() { return 0; }
cc_progress_init 'Interactive test' 2 0 TEST
{
    cc_progress_start 'Current operation'
    cc_progress_finish PASS
} 2>"$TEST_DIR/interactive.err"
grep -Fq '[ 1/2] Current operation ... RUNNING' "$TEST_DIR/interactive.err" || fail 'interactive current activity was absent'
grep -Fq '[ 1/2] Current operation ... PASS' "$TEST_DIR/interactive.err" || fail 'interactive completion status was absent'
grep -q $'\r' "$TEST_DIR/interactive.err" || fail 'interactive progress did not use a live line'

cc_debug_enable
cc_progress_init 'Debug test' 1 0 TEST
{
    cc_progress_start 'Failing operation'
    set +e
    false
    operation_status=$?
    set -e
    cc_progress_finish FAIL
} 2>"$TEST_DIR/debug.err"
[ "$operation_status" -eq 1 ] || fail 'progress reporting altered operation exit status'
grep -Fq '[CC TEST] [1/1] Failing operation ... RUNNING' "$TEST_DIR/debug.err" || fail 'debug activity line was absent'
grep -Fq '[CC TEST] [1/1] Failing operation ... FAIL' "$TEST_DIR/debug.err" || fail 'debug failure status was absent'
if grep -q $'\r\|\033' "$TEST_DIR/debug.err"; then
    fail 'debug progress used terminal animation'
fi

cc_debug_disable
cc_progress_init 'Machine test' 1 1
machine_stdout="$TEST_DIR/machine.stdout"
machine_stderr="$TEST_DIR/machine.stderr"
{
    cc_progress_start 'JSON operation'
    printf '%s\n' '{"status":"PASS"}'
    cc_progress_finish PASS
} >"$machine_stdout" 2>"$machine_stderr"
[ "$(cat "$machine_stdout")" = '{"status":"PASS"}' ] || fail 'progress contaminated machine-readable stdout'
[ ! -s "$machine_stderr" ] || fail 'non-debug machine mode emitted progress'

cc_progress_terminal_available() { return 0; }
cc_progress_init 'Cleanup test' 1 0
cc_progress_start 'Interrupted operation' 2>"$TEST_DIR/cleanup.err"
cc_progress_cleanup 2>>"$TEST_DIR/cleanup.err"
[ "$CC_PROGRESS_ACTIVE" -eq 0 ] || fail 'progress cleanup retained active terminal state'

printf 'Progress framework tests: PASS\n'
