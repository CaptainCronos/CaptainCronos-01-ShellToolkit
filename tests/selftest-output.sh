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
registered="$(jq -r '.registered' "$TEST_DIR/normal.json")"
executed="$(jq -r '.executed' "$TEST_DIR/normal.json")"
passed="$(jq -r '.passed' "$TEST_DIR/normal.json")"
failed="$(jq -r '.failed' "$TEST_DIR/normal.json")"
[ "$registered" -eq "$executed" ] || fail 'announced total did not equal executed count'
[ "$((passed + failed))" -eq "$executed" ] || fail 'passed and failed counts did not equal executed count'
[ "$(jq -r '.registered' "$TEST_DIR/debug.json")" -eq "$registered" ] || fail 'debug mode changed registered count'
[ "$(jq -r '.executed' "$TEST_DIR/debug.json")" -eq "$executed" ] || fail 'debug mode changed executed count'
if grep -Fq '[CC DEBUG]' "$TEST_DIR/normal.err"; then
    fail 'normal selftest emitted debug diagnostics'
fi
grep -Fq '[CC DEBUG]' "$TEST_DIR/debug.err" || fail 'selftest --debug emitted no diagnostics'
grep -Fq "[CC TEST] [1/$registered] Common library ... RUNNING" "$TEST_DIR/debug.err" || fail 'debug sequential activity was absent'
grep -Eq "\[CC TEST\] \[$registered/$registered\] Plugin status load.*PASS" "$TEST_DIR/debug.err" || fail 'debug completed/total count was absent'
if grep -q $'\r\|\033' "$TEST_DIR/debug.err"; then
    fail 'debug selftest emitted terminal animation'
fi
if grep -Fq '[CC DEBUG]' "$TEST_DIR/debug.json" || grep -Fq '[CC TEST]' "$TEST_DIR/debug.json"; then
    fail 'diagnostics contaminated structured stdout'
fi
grep -Fq 'Common library' "$TEST_DIR/redirected.out" || fail 'redirected selftest output was unreadable'
grep -Fq 'Overall Status:' "$TEST_DIR/redirected.out" || fail 'redirected selftest summary was absent'
[ "$(grep -Ec '^\[CC TEST\].* (PASS|FAIL)$' "$TEST_DIR/redirected.out")" -eq "$registered" ] || fail 'redirected canonical result count did not equal registered count'
sed -n 's/^\[CC TEST\] \[ *\([0-9][0-9]*\)\/\([0-9][0-9]*\)\].* \(PASS\|FAIL\)$/\1 \2 \3/p' \
    "$TEST_DIR/redirected.out" > "$TEST_DIR/canonical-results"
awk -v total="$registered" '
    $1 != NR {exit 1}
    $2 != total {exit 1}
    END {if (NR != total) exit 1}
' "$TEST_DIR/canonical-results" || fail 'canonical numbering was not a unique 1..N sequence with an N denominator'
grep -Eq "^$registered $registered (PASS|FAIL)$" "$TEST_DIR/canonical-results" || fail 'final test was not N/N'
if grep -Eq 'Diagnostic framework tests: PASS|Progress framework tests: PASS|Shell helper tests: PASS|Package management tests: PASS' "$TEST_DIR/redirected.out"; then
    fail 'successful child summaries escaped harness capture'
fi
if grep -Eq 'RUNNING[^[:space:]]|RUNNING.*Captain Cronos Shell Toolkit' "$TEST_DIR/redirected.out" "$TEST_DIR/redirected.err"; then
    fail 'child output corrupted RUNNING presentation'
fi
if grep -q $'\r\|\033\[2K' "$TEST_DIR/redirected.out" "$TEST_DIR/redirected.err"; then
    fail 'redirected selftest emitted terminal animation'
fi

set +e
bash "$PROJECT_ROOT/tools/cc" selftest --debug-invalid >/dev/null 2>&1
invalid_status=$?
set -e
[ "$invalid_status" -eq 1 ] || fail 'invalid debug option returned an unexpected status'

printf 'Selftest output-contract tests: PASS\n'
