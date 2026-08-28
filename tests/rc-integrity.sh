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
report="$(find "$HOME/.captaincronos/hosts" -type f -name "monthly-health-*.log" -print -quit)"
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

# Generated help is a repository artifact, not a reflection of caller-specific
# program mappings. A broken inherited mapping must neither contaminate the
# reference nor be converted into a false stale-document result.
polluted_docs="$TEST_DIR/generated-polluted-environment"
CC_PROGRAMS_CONFIG="$TEST_DIR/does-not-exist" \
    bash "$PROJECT_ROOT/tools/commands/docs" reference --apply --out "$polluted_docs" >/dev/null \
    || fail "reference generation depended on caller program configuration"
cmp -s "$docs_fixture/COMMAND_REFERENCE.md" "$polluted_docs/COMMAND_REFERENCE.md" \
    || fail "caller program configuration changed generated command help"
normal_switches="$TEST_DIR/drive-inventory-switches-normal"
polluted_switches="$TEST_DIR/drive-inventory-switches-polluted"
bash "$PROJECT_ROOT/tools/cc" drive-inventory switches >"$normal_switches" \
    || fail "baseline switch discovery failed"
CC_PROGRAMS_CONFIG="$TEST_DIR/does-not-exist" \
    bash "$PROJECT_ROOT/tools/cc" drive-inventory switches >"$polluted_switches" \
    || fail "switch discovery depended on caller program configuration"
cmp -s "$normal_switches" "$polluted_switches" \
    || fail "caller program configuration changed drive-inventory switches"
cat >"$TEST_DIR/bash-env" <<EOF_HOOK
export CC_PROGRAMS_CONFIG=$(printf '%q' "$TEST_DIR/does-not-exist")
bash() { printf 'caller bash hook\n' >&2; return 77; }
export -f bash
EOF_HOOK
BASH_ENV="$TEST_DIR/bash-env" \
    bash "$PROJECT_ROOT/tools/commands/docs" check --out "$docs_fixture" >/dev/null \
    || fail "caller shell hook changed generated documentation freshness"
polluted_hook_docs="$TEST_DIR/generated-polluted-hook"
BASH_ENV="$TEST_DIR/bash-env" \
    bash "$PROJECT_ROOT/tools/commands/docs" build --apply --out "$polluted_hook_docs" >/dev/null \
    || fail "caller shell hook changed generated documentation"
diff -qr "$docs_fixture" "$polluted_hook_docs" >/dev/null \
    || fail "clean and polluted generated documentation differed"
prompt_normal="$TEST_DIR/prompt-switches-normal"
prompt_polluted="$TEST_DIR/prompt-switches-polluted"
bash "$PROJECT_ROOT/tools/cc" prompt switches >"$prompt_normal" \
    || fail "baseline prompt switch discovery failed"
BASH_ENV="$TEST_DIR/bash-env" \
    bash "$PROJECT_ROOT/tools/cc" prompt switches >"$prompt_polluted" \
    || fail "caller shell hook changed prompt switch discovery"
cmp -s "$prompt_normal" "$prompt_polluted" \
    || fail "caller shell hook changed prompt switch output"

# Discovery failures retain the real child status and bounded phase context,
# while write_output prevents publication of a partial reference artifact.
failure_bin="$TEST_DIR/failure-bin"
failure_docs="$TEST_DIR/generated-failure"
mkdir -p "$failure_bin"
real_bash="$(type -P bash)"
cat >"$failure_bin/bash" <<EOF_FAILURE_BASH
#!$real_bash
if [ "\${1:-}" = "$PROJECT_ROOT/tools/cc" ] &&
   [ "\${2:-}" = about ] && [ "\${3:-}" = switches ]; then
    printf 'partial output\n'
    printf 'injected discovery failure\n' >&2
    exit 23
fi
exec $(printf '%q' "$real_bash") "\$@"
EOF_FAILURE_BASH
chmod 700 "$failure_bin/bash"
if PATH="$failure_bin:$PATH" \
    "$real_bash" "$PROJECT_ROOT/tools/commands/docs" reference --apply --out "$failure_docs" \
    >"$TEST_DIR/discovery-failure.out" 2>"$TEST_DIR/discovery-failure.err"; then
    fail "injected discovery failure returned success"
else
    discovery_status=$?
fi
[ "$discovery_status" -eq 23 ] \
    || fail "discovery failure changed child status 23 to $discovery_status"
grep -Fq 'Discovery failure: phase=switch-discovery, exit=23, stdout_bytes=15.' \
    "$TEST_DIR/discovery-failure.err" || fail "discovery failure omitted status or stdout size"
grep -Fq 'injected discovery failure' "$TEST_DIR/discovery-failure.err" \
    || fail "discovery failure omitted captured stderr"
[ ! -e "$failure_docs/COMMAND_REFERENCE.md" ] \
    || fail "discovery failure published a partial command reference"

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

# Release searches must work with the declared core grep interface and must not
# turn a missing optional ripgrep executable into a false PASS.
release_search_repo="$TEST_DIR/release-search-repo"
release_search_bin="$TEST_DIR/release-search-bin"
mkdir -p "$release_search_repo/docs" "$release_search_repo/tools/commands" \
    "$release_search_repo/install" "$release_search_repo/lib" "$release_search_repo/tests" \
    "$release_search_bin"
ln -s "$(command -v grep)" "$release_search_bin/grep"
cp "$PROJECT_ROOT/VERSION" "$PROJECT_ROOT/README.md" "$PROJECT_ROOT/ROADMAP.md" \
    "$PROJECT_ROOT/CHANGELOG.md" "$PROJECT_ROOT/manifest.yml" "$release_search_repo/"
cp "$PROJECT_ROOT/docs/ARCHITECTURE.md" "$PROJECT_ROOT/docs/RELEASE_1.3_CHECKLIST.md" \
    "$release_search_repo/docs/"
cp "$PROJECT_ROOT/tools/commands/roadmap" "$release_search_repo/tools/commands/"
if ! PROJECT_ROOT="$release_search_repo" PATH="$release_search_bin" release_version_consistent ||
    ! PROJECT_ROOT="$release_search_repo" PATH="$release_search_bin" release_docs_consistent ||
    ! PROJECT_ROOT="$release_search_repo" PATH="$release_search_bin" release_temp_safety; then
    fail "release searches require an undeclared ripgrep executable"
fi
printf 'status: beta\n' >>"$release_search_repo/manifest.yml"
if PROJECT_ROOT="$release_search_repo" PATH="$release_search_bin" release_version_consistent; then
    fail "release version search accepted forbidden maturity metadata without ripgrep"
fi
printf 'docs/ROADMAP.md\n' >>"$release_search_repo/tools/commands/roadmap"
if PROJECT_ROOT="$release_search_repo" PATH="$release_search_bin" release_docs_consistent; then
    fail "release documentation search accepted a forbidden stale path without ripgrep"
fi
printf '%s\n' '/tmp/'"cc-predictable" >"$release_search_repo/tools/predictable-temp"
if PROJECT_ROOT="$release_search_repo" PATH="$release_search_bin" release_temp_safety >/dev/null 2>&1; then
    fail "release temporary-path search accepted a predictable path without ripgrep"
fi

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
