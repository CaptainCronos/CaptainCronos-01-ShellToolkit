#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_DIR="$(mktemp -d)"
MOCK_BIN="$TEST_DIR/bin"
TRACE_FILE="$TEST_DIR/dev-updates.trace"
HOME_DIR="$TEST_DIR/home"

cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    local text="$1" expected="$2" label="$3"
    printf '%s\n' "$text" | grep -Fq -- "$expected" || fail "$label"
}

assert_not_traced() {
    local pattern="$1" label="$2"
    if [ -f "$TRACE_FILE" ] && grep -Eq -- "$pattern" "$TRACE_FILE"; then
        fail "$label"
    fi
}

mkdir -p "$MOCK_BIN" "$HOME_DIR/.captaincronos"

for manager in npm pipx pip cargo go gem; do
    sed "s/@MANAGER@/$manager/g" >"$MOCK_BIN/$manager" <<'EOF_MANAGER'
#!/usr/bin/env bash
printf '@MANAGER@' >> "${CC_DEV_UPDATE_TRACE:?}"
printf '\t%s' "$@" >> "$CC_DEV_UPDATE_TRACE"
printf '\n' >> "$CC_DEV_UPDATE_TRACE"
case "@MANAGER@" in
    npm) exit "${CC_MOCK_NPM_STATUS:-0}" ;;
    pipx) exit "${CC_MOCK_PIPX_STATUS:-0}" ;;
esac
exit 0
EOF_MANAGER
done

cat >"$MOCK_BIN/sudo" <<'EOF_SUDO'
#!/usr/bin/env bash
printf 'sudo' >> "${CC_DEV_UPDATE_TRACE:?}"
printf '\t%s' "$@" >> "$CC_DEV_UPDATE_TRACE"
printf '\n' >> "$CC_DEV_UPDATE_TRACE"
exit 98
EOF_SUDO

cat >"$MOCK_BIN/update-runner" <<'EOF_RUNNER'
#!/usr/bin/env bash
shift
printf 'cc' >> "${CC_DEV_UPDATE_TRACE:?}"
printf '\t%s' "$@" >> "$CC_DEV_UPDATE_TRACE"
printf '\n' >> "$CC_DEV_UPDATE_TRACE"
exit 0
EOF_RUNNER

chmod 755 "$MOCK_BIN"/*

fixture_path="$MOCK_BIN:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
common_env=(
    "PATH=$fixture_path"
    "HOME=$HOME_DIR"
    "CAPTAIN_CRONOS_TOOLKIT_ROOT=$PROJECT_ROOT"
    "CC_DEV_UPDATE_TRACE=$TRACE_FILE"
)

# Default, explicit dry-run, and status-only modes report detection and commands
# without executing any developer manager.
for mode in default dry-run status-only; do
    args=()
    case "$mode" in
        dry-run) args=(--dry-run) ;;
        status-only) args=(--status-only) ;;
    esac
    : >"$TRACE_FILE"
    output="$(env "${common_env[@]}" bash "$PROJECT_ROOT/tools/commands/dev-update" "${args[@]}")" \
        || fail "dev-update $mode reporting failed"
    [ ! -s "$TRACE_FILE" ] || fail "dev-update $mode executed a developer manager"
    assert_contains "$output" "npm      installed" "$mode did not detect npm"
    assert_contains "$output" "pipx     installed" "$mode did not detect pipx"
    assert_contains "$output" "npm outdated -g --depth=0" "$mode omitted npm report command"
    assert_contains "$output" "pipx list" "$mode omitted pipx report command"
    assert_contains "$output" "python3 -m pip list --outdated" "$mode omitted pip report command"
    assert_contains "$output" "cargo install --list" "$mode omitted cargo review command"
    assert_contains "$output" "go env GOPATH GOBIN" "$mode omitted Go review command"
    assert_contains "$output" "gem outdated" "$mode omitted gem review command"
done

for conflict in '--dry-run --apply' '--apply --status-only' '--status-only --dry-run'; do
    read -r -a conflict_args <<< "$conflict"
    set +e
    env "${common_env[@]}" bash "$PROJECT_ROOT/tools/commands/dev-update" \
        "${conflict_args[@]}" >"$TEST_DIR/conflict.out" 2>"$TEST_DIR/conflict.err"
    conflict_status=$?
    set -e
    [ "$conflict_status" -eq 2 ] || fail "dev-update conflict returned $conflict_status: $conflict"
    [ ! -s "$TRACE_FILE" ] || fail "dev-update conflict executed a developer manager: $conflict"
done

# Explicit apply reaches only the two supported user-scoped managers. pip,
# cargo, Go, and gem remain manual-review, and this layer never injects sudo.
: >"$TRACE_FILE"
apply_output="$(env "${common_env[@]}" bash "$PROJECT_ROOT/tools/commands/dev-update" --apply)" \
    || fail "dev-update explicit apply failed"
grep -Fxq $'npm\tupdate\t-g' "$TRACE_FILE" || fail "npm apply did not run the global update"
grep -Fxq $'pipx\tupgrade-all' "$TRACE_FILE" || fail "pipx apply did not run upgrade-all"
assert_not_traced '^(pip|cargo|go|gem|sudo)(\t|$)' "apply mutated a report-only manager or invoked sudo"
assert_contains "$apply_output" "pip: update apply is disabled" "pip was not kept report-only"
assert_contains "$apply_output" "cargo: update apply is disabled" "cargo was not kept report-only"
assert_contains "$apply_output" "go: update apply is disabled" "Go was not kept report-only"
assert_contains "$apply_output" "gem: update apply is disabled" "gem was not kept report-only"

# A supported-manager failure remains a failure, but later safe manager work
# continues and report-only managers remain non-mutating.
: >"$TRACE_FILE"
failure_output="$TEST_DIR/failure.out"
failure_error="$TEST_DIR/failure.err"
if env "${common_env[@]}" CC_MOCK_NPM_STATUS=17 \
    bash "$PROJECT_ROOT/tools/commands/dev-update" --apply >"$failure_output" 2>"$failure_error"; then
    fail "dev-update converted an npm apply failure into success"
fi
grep -Fq 'npm: update failed.' "$failure_error" || fail "npm failure was not reported truthfully"
grep -Fxq $'pipx\tupgrade-all' "$TRACE_FILE" || fail "npm failure skipped the later pipx update"
assert_not_traced '^(pip|cargo|go|gem|sudo)(\t|$)' "failure path mutated a report-only manager or invoked sudo"

# Full update --apply does not opt into developer mutation. The configuration
# flag enables the stage explicitly, and the runner makes every stage hermetic.
: >"$TRACE_FILE"
env "${common_env[@]}" CC_UPDATE_RUNNER="$MOCK_BIN/update-runner" \
    bash "$PROJECT_ROOT/tools/commands/update" --apply >/dev/null \
    || fail "mocked full update without DEV_UPDATES failed"
assert_not_traced $'^cc\tdev-update\t' "full update enabled developer updates without DEV_UPDATES=yes"

printf 'DEV_UPDATES="yes"\n' >"$HOME_DIR/.captaincronos/config"
: >"$TRACE_FILE"
env "${common_env[@]}" CC_UPDATE_RUNNER="$MOCK_BIN/update-runner" \
    bash "$PROJECT_ROOT/tools/commands/update" --apply >/dev/null \
    || fail "mocked full update with DEV_UPDATES=yes failed"
grep -Fxq $'cc\tdev-update\tall\t--apply' "$TRACE_FILE" \
    || fail "DEV_UPDATES=yes did not enable explicit developer apply"

printf 'Developer update tests: PASS\n'
