#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_DIR="$(mktemp -d)"
MOCK_BIN="$TEST_DIR/bin"
TRACE_FILE="$TEST_DIR/mutations.trace"
GIT_TRACE_FILE="$TEST_DIR/git-mutations.trace"
PROGRAMS_FILE="$TEST_DIR/programs.conf"

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

assert_rejected() {
    local label="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        fail "$label"
    fi
}

assert_file_content() {
    local file="$1" expected="$2" label="$3"
    [ -f "$file" ] || fail "$label (missing file)"
    [ "$(cat "$file")" = "$expected" ] || fail "$label"
}

mkdir -p "$MOCK_BIN"

cat > "$MOCK_BIN/git" <<'EOF_GIT'
#!/usr/bin/env bash
case "${1:-}" in
    fetch|pull|checkout|reset|rebase)
        printf '%s' "$1" >> "${CC_SAFETY_GIT_TRACE:?}"
        shift
        printf '\t%s' "$@" >> "$CC_SAFETY_GIT_TRACE"
        printf '\n' >> "$CC_SAFETY_GIT_TRACE"
        [ "${CC_SAFETY_ALLOW_GIT_MUTATION:-0}" = 1 ] && exit 0
        exit 97
        ;;
    *) exec /usr/bin/git "$@" ;;
esac
EOF_GIT

cat > "$MOCK_BIN/sudo" <<'EOF_SUDO'
#!/usr/bin/env bash
printf 'sudo' >> "${CC_SAFETY_TRACE:?}"
printf '\t%s' "$@" >> "$CC_SAFETY_TRACE"
printf '\n' >> "$CC_SAFETY_TRACE"
exit "${CC_MOCK_SUDO_STATUS:-0}"
EOF_SUDO

cat > "$MOCK_BIN/snap" <<'EOF_SNAP'
#!/usr/bin/env bash
printf 'snap' >> "${CC_SAFETY_TRACE:?}"
printf '\t%s' "$@" >> "$CC_SAFETY_TRACE"
printf '\n' >> "$CC_SAFETY_TRACE"
exit "${CC_MOCK_SNAP_STATUS:-0}"
EOF_SNAP

cat > "$MOCK_BIN/flatpak" <<'EOF_FLATPAK'
#!/usr/bin/env bash
printf 'flatpak' >> "${CC_SAFETY_TRACE:?}"
printf '\t%s' "$@" >> "$CC_SAFETY_TRACE"
printf '\n' >> "$CC_SAFETY_TRACE"
exit "${CC_MOCK_FLATPAK_STATUS:-0}"
EOF_FLATPAK

cat > "$MOCK_BIN/apt-get-safety-mock" <<'EOF_APT'
#!/usr/bin/env bash
exit 0
EOF_APT

chmod 755 "$MOCK_BIN"/*
sed 's/CC_PKG_MANAGER="apt-get"/CC_PKG_MANAGER="apt-get-safety-mock"/' \
    "$PROJECT_ROOT/config/programs.conf" > "$PROGRAMS_FILE"

common_env=(
    "PATH=$MOCK_BIN:$PATH"
    "CAPTAIN_CRONOS_TOOLKIT_ROOT=$PROJECT_ROOT"
    "CC_PROGRAMS_CONFIG=$PROGRAMS_FILE"
    "CC_SAFETY_TRACE=$TRACE_FILE"
    "CC_SAFETY_GIT_TRACE=$GIT_TRACE_FILE"
)

# system-update defaults to dry-run and must not create its log or invoke a
# mutation-capable program.
system_home="$TEST_DIR/system-home"
mkdir -p "$system_home"
system_log="$system_home/upgrade.log"
system_output="$(env "${common_env[@]}" HOME="$system_home" LOG="$system_log" \
    bash "$PROJECT_ROOT/tools/commands/system-update")" || fail "system-update default preview failed"
[ ! -e "$system_log" ] || fail "system-update default preview created its log"
[ ! -e "$TRACE_FILE" ] || fail "system-update default preview invoked a mutation command"
assert_contains "$system_output" "DRY RUN: sudo apt-get-safety-mock update" "system-update did not preview package update"
assert_contains "$system_output" "Firefox archive replacement: deferred" "browser archive deferral was not reported"
assert_contains "$system_output" "routine system update does not modify boot configuration" "GRUB deferral was not reported"

system_output="$(env "${common_env[@]}" HOME="$system_home" LOG="$system_log" \
    bash "$PROJECT_ROOT/tools/commands/system-update" --dry-run)" || fail "system-update --dry-run failed"
[ ! -e "$system_log" ] || fail "system-update --dry-run created its log"
[ ! -e "$TRACE_FILE" ] || fail "system-update --dry-run invoked a mutation command"

assert_rejected "system-update accepted an unknown option" \
    env "${common_env[@]}" HOME="$system_home" bash "$PROJECT_ROOT/tools/commands/system-update" --bogus
assert_rejected "system-update accepted conflicting modes" \
    env "${common_env[@]}" HOME="$system_home" bash "$PROJECT_ROOT/tools/commands/system-update" --dry-run --apply

# Apply is exercised only through mocks. Package, Snap, and Flatpak adapters are
# reached, while browser and bootloader mutation remain unreachable.
env "${common_env[@]}" HOME="$system_home" LOG="$system_log" \
    bash "$PROJECT_ROOT/tools/commands/system-update" --apply >/dev/null || fail "mocked system-update apply failed"
[ -f "$system_log" ] || fail "system-update apply did not create its apply log"
grep -Fq $'sudo\tapt-get-safety-mock\tupdate' "$TRACE_FILE" || fail "apply did not reach package update"
grep -Fq $'sudo\tsnap\trefresh' "$TRACE_FILE" || fail "apply did not reach Snap refresh"
grep -Fq $'flatpak\tupdate\t-y' "$TRACE_FILE" || fail "apply did not reach Flatpak update"
if grep -Eq 'update-grub|grub.d|firefox|thunderbird|/opt/' "$TRACE_FILE"; then
    fail "routine apply reached a deferred bootloader/browser mutation"
fi

: > "$TRACE_FILE"
if env "${common_env[@]}" HOME="$system_home" LOG="$system_log" CC_MOCK_FLATPAK_STATUS=9 \
    bash "$PROJECT_ROOT/tools/commands/system-update" --apply >/dev/null 2>&1; then
    fail "system-update converted a mocked apply failure into success"
fi

# The full installer must leave an existing fixture home byte-for-byte unchanged
# in both default and explicit dry-run modes.
install_home="$TEST_DIR/install-home"
mkdir -p "$install_home/bin"
printf 'old bashrc\n' > "$install_home/.bashrc"
printf 'old aliases\n' > "$install_home/.bash_aliases"
printf 'old functions\n' > "$install_home/.bash_functions"
printf 'old launcher\n' > "$install_home/bin/cc"
chmod 755 "$install_home/bin/cc"

for mode in default explicit; do
    installer_args=()
    [ "$mode" = default ] || installer_args=(--dry-run)
    env HOME="$install_home" PATH="$MOCK_BIN:$PATH" \
        CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" \
        bash "$PROJECT_ROOT/install/install.sh" "${installer_args[@]}" --no-deps --no-baseline >/dev/null \
        || fail "full installer $mode dry-run failed"
    assert_file_content "$install_home/.bashrc" "old bashrc" "installer $mode dry-run replaced bashrc"
    assert_file_content "$install_home/.bash_aliases" "old aliases" "installer $mode dry-run replaced aliases"
    assert_file_content "$install_home/.bash_functions" "old functions" "installer $mode dry-run replaced functions"
    assert_file_content "$install_home/bin/cc" "old launcher" "installer $mode dry-run replaced launcher"
    [ ! -e "$install_home/.captaincronos/backups" ] || fail "installer $mode dry-run created backups"
done

env HOME="$install_home" PATH="$MOCK_BIN:$PATH" \
    CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" \
    bash "$PROJECT_ROOT/install/install.sh" --apply --no-deps --no-baseline >/dev/null \
    || fail "fixture installer apply failed"
cmp -s "$PROJECT_ROOT/bash/bashrc" "$install_home/.bashrc" || fail "installer apply did not install bashrc"
cmp -s "$PROJECT_ROOT/tools/cc" "$install_home/bin/cc" || fail "installer apply did not install launcher"
find "$install_home/.captaincronos/backups" -type f -name .bashrc -print -quit | grep -q . \
    || fail "installer apply did not back up bashrc"

# Launcher installation follows the same default-preview/explicit-apply contract.
launcher_home="$TEST_DIR/launcher-home"
mkdir -p "$launcher_home"
env HOME="$launcher_home" PATH="$MOCK_BIN:$PATH" TOOLKIT_ROOT="$PROJECT_ROOT" CURRENT_REPO="$PROJECT_ROOT" \
    bash "$PROJECT_ROOT/tools/commands/install" >/dev/null || fail "cc install default preview failed"
[ ! -e "$launcher_home/bin/cc" ] || fail "cc install default preview installed the launcher"
env HOME="$launcher_home" PATH="$MOCK_BIN:$PATH" TOOLKIT_ROOT="$PROJECT_ROOT" CURRENT_REPO="$PROJECT_ROOT" \
    bash "$PROJECT_ROOT/tools/commands/install" --apply >/dev/null || fail "cc install apply failed"
cmp -s "$PROJECT_ROOT/tools/cc" "$launcher_home/bin/cc" || fail "cc install apply did not install launcher"
assert_rejected "cc install accepted an unknown option" \
    env HOME="$launcher_home" TOOLKIT_ROOT="$PROJECT_ROOT" bash "$PROJECT_ROOT/tools/commands/install" --bogus

# Toolkit dry-run may inspect local refs but may not fetch/pull or install. Apply
# reaches the mocked pull and installs only into the disposable fixture home.
toolkit_home="$TEST_DIR/toolkit-home"
mkdir -p "$toolkit_home/bin"
printf 'toolkit old bashrc\n' > "$toolkit_home/.bashrc"
printf 'toolkit old aliases\n' > "$toolkit_home/.bash_aliases"
printf 'toolkit old functions\n' > "$toolkit_home/.bash_functions"
printf 'toolkit old launcher\n' > "$toolkit_home/bin/cc"
chmod 755 "$toolkit_home/bin/cc"
rm -f "$GIT_TRACE_FILE"
toolkit_output="$(env "${common_env[@]}" HOME="$toolkit_home" \
    bash "$PROJECT_ROOT/tools/commands/toolkit-update")" || fail "toolkit-update default preview failed"
[ ! -e "$GIT_TRACE_FILE" ] || fail "toolkit-update preview invoked fetch/pull/ref mutation"
[ ! -e "$toolkit_home/.captaincronos/backups" ] || fail "toolkit-update preview created installer backups"
assert_file_content "$toolkit_home/.bashrc" "toolkit old bashrc" "toolkit-update preview replaced bashrc"
assert_contains "$toolkit_output" "would fetch and pull origin/main during --apply" "toolkit preview omitted remote deferral"
assert_rejected "toolkit-update accepted an unknown option" \
    env "${common_env[@]}" HOME="$toolkit_home" bash "$PROJECT_ROOT/tools/commands/toolkit-update" --bogus

env "${common_env[@]}" HOME="$toolkit_home" CC_SAFETY_ALLOW_GIT_MUTATION=1 \
    bash "$PROJECT_ROOT/tools/commands/toolkit-update" --apply >/dev/null || fail "mocked toolkit-update apply failed"
grep -Fq $'pull\t--rebase\torigin\tmain' "$GIT_TRACE_FILE" || fail "toolkit apply did not reach mocked git pull"
cmp -s "$PROJECT_ROOT/bash/bashrc" "$toolkit_home/.bashrc" || fail "toolkit apply did not reach installer apply"

# The complete update preview is allowed to inspect the host, but every
# mutation-capable adapter is mocked to fail if reached. Fixture installation,
# backup, update-log, Git-ref, GRUB, and browser state must remain absent.
update_home="$TEST_DIR/update-home"
mkdir -p "$update_home/bin"
printf 'update old bashrc\n' > "$update_home/.bashrc"
printf 'update old aliases\n' > "$update_home/.bash_aliases"
printf 'update old functions\n' > "$update_home/.bash_functions"
printf 'update old launcher\n' > "$update_home/bin/cc"
chmod 755 "$update_home/bin/cc"
rm -f "$TRACE_FILE" "$GIT_TRACE_FILE" "$update_home/upgrade.log"
env "${common_env[@]}" HOME="$update_home" LOG="$update_home/upgrade.log" \
    bash "$PROJECT_ROOT/tools/cc" update --dry-run >/dev/null || fail "cc update --dry-run failed"
if [ -e "$TRACE_FILE" ] && grep -Fv smartctl "$TRACE_FILE" | grep -q .; then
    fail "cc update --dry-run invoked a mutation command"
fi
[ ! -e "$GIT_TRACE_FILE" ] || fail "cc update --dry-run invoked Git mutation"
[ ! -e "$update_home/upgrade.log" ] || fail "cc update --dry-run created an update log"
[ ! -e "$update_home/.captaincronos/backups" ] || fail "cc update --dry-run created backups"
assert_file_content "$update_home/.bashrc" "update old bashrc" "cc update --dry-run replaced bashrc"

assert_rejected "cc update accepted an unknown option" \
    env "${common_env[@]}" HOME="$update_home" bash "$PROJECT_ROOT/tools/commands/update" --bogus
assert_rejected "cc update accepted conflicting modes" \
    env "${common_env[@]}" HOME="$update_home" bash "$PROJECT_ROOT/tools/commands/update" --dry-run --apply

# monthly-health reuses the explicit system preview without creating a report or
# update log when its update-readiness section is rendered.
monthly_home="$TEST_DIR/monthly-home"
mkdir -p "$monthly_home"
rm -f "$TRACE_FILE" "$monthly_home/upgrade.log"
# Expanded by the child Bash process using its positional parameter.
# shellcheck disable=SC2016
monthly_rc=0
env "${common_env[@]}" HOME="$monthly_home" LOG="$monthly_home/upgrade.log" \
    bash -c 'source "$1/tools/commands/monthly-health"; print_updates' bash "$PROJECT_ROOT" >/dev/null \
    || monthly_rc=$?
case "$monthly_rc" in
    0|10) ;;
    *) fail "monthly-health update preview failed" ;;
esac
[ ! -e "$TRACE_FILE" ] || fail "monthly-health update preview invoked mutation"
[ ! -e "$monthly_home/upgrade.log" ] || fail "monthly-health update preview created an update log"

# Static reachability guards complement the runtime mocks: routine system update
# contains no bootloader writer or remote browser archive installer.
if grep -Eq 'update-grub|/etc/grub\.d/40_custom|download\.mozilla\.org|sudo rm -rf "/opt/' \
    "$PROJECT_ROOT/tools/commands/system-update"; then
    fail "deferred bootloader/browser mutation remains reachable in system-update"
fi

printf 'Safety contract tests: PASS\n'
