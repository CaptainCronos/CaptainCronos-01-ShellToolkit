#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

TEST_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

set +e
bash "$PROJECT_ROOT/tools/cc" selftest --json 2>"$TEST_DIR/normal.err" | tee "$TEST_DIR/normal.json" >/dev/null
normal_status=${PIPESTATUS[0]}
bash "$PROJECT_ROOT/tools/cc" selftest --debug --json >"$TEST_DIR/debug.json" 2>"$TEST_DIR/debug.err"
debug_status=$?
bash "$PROJECT_ROOT/tools/cc" selftest >"$TEST_DIR/redirected.out" 2>"$TEST_DIR/redirected.err"
redirected_status=$?
set -e

[ "$normal_status" -eq "$debug_status" ] || fail 'debug mode changed selftest exit status'
[ "$normal_status" -eq "$redirected_status" ] || fail 'redirection changed selftest exit status'
jq -e '.status and (.passed | type == "number") and (.failed | type == "number")' "$TEST_DIR/normal.json" >/dev/null || fail 'normal JSON output was invalid'
jq -e '.status and (.passed | type == "number") and (.failed | type == "number")' "$TEST_DIR/debug.json" >/dev/null || fail 'debug JSON output was corrupted'
[ "$(jq -r '.status' "$TEST_DIR/normal.json")" = "$(jq -r '.status' "$TEST_DIR/debug.json")" ] || fail 'debug mode changed summary status'
if grep -Fq '[CC DEBUG]' "$TEST_DIR/normal.err"; then
    fail 'normal selftest emitted debug diagnostics'
fi
grep -Fq '[CC DEBUG]' "$TEST_DIR/debug.err" || fail 'selftest --debug emitted no diagnostics'
grep -Fq '[CC TEST] [1/36] Common library ... RUNNING' "$TEST_DIR/debug.err" || fail 'debug sequential activity was absent'
grep -Fq '[CC TEST] [36/36] Plugin status load' "$TEST_DIR/debug.err" || fail 'debug completed/total count was absent'
if grep -q $'\r\|\033' "$TEST_DIR/debug.err"; then
    fail 'debug selftest emitted terminal animation'
fi
if grep -Fq '[CC DEBUG]' "$TEST_DIR/debug.json" || grep -Fq '[CC TEST]' "$TEST_DIR/debug.json"; then
    fail 'diagnostics contaminated structured stdout'
fi
grep -Fq 'Common library' "$TEST_DIR/redirected.out" || fail 'redirected selftest output was unreadable'
grep -Fq 'Overall Status:' "$TEST_DIR/redirected.out" || fail 'redirected selftest summary was absent'
if grep -q $'\r\|\033\[2K' "$TEST_DIR/redirected.out" "$TEST_DIR/redirected.err"; then
    fail 'redirected selftest emitted terminal animation'
fi

set +e
bash "$PROJECT_ROOT/tools/cc" selftest --debug-invalid >/dev/null 2>&1
invalid_status=$?
set -e
[ "$invalid_status" -eq 1 ] || fail 'invalid debug option returned an unexpected status'

printf 'Selftest output-contract tests: PASS\n'
