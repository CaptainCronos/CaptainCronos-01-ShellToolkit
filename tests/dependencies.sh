#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-deps.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

TEST_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

cc_dep_is_program_capability pkg-manager || fail "pkg-manager was not classified as a program capability"
[ "$(cc_dep_resolve_program pkg-manager)" = "apt-get" ] || fail "pkg-manager did not resolve to apt-get"
[ "$(cc_dep_execution_status pkg-manager)" = "OK" ] || fail "available pkg-manager capability did not report OK"
if cc_dep_install_hint pkg-manager >/dev/null 2>&1; then
    fail "pkg-manager produced a literal package-install hint"
fi

cc_dep_is_program_capability yaml || fail "yaml was not classified as a program capability"
if cc_dep_install_hint yaml >/dev/null 2>&1; then
    fail "yaml capability produced a literal package-install hint"
fi
[ "$(cc_dep_install_hint smartctl)" = "smartmontools" ] || fail "literal executable package hints stopped working"

semantic_dependencies=""
for command_file in "$PROJECT_ROOT"/tools/commands/*; do
    [ -f "$command_file" ] || continue
    requires="$(awk '
        /^# Requires[[:space:]]*:/ {
            sub(/^# Requires[[:space:]]*:[[:space:]]*/, "")
            print
            exit
        }
    ' "$command_file")"
    for dependency in $requires; do
        if cc_dep_is_program_capability "$dependency"; then
            semantic_dependencies="${semantic_dependencies}${dependency}\n"
            cc_dep_resolve_program "$dependency" >/dev/null || fail "could not resolve semantic dependency: $dependency"
            if cc_dep_install_hint "$dependency" >/dev/null 2>&1; then
                fail "semantic dependency produced an install hint: $dependency"
            fi
        fi
    done
done
printf '%b' "$semantic_dependencies" | grep -qx pkg-manager || fail "pkg-manager command declaration was not audited"
printf '%b' "$semantic_dependencies" | grep -qx yaml || fail "yaml command declarations were not audited"

deps_output="$(bash "$PROJECT_ROOT/tools/cc" deps command system-update)" || fail "command dependency reporting failed"
printf '%s\n' "$deps_output" | grep -Eq '^pkg-manager[[:space:]]+PASS$' || fail "cc deps treated pkg-manager as a literal executable"
deps_output="$(bash "$PROJECT_ROOT/tools/cc" deps command drive-report)" || fail "YAML dependency reporting failed"
printf '%s\n' "$deps_output" | grep -Eq '^yaml[[:space:]]+PASS$' || fail "cc deps treated yaml as a literal executable"

sed 's/CC_PKG_MANAGER="apt-get"/CC_PKG_MANAGER="apt-get-regression-mock"/' \
    "$PROJECT_ROOT/config/programs.conf" > "$TEST_DIR/programs-compatible.conf"
cat > "$TEST_DIR/apt-get-regression-mock" <<'EOF_MOCK'
#!/usr/bin/env bash
exit 0
EOF_MOCK
chmod 755 "$TEST_DIR/apt-get-regression-mock"

update_output="$(
    PATH="$TEST_DIR:$PATH" \
    CC_PROGRAMS_CONFIG="$TEST_DIR/programs-compatible.conf" \
    LOG="$TEST_DIR/system-update.log" \
    XDG_STATE_HOME="$TEST_DIR/state" \
        bash "$PROJECT_ROOT/tools/cc" system-update --dry-run
)" || fail "system-update rejected a resolved package-manager capability"
printf '%s\n' "$update_output" | grep -q '^DRY RUN: sudo apt-get-regression-mock update$' || fail "system-update did not use the resolved package-manager program"
printf '%s\n' "$update_output" | grep -q '^DRY RUN: sudo apt-get-regression-mock upgrade -y$' || fail "system-update upgrade did not use the resolved package-manager program"

sed 's/CC_PKG_MANAGER="apt-get"/CC_PKG_MANAGER="pkg-manager-missing"/' \
    "$PROJECT_ROOT/config/programs.conf" > "$TEST_DIR/programs-missing.conf"
missing_status=0
missing_output="$(
    CC_PROGRAMS_CONFIG="$TEST_DIR/programs-missing.conf" \
        bash "$PROJECT_ROOT/tools/cc" system-update --dry-run 2>&1
)" || missing_status=$?
[ "$missing_status" -eq 127 ] || fail "missing package-manager capability returned an unexpected status"
printf '%s\n' "$missing_output" | grep -Eq '^pkg-manager[[:space:]]+MISSING$' || fail "missing package-manager capability was not reported semantically"
if printf '%s\n' "$missing_output" | grep -Eq 'apt(-get)? install pkg-manager|install package:[[:space:]]*pkg-manager'; then
    fail "missing semantic capability generated a literal package-install hint"
fi

cat > "$TEST_DIR/dnf" <<'EOF_DNF'
#!/usr/bin/env bash
exit 0
EOF_DNF
chmod 755 "$TEST_DIR/dnf"
source "$PROJECT_ROOT/lib/cc-packages.sh"
(
    PATH="$TEST_DIR:$PATH"
    export PATH
    cc_platform_package_manager() { printf '%s\n' dnf; }
    [ "$(cc_dep_resolve_program pkg-manager)" = "dnf" ] || fail "non-Debian package-manager resolution changed"
    [ "$(cc_dep_execution_status pkg-manager)" = "OK" ] || fail "non-Debian package-manager status changed"
)

printf 'Semantic dependency tests: PASS\n'
