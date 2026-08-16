#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_DIR="$(mktemp -d)"
MOCK_RUNNER="$TEST_DIR/update-runner"

cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_contains() { printf '%s\n' "$1" | grep -Fq -- "$2" || fail "$3"; }

cat >"$MOCK_RUNNER" <<'EOF_RUNNER'
#!/usr/bin/env bash
shift
command_name="${1:-}"
printf 'mock stage: %s\n' "$command_name"
[ "$command_name" != "${CC_TEST_MARK_COMMAND:-none}" ] || : >"${CC_TEST_MARK_FILE:?}"
case "$command_name" in
    "${CC_TEST_FAIL_COMMAND:-none}") exit 7 ;;
    "${CC_TEST_WARN_COMMAND:-none}") exit 10 ;;
    "${CC_TEST_SKIP_COMMAND:-none}") exit 20 ;;
    *) exit 0 ;;
esac
EOF_RUNNER
chmod 700 "$MOCK_RUNNER"

run_update() {
    env CC_UPDATE_RUNNER="$MOCK_RUNNER" "$@" \
        bash "$PROJECT_ROOT/tools/commands/update" --health-only --dry-run 2>&1
}

output="$(run_update)" || fail "PASS aggregation returned nonzero"
assert_contains "$output" "Maintenance workflow result: PASS" "PASS did not aggregate"
assert_contains "$output" "SKIP=4" "disabled stages were not SKIP"

output="$(run_update CC_TEST_WARN_COMMAND=doctor)" || fail "WARN aggregation returned nonzero"
assert_contains "$output" "Maintenance workflow result: WARN" "WARN did not aggregate"

marker="$TEST_DIR/continued"
if output="$(run_update CC_TEST_FAIL_COMMAND=verify CC_TEST_MARK_COMMAND=doctor CC_TEST_MARK_FILE="$marker")"; then
    fail "FAIL aggregation returned success"
fi
assert_contains "$output" "Maintenance workflow result: FAIL" "FAIL did not aggregate"
[ -f "$marker" ] || fail "diagnostics did not continue after a safe stage failure"

monthly_home="$TEST_DIR/monthly-home"
mkdir -p "$monthly_home"
HOME="$monthly_home" PROJECT_ROOT="$PROJECT_ROOT" bash -c '
set -euo pipefail
source "$PROJECT_ROOT/tools/commands/monthly-health"
print_header() { echo "User: secret-user"; echo "Toolkit: $PROJECT_ROOT"; echo "https://name:password@example.test/x"; }
print_kernel_health() { echo kernel-ok; }
print_basics() { echo basics-ok; }
print_storage() { echo "permission denied: SMART unavailable"; return 1; }
print_updates() { echo preview-ok; }
print_backups() { echo unavailable; return 20; }
print_services() { echo services-degraded; return 10; }
print_security_network() { echo network-ok; }
print_desktop_gpu() { return 20; }
print_logs() { echo logs-ok; }
if monthly_health_main --file; then exit 91; fi
report="$(find "$HOME/.captaincronos/reports/monthly-health" -type f -name "monthly-health-*.log" -print -quit)"
[ -n "$report" ]
[ "$(stat -c %a "$report")" = 600 ]
grep -Fq "Storage and SMART" "$report"
grep -Fq "FAIL" "$report"
grep -Fq "Overall report result: FAIL" "$report"
! grep -Fq "$PROJECT_ROOT" "$report"
! grep -Fq "name:password" "$report"
' || fail "monthly-health privacy, redaction, or aggregation contract failed"

docs_fixture="$TEST_DIR/generated"
bash "$PROJECT_ROOT/tools/commands/docs" build --apply --out "$docs_fixture" >/dev/null
bash "$PROJECT_ROOT/tools/commands/docs" check --out "$docs_fixture" >/dev/null \
    || fail "fresh generated documents were rejected"

LC_ALL=C bash "$PROJECT_ROOT/tools/commands/docs" inventory >"$TEST_DIR/inventory-c"
LC_ALL=en_US.utf8 bash "$PROJECT_ROOT/tools/commands/docs" inventory >"$TEST_DIR/inventory-en"
cmp -s "$TEST_DIR/inventory-c" "$TEST_DIR/inventory-en" \
    || fail "generated command order changed with the caller locale"

printf '\nstale\n' >>"$docs_fixture/COMMAND_INVENTORY.md"
if bash "$PROJECT_ROOT/tools/commands/docs" check --out "$docs_fixture" >/dev/null 2>&1; then
    fail "stale generated document was accepted"
fi

source "$PROJECT_ROOT/tools/commands/release"
release_version_consistent || fail "canonical version state was rejected"
release_temp_safety || fail "predictable temporary output regression detected"

if [ "${CC_RC_SKIP_RELEASE_FIXTURES:-0}" != 1 ]; then
    # Exercise the complete release gate in a disposable clean repository. This
    # avoids weakening the real gate merely to make dirty-development tests pass.
    release_repo="$TEST_DIR/release-repo"
    mkdir -p "$release_repo"
    cp -a "$PROJECT_ROOT/." "$release_repo/"
    rm -rf "$release_repo/.git"
    (
        cd "$release_repo"
        git init -q
        git config user.name "RC Fixture"
        git config user.email "rc-fixture@example.invalid"
        bash tools/cc docs build --apply >/dev/null
        git add .
        git commit -qm "test: clean release fixture"
        bash tools/cc release check >"$TEST_DIR/release-clean.out" 2>&1
    ) || { cat "$TEST_DIR/release-clean.out" >&2; fail "clean release-check fixture failed"; }

    printf '\nstale\n' >>"$release_repo/docs/generated/COMMAND_REFERENCE.md"
    (
        cd "$release_repo"
        git add docs/generated/COMMAND_REFERENCE.md
        git commit -qm "test: stale generated fixture"
    )
    if (cd "$release_repo" && bash tools/cc release check >"$TEST_DIR/release-stale.out" 2>&1); then
        fail "release check accepted stale generated documentation"
    fi
    grep -Fq "Generated documentation freshness" "$TEST_DIR/release-stale.out" \
        || fail "release check did not identify stale generated documentation"

    (
        cd "$release_repo"
        git checkout -q HEAD~ -- docs/generated/COMMAND_REFERENCE.md
        printf 'TOOLKIT_VERSION="9.9.9-alpha1"\nTOOLKIT_CODENAME="Mismatch"\n' >VERSION
        git add VERSION docs/generated/COMMAND_REFERENCE.md
        git commit -qm "test: inconsistent version fixture"
    )
    if (cd "$release_repo" && bash tools/cc release check >"$TEST_DIR/release-version.out" 2>&1); then
        fail "release check accepted inconsistent version state"
    fi
    grep -Fq "Version and maturity consistency" "$TEST_DIR/release-version.out" \
        || fail "release check did not identify version inconsistency"
fi

printf 'RC diagnostic-integrity tests: PASS\n'
