#!/usr/bin/env bash
# shellcheck disable=SC2329

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/tools/commands/selftest"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

TEST_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

reset_harness() {
    VERBOSE="$1"
    JSON=0
    DEBUG=0
    PASSED=0
    FAILED=0
    RESULTS=""
    SELFTEST_TOTAL="$2"
    SELFTEST_TEMP="$TEST_DIR"
    SELFTEST_LAST_STATUS=0
    cc_debug_disable
    cc_progress_init 'Selftest harness fixture' "$SELFTEST_TOTAL" 0 TEST
}

fixture_success() {
    printf 'child success summary: PASS\n'
}

fixture_noisy_success() {
    printf 'child stdout must remain subordinate\n'
    printf 'child stderr remains useful\n' >&2
}

fixture_failure() {
    printf 'failure stdout marker\n'
    printf 'failure stderr marker\n' >&2
    return 7
}

# Noninteractive normal and verbose execution prove canonical-line ownership,
# success-output suppression, labeled stderr, authoritative failure status, and
# aggregate accounting without invoking the recursive full selftest suite.
cc_progress_terminal_available() { return 1; }
reset_harness 1 3
{
    run_check 'Quiet success' fixture fixture_success
    run_check 'Noisy success' fixture fixture_noisy_success
    run_check 'Authoritative failure' fixture fixture_failure
} >"$TEST_DIR/sequential.out" 2>"$TEST_DIR/sequential.err"

[ "$SELFTEST_LAST_STATUS" -eq 7 ] || fail 'child exit status was not preserved'
[ "$PASSED" -eq 2 ] || fail 'successful child accounting was incorrect'
[ "$FAILED" -eq 1 ] || fail 'failed child accounting was incorrect'
[ "$CC_PROGRESS_COMPLETED" -eq 3 ] || fail 'executed count was incorrect'
[ "$((PASSED + FAILED))" -eq "$CC_PROGRESS_COMPLETED" ] || fail 'aggregate accounting did not equal execution count'
[ "$CC_PROGRESS_COMPLETED" -eq "$SELFTEST_TOTAL" ] || fail 'executed count did not equal announced total'
[ "$(grep -Ec '^\[CC TEST\].* (PASS|FAIL)$' "$TEST_DIR/sequential.out")" -eq 3 ] || fail 'canonical result count did not equal registered count'
[ "$(grep -Ec '^\[CC TEST\].* PASS$' "$TEST_DIR/sequential.out")" -eq 2 ] || fail 'successful children created duplicate canonical PASS results'
[ "$(grep -Ec '^\[CC TEST\].* FAIL$' "$TEST_DIR/sequential.out")" -eq 1 ] || fail 'failure did not produce exactly one canonical FAIL result'
grep -Eq '^\[CC TEST\] \[ 3/3\] Authoritative failure.* FAIL$' "$TEST_DIR/sequential.out" || fail 'final result was not N/N'
if grep -Fq 'child success summary: PASS' "$TEST_DIR/sequential.out"; then
    fail 'successful child stdout escaped capture'
fi
grep -Fq 'stdout captured: 1 lines' "$TEST_DIR/sequential.out" || fail 'verbose success capture summary was absent'
grep -Fq 'Noisy success stderr:' "$TEST_DIR/sequential.out" || fail 'successful child stderr was not labeled'
grep -Fq 'child stderr remains useful' "$TEST_DIR/sequential.out" || fail 'successful child stderr was lost'
grep -Fq 'Authoritative failure stdout:' "$TEST_DIR/sequential.out" || fail 'failure stdout was not associated with its test'
grep -Fq 'failure stdout marker' "$TEST_DIR/sequential.out" || fail 'failure stdout was lost'
grep -Fq 'Authoritative failure stderr:' "$TEST_DIR/sequential.out" || fail 'failure stderr was not associated with its test'
grep -Fq 'failure stderr marker' "$TEST_DIR/sequential.out" || fail 'failure stderr was lost'

# Simulated interactive progress proves that captured child output cannot attach
# to a live RUNNING line. The result is completed before any detail is emitted.
cc_progress_terminal_available() { return 0; }
reset_harness 1 1
run_check 'Interactive noisy success' fixture fixture_noisy_success \
    >"$TEST_DIR/interactive.out" 2>"$TEST_DIR/interactive.err"

if grep -Eq 'RUNNING(child|failure)|RUNNING.*child (stdout|stderr)' "$TEST_DIR/interactive.err"; then
    fail 'child output concatenated onto RUNNING presentation'
fi
[ "$(grep -Ec 'Interactive noisy success.*PASS' "$TEST_DIR/interactive.err")" -eq 1 ] || fail 'interactive result was not canonical and unique'
grep -Fq '[ 1/1] Interactive noisy success' "$TEST_DIR/interactive.err" || fail 'interactive total was incorrect'

# Normal mode is intentionally concise even when the successful child writes.
cc_progress_terminal_available() { return 1; }
reset_harness 0 1
run_check 'Normal noisy success' fixture fixture_noisy_success \
    >"$TEST_DIR/normal.out" 2>"$TEST_DIR/normal.err"
grep -Eq '^\[CC TEST\] \[ 1/1\] Normal noisy success.* PASS$' "$TEST_DIR/normal.out" || fail 'normal canonical result was absent'
if grep -Fq 'child stdout must remain subordinate' "$TEST_DIR/normal.out" ||
    grep -Fq 'child stderr remains useful' "$TEST_DIR/normal.out" "$TEST_DIR/normal.err"; then
    fail 'normal mode exposed successful child output'
fi

printf 'Selftest harness integrity tests: PASS\n'
