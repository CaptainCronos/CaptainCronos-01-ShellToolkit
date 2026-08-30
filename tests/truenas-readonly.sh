#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE_ROOT="$PROJECT_ROOT/tests/fixtures/truenas"
PLUGIN="$PROJECT_ROOT/plugins/truenas-readonly/run"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_contains() {
    local text="$1" expected="$2" label="$3"
    printf '%s\n' "$text" | grep -Fq -- "$expected" || fail "$label"
}

source "$PROJECT_ROOT/lib/cc-capabilities.sh"

# Platform evidence requires Debian identity, the TrueNAS production kernel
# marker, a version file value, and the fixed executable path together.
CC_TEST_OS_ID=debian
CC_TEST_KERNEL=6.12.0-production+truenas
CC_TEST_VERSION=25.10.3
CC_TEST_MIDCLT="$FIXTURE_ROOT/fake-midclt"
cc_platform_os_id() { printf '%s\n' "$CC_TEST_OS_ID"; }
cc_platform_kernel() { printf '%s\n' "$CC_TEST_KERNEL"; }
cc_platform_truenas_version() { printf '%s\n' "$CC_TEST_VERSION"; }
_cc_platform_truenas_midclt_path() { printf '%s\n' "$CC_TEST_MIDCLT"; }
cc_platform_is_truenas_scale || fail 'positive SCALE evidence was rejected'
[ "$(cc_platform_type)" = truenas-scale ] || fail 'positive SCALE fixture type was wrong'

CC_TEST_OS_ID=ubuntu
if cc_platform_is_truenas_scale; then fail 'Ubuntu false-positive as TrueNAS SCALE'; fi
CC_TEST_OS_ID=debian CC_TEST_KERNEL=6.12.0-generic
if cc_platform_is_truenas_scale; then fail 'ordinary Debian false-positive as TrueNAS SCALE'; fi
CC_TEST_KERNEL=6.12.0-production+truenas CC_TEST_MIDCLT="$TEST_DIR/missing-midclt"
if cc_platform_is_truenas_scale; then fail 'missing midclt passed SCALE evidence'; fi
CC_TEST_MIDCLT="$FIXTURE_ROOT/fake-midclt"

trace="$TEST_DIR/methods.trace"
: >"$trace"
run_inventory() {
    CC_TRUENAS_MIDCLT_PATH="$FIXTURE_ROOT/fake-midclt" \
        CC_TRUENAS_TIMEOUT_PATH=/usr/bin/timeout \
        CC_TRUENAS_TIMEOUT_SECONDS="${CC_TEST_TIMEOUT_SECONDS:-2}" \
        CC_PLUGIN_ID='' \
        CC_TOOLKIT_ROOT="$PROJECT_ROOT" \
        CC_FAKE_MIDCLT_TRACE="$trace" \
        CC_TRUENAS_FIXTURE_ROOT="$FIXTURE_ROOT" \
        CC_FAKE_MIDCLT_FAIL_METHOD="${CC_TEST_FAIL_METHOD:-}" \
        CC_FAKE_MIDCLT_SLEEP_METHOD="${CC_TEST_SLEEP_METHOD:-}" \
        CC_FAKE_MIDCLT_MALFORMED_METHOD="${CC_TEST_MALFORMED_METHOD:-}" \
        "$PLUGIN" "$1"
}

for operation in system pools datasets disks network; do
    output="$(run_inventory "$operation")" || fail "$operation fixture failed"
    assert_contains "$output" "\"operation\": \"$operation\"" "$operation normalization was absent"
done
assert_contains "$(run_inventory datasets)" 'tank/media' 'nested dataset was not normalized'
assert_contains "$(run_inventory network)" '192.0.2.10' 'network address was not normalized'
if run_inventory arbitrary.method >/dev/null 2>&1; then fail 'arbitrary method injection was accepted'; fi
[ "$(run_inventory arbitrary.method >/dev/null 2>&1; printf '%s' "$?")" -eq 2 ] || fail 'unknown operation was not a usage error'

CC_TEST_MALFORMED_METHOD=system.info
if run_inventory system >/dev/null 2>&1; then fail 'malformed JSON was accepted'; fi
[ "$(run_inventory system >/dev/null 2>&1; printf '%s' "$?")" -eq 65 ] || fail 'malformed JSON status changed'
CC_TEST_MALFORMED_METHOD=

CC_TEST_FAIL_METHOD=pool.query
if run_inventory pools >/dev/null 2>&1; then fail 'midclt failure was hidden'; fi
[ "$(run_inventory pools >/dev/null 2>&1; printf '%s' "$?")" -eq 42 ] || fail 'midclt status was not propagated'
CC_TEST_FAIL_METHOD=
run_inventory system >/dev/null || fail 'one subsystem failure poisoned another operation'

CC_TEST_SLEEP_METHOD=interface.query CC_TEST_TIMEOUT_SECONDS=1
if run_inventory network >/dev/null 2>&1; then fail 'midclt timeout was not bounded'; fi
[ "$(run_inventory network >/dev/null 2>&1; printf '%s' "$?")" -eq 124 ] || fail 'timeout status was not propagated'
CC_TEST_SLEEP_METHOD='' CC_TEST_TIMEOUT_SECONDS=2

sort -u "$trace" >"$TEST_DIR/methods.unique"
while IFS= read -r method; do
    case "$method" in
        system.info|pool.query|pool.dataset.query|disk.query|interface.query) ;;
        *) fail "non-allowlisted middleware method recorded: $method" ;;
    esac
    case "$method" in
        *.create|*.update|*.delete|*.start|*.stop|*.restart|*.acknowledge|*.install)
            fail "mutation middleware method recorded: $method"
            ;;
    esac
done <"$TEST_DIR/methods.unique"
[ "$(wc -l <"$TEST_DIR/methods.unique")" -eq 5 ] || fail 'fixed method allowlist was not fully exercised'

# Capability resolution stays passive. With a fixture platform/dependency it
# becomes available; the entrypoint trace remains unchanged.
cap_toolkit="$TEST_DIR/cap-toolkit" cap_host="$TEST_DIR/cap-host"
mkdir -p "$cap_toolkit/plugins" "$cap_toolkit/config" "$cap_host/plugins"
chmod 700 "$cap_toolkit/plugins" "$cap_host/plugins"
cp "$PROJECT_ROOT/config/programs.conf" "$cap_toolkit/config/programs.conf"
cp -a "$PROJECT_ROOT/plugins/truenas-readonly" "$cap_toolkit/plugins/"
fake_bin="$TEST_DIR/bin"
mkdir "$fake_bin"
ln -s "$FIXTURE_ROOT/fake-midclt" "$fake_bin/midclt"
before_count="$(wc -l <"$trace")"
cc_platform_type() { printf '%s\n' truenas-scale; }
result="$(PATH="$fake_bin:/usr/bin:/bin" TOOLKIT_ROOT="$cap_toolkit" CC_HOST_HOME="$cap_host" cc_capability_result truenas.inventory.read)"
assert_contains "$result" $'available\tPASS\tplugin/truenas-readonly' 'healthy capability was unavailable'
[ "$(wc -l <"$trace")" -eq "$before_count" ] || fail 'capability resolution executed midclt'
chmod 600 "$cap_toolkit/plugins/truenas-readonly/run"
result="$(PATH="$fake_bin:/usr/bin:/bin" TOOLKIT_ROOT="$cap_toolkit" CC_HOST_HOME="$cap_host" cc_capability_result truenas.inventory.read)"
assert_contains "$result" $'unavailable\tFAIL' 'unsafe capability remained available'

printf 'TrueNAS read-only fixture tests: PASS\n'
