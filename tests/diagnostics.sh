#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-diagnostics.sh"
source "$PROJECT_ROOT/lib/cc-programs.sh"
source "$PROJECT_ROOT/lib/cc-platform.sh"
source "$PROJECT_ROOT/lib/cc-deps.sh"
source "$PROJECT_ROOT/lib/cc-smart.sh"
source "$PROJECT_ROOT/lib/cc-services.sh"

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
cc_debug 'disabled diagnostic' 2>"$TEST_DIR/disabled.err"
[ ! -s "$TEST_DIR/disabled.err" ] || fail 'disabled debugging emitted output'

cc_debug_enable
stdout="$(cc_debug_kv subsystem diagnostics 2>"$TEST_DIR/debug.err")"
[ -z "$stdout" ] || fail 'debug diagnostic contaminated stdout'
grep -Fq '[CC DEBUG] subsystem: diagnostics' "$TEST_DIR/debug.err" || fail 'debug diagnostic was not enabled'

cc_debug_kv 'API token' 'captain-secret-value' 2>"$TEST_DIR/secret.err"
grep -Fq '[REDACTED: present]' "$TEST_DIR/secret.err" || fail 'sensitive debug value was not redacted'
if grep -Fq 'captain-secret-value' "$TEST_DIR/secret.err"; then
    fail 'sensitive debug value was exposed'
fi

expected_pkg_manager="$(cc_dep_resolve_program pkg-manager 2>/dev/null)"
cc_dep_execution_status pkg-manager >/dev/null 2>"$TEST_DIR/semantic.err"
grep -Fq 'dependency requested: pkg-manager' "$TEST_DIR/semantic.err" || fail 'semantic dependency request was not diagnosed'
grep -Fq 'dependency class: semantic capability' "$TEST_DIR/semantic.err" || fail 'semantic dependency classification was absent'
grep -Fq 'resolver: Program Management' "$TEST_DIR/semantic.err" || fail 'semantic capability resolver was absent'
grep -Fq "selected implementation: $expected_pkg_manager" "$TEST_DIR/semantic.err" || fail 'selected package implementation was absent'
grep -Fq 'capability status: OK' "$TEST_DIR/semantic.err" || fail 'semantic capability status was absent'

cc_dep_execution_status bash >/dev/null 2>"$TEST_DIR/literal.err"
grep -Fq 'dependency class: literal executable' "$TEST_DIR/literal.err" || fail 'literal dependency classification was absent'
grep -Fq 'command lookup: bash' "$TEST_DIR/literal.err" || fail 'literal command lookup was absent'

smart_text="$(cat "$PROJECT_ROOT/tests/fixtures/smart/sandisk-ultra-ii.txt")"
cc_debug_kv 'SMART input fixture' 'sandisk-ultra-ii.txt' 2>"$TEST_DIR/smart.err"
cc_smart_attr_raw "$smart_text" Temperature_Celsius >/dev/null 2>>"$TEST_DIR/smart.err"
cc_smart_attr_normalized "$smart_text" Media_Wearout_Indicator >/dev/null 2>>"$TEST_DIR/smart.err"
grep -Fq 'SMART field selected: RAW_VALUE column 10' "$TEST_DIR/smart.err" || fail 'SMART raw field selection was absent'
grep -Fq 'raw parsed value: 34' "$TEST_DIR/smart.err" || fail 'SMART raw value was absent'
grep -Fq 'normalized value: 8' "$TEST_DIR/smart.err" || fail 'SMART normalized value was absent'

if cc_smart_device_candidate zram0 2>"$TEST_DIR/storage.err"; then
    fail 'RAM-backed device became a physical candidate'
fi
grep -Fq 'backing type: RAM' "$TEST_DIR/storage.err" || fail 'RAM backing diagnosis was absent'
grep -Fq 'physical-drive candidate: no' "$TEST_DIR/storage.err" || fail 'storage exclusion diagnosis was absent'

expected_service_manager="$(_cc_service_manager 2>/dev/null)" || fail 'service manager resolution failed'
_cc_service_manager >/dev/null 2>"$TEST_DIR/service.err" || fail 'service manager resolution failed'
grep -Fq 'service platform adapter:' "$TEST_DIR/service.err" || fail 'service platform adapter was absent'
grep -Fq "selected implementation: $expected_service_manager" "$TEST_DIR/service.err" || fail 'service implementation was absent'

cat > "$TEST_DIR/failing-service-manager" <<'EOF_SERVICE'
#!/usr/bin/env bash
exit 23
EOF_SERVICE
chmod 755 "$TEST_DIR/failing-service-manager"
PATH="$TEST_DIR:$PATH"
export PATH
export CC_SERVICE_MANAGER=failing-service-manager
export CC_PROGRAMS_LOADED=1
cc_platform_init_system() { printf '%s\n' systemd; }
set +e
_cc_service_list_timers user >/dev/null 2>"$TEST_DIR/service-failure.err"
service_status=$?
set -e
[ "$service_status" -eq 23 ] || fail 'service-manager failure status was not preserved'
grep -Fq 'underlying exit status: 23' "$TEST_DIR/service-failure.err" || fail 'service-manager failure status was not diagnosed'
grep -Fq 'failure propagation: service manager -> semantic helper -> caller' "$TEST_DIR/service-failure.err" || fail 'service failure propagation was absent'

printf '%s\n' 'partial result' > "$TEST_DIR/failure.stdout"
printf '%s\n' 'API_TOKEN=captain-secret-value' > "$TEST_DIR/failure.stderr"
cc_debug_result 0 7 "$TEST_DIR/failure.stdout" "$TEST_DIR/failure.stderr" 2>"$TEST_DIR/failure.err"
grep -Fq 'actual exit status: 7' "$TEST_DIR/failure.err" || fail 'failing exit status was not diagnosed'
grep -Fq 'captured stdout: partial result' "$TEST_DIR/failure.err" || fail 'captured stdout was not diagnosed'
grep -Fq 'captured stderr: API_TOKEN=[REDACTED]' "$TEST_DIR/failure.err" || fail 'captured stderr was not safely diagnosed'
grep -Fq 'failure propagation:' "$TEST_DIR/failure.err" || fail 'failure propagation path was absent'
if grep -Fq 'captain-secret-value' "$TEST_DIR/failure.err"; then
    fail 'captured diagnostic exposed a representative secret'
fi

printf 'Diagnostic framework tests: PASS\n'
