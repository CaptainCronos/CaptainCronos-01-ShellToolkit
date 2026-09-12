#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-diagnostics.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

reject() {
    local rc
    set +e
    "$@" >/dev/null 2>&1
    rc=$?
    set -e
    [ "$rc" -eq 2 ] || fail "expected validation failure (2): $*; got $rc"
}

assert_state() {
    local total="$1" current="$2" completed="$3" active="$4"
    [ "$CC_PROGRESS_TOTAL" = "$total" ] || fail "total expected $total, got $CC_PROGRESS_TOTAL"
    [ "$CC_PROGRESS_CURRENT" = "$current" ] || fail "current expected $current, got $CC_PROGRESS_CURRENT"
    [ "$CC_PROGRESS_COMPLETED" = "$completed" ] || fail "completed expected $completed, got $CC_PROGRESS_COMPLETED"
    [ "$CC_PROGRESS_ACTIVE" = "$active" ] || fail "active expected $active, got $CC_PROGRESS_ACTIVE"
}

TEST_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

cc_debug_disable
cc_progress_terminal_available() { return 1; }

# Initialization validates before mutating state, and pre-init transitions fail.
reject cc_progress_start 'before init'
reject cc_progress_finish PASS
reject cc_progress_init
reject cc_progress_init '' 1
reject cc_progress_init 'missing total'
reject cc_progress_init 'zero' 0
reject cc_progress_init 'negative' -1
reject cc_progress_init 'nonnumeric' one
reject cc_progress_init 'machine' 1 2
reject cc_progress_init 'tag' 1 0 'invalid tag'
reject cc_progress_init 'extra' 1 0 TEST extra
[ "$CC_PROGRESS_INITIALIZED" -eq 0 ] || fail 'invalid init initialized progress state'

cc_progress_init 'State test' 2
assert_state 2 0 0 0
[ "$CC_PROGRESS_INITIALIZED" -eq 1 ] || fail 'successful init did not set initialized state'
[ "$CC_PROGRESS_TAG" = STATUS ] || fail 'default tag was incorrect'
cc_progress_init 'Custom tag' 2 0 check_1
[ "$CC_PROGRESS_TAG" = CHECK_1 ] || fail 'custom tag was not normalized'
cc_progress_init 'Machine zero' 2 0
cc_progress_init 'Machine one' 2 1

# Starts and finishes are strict state transitions; failures preserve accounting.
cc_progress_init 'Transition test' 2 0 TEST
reject cc_progress_start
reject cc_progress_start ''
reject cc_progress_start first extra
assert_state 2 0 0 0
cc_progress_start first
assert_state 2 1 0 1
[ "$CC_PROGRESS_LABEL" = first ] || fail 'start did not retain operation label'
reject cc_progress_start second
assert_state 2 1 0 1
reject cc_progress_finish
reject cc_progress_finish ''
reject cc_progress_finish PASS extra
assert_state 2 1 0 1
cc_progress_finish PASS
assert_state 2 1 1 0
reject cc_progress_finish PASS
assert_state 2 1 1 0
cc_progress_start second
cc_progress_finish FAIL
assert_state 2 2 2 0
reject cc_progress_start beyond-total
assert_state 2 2 2 0

# Noninteractive presentation is silent and never uses stdout.
cc_progress_init 'Noninteractive test' 1 0
{
    cc_progress_start 'First operation'
    cc_progress_finish PASS
} >"$TEST_DIR/noninteractive.out" 2>"$TEST_DIR/noninteractive.err"
[ ! -s "$TEST_DIR/noninteractive.out" ] || fail 'progress wrote to stdout'
[ ! -s "$TEST_DIR/noninteractive.err" ] || fail 'non-TTY progress emitted terminal presentation'

# Simulated interactive mode owns stderr and performs live-line cleanup.
cc_progress_terminal_available() { return 0; }
cc_progress_init 'Interactive test' 2 0 TEST
{
    cc_progress_start 'Current operation'
    cc_progress_finish PASS
} >"$TEST_DIR/interactive.out" 2>"$TEST_DIR/interactive.err"
[ ! -s "$TEST_DIR/interactive.out" ] || fail 'interactive progress wrote to stdout'
grep -Fq '[ 1/2] Current operation ... RUNNING' "$TEST_DIR/interactive.err" || fail 'interactive current activity was absent'
grep -Fq '[ 1/2] Current operation ... PASS' "$TEST_DIR/interactive.err" || fail 'interactive completion status was absent'
grep -q $'\r' "$TEST_DIR/interactive.err" || fail 'interactive progress did not use a live line'

cc_progress_init 'Live cleanup test' 1 0 TEST
cc_progress_start 'Interrupted operation' 2>"$TEST_DIR/live-cleanup.err"
cc_progress_cleanup 2>>"$TEST_DIR/live-cleanup.err"
assert_state 1 1 0 0
[ "$(tail -c 1 "$TEST_DIR/live-cleanup.err" | od -An -t x1 | tr -d '[:space:]')" = 0a ] || fail 'live cleanup did not terminate the active line'
cc_progress_cleanup 2>>"$TEST_DIR/live-cleanup.err"
reject cc_progress_cleanup unexpected
assert_state 1 1 0 0

# Debug is sequential even with terminal support, and reporting preserves status.
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
cc_progress_init 'Sequential cleanup test' 1 0 TEST
cc_progress_start 'Interrupted sequential operation' 2>"$TEST_DIR/sequential-cleanup.err"
cc_progress_cleanup 2>>"$TEST_DIR/sequential-cleanup.err"
[ "$(wc -l < "$TEST_DIR/sequential-cleanup.err")" -eq 1 ] || fail 'sequential cleanup emitted output'

# Machine mode suppresses normal presentation while leaving stdout to the caller.
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

# Completion delegates semantic rendering to the shared status-line helper.
cc_status_line_fd() {
    local fd="$1" label="$2" status="$3" width="$4"
    printf 'STATUS-FD:%s:%s:%s\n' "$label" "$status" "$width" >&"$fd"
}
cc_progress_terminal_available() { return 0; }
cc_progress_init 'Status line test' 1 0 TEST
{
    cc_progress_start 'Integrated operation'
    cc_progress_finish PASS
} 2>"$TEST_DIR/status-line.err"
grep -Fq 'STATUS-FD:[CC TEST] [ 1/1] Integrated operation:PASS:62' "$TEST_DIR/status-line.err" || fail 'status-line helper was not used'
unset -f cc_status_line_fd

printf 'Progress framework tests: PASS\n'
