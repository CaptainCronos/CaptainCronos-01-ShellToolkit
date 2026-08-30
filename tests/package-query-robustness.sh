#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-kernel.sh"
source "$PROJECT_ROOT/lib/cc-deps.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_status() {
    local expected="$1" label="$2"
    shift 2
    local actual=0
    "$@" >/dev/null 2>&1 || actual=$?
    [ "$actual" -eq "$expected" ] || fail "$label (expected $expected, got $actual)"
}

TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

[ "$(cc_program_get pkg-manager)" = apt-get ] || fail 'pkg-manager provider changed unexpectedly'
[ "$(cc_program_get pkg-query)" = apt-cache ] || fail 'pkg-query provider changed unexpectedly'
[ "$(cc_program_get pkg-database)" = dpkg-query ] || fail 'pkg-database does not resolve dpkg-query'
[ "$(cc_program_get pkg-version-compare)" = dpkg ] || fail 'version comparison does not resolve dpkg'
kernel_deps="$(cc_dep_kernel_list)"
printf '%s\n' "$kernel_deps" | grep -Fxq pkg-database || fail 'kernel dependencies omit pkg-database'
printf '%s\n' "$kernel_deps" | grep -Fxq pkg-version-compare || fail 'kernel dependencies omit version comparison'

make_config() {
    local old="$1" new="$2" destination="$3"
    sed "s|$old|$new|" "$PROJECT_ROOT/config/programs.conf" > "$destination"
}

make_config 'CC_PKG_DATABASE="dpkg-query"' 'CC_PKG_DATABASE="cc-missing-dpkg-query"' \
    "$TEST_DIR/dpkg-only.conf"
(
    CC_PROGRAMS_CONFIG="$TEST_DIR/dpkg-only.conf"
    CC_PROGRAMS_LOADED=0
    [ "$(cc_program_status pkg-database)" = MISSING ] || fail 'dpkg-only host accepted missing dpkg-query'
    [ "$(cc_program_status pkg-version-compare)" = OK ] || fail 'dpkg-only host lost dpkg version comparison'
)

make_config 'CC_PKG_VERSION_COMPARE="dpkg"' 'CC_PKG_VERSION_COMPARE="cc-missing-dpkg"' \
    "$TEST_DIR/dpkg-query-only.conf"
(
    CC_PROGRAMS_CONFIG="$TEST_DIR/dpkg-query-only.conf"
    CC_PROGRAMS_LOADED=0
    [ "$(cc_program_status pkg-database)" = OK ] || fail 'dpkg-query-only host lost database queries'
    [ "$(cc_program_status pkg-version-compare)" = MISSING ] || fail 'dpkg-query-only host accepted missing dpkg'
)

make_config 'CC_PKG_QUERY="apt-cache"' 'CC_PKG_QUERY="cc-missing-apt-cache"' \
    "$TEST_DIR/apt-cache-missing.conf"
(
    CC_PROGRAMS_CONFIG="$TEST_DIR/apt-cache-missing.conf"
    CC_PROGRAMS_LOADED=0
    [ "$(cc_program_status pkg-query)" = MISSING ] || fail 'missing apt-cache provider was accepted'
)

make_config 'CC_PKG_MANAGER="apt-get"' 'CC_PKG_MANAGER="cc-missing-apt-get"' \
    "$TEST_DIR/apt-get-missing.conf"
(
    CC_PROGRAMS_CONFIG="$TEST_DIR/apt-get-missing.conf"
    CC_PROGRAMS_LOADED=0
    export CC_PROGRAMS_CONFIG CC_PROGRAMS_LOADED
    [ "$(cc_program_status pkg-manager)" = MISSING ] || fail 'missing apt-get provider was accepted'
)

CC_TEST_QUERY_SCENARIO=installed
fixture_dpkg_query() {
    case "${1:-}:$CC_TEST_QUERY_SCENARIO" in
        -s:installed) printf 'Status: install ok installed\n' ;;
        -s:absent) return 1 ;;
        -s:failure) return 42 ;;
        -s:malformed) printf 'unexpected package status\n' ;;
        -l:installed) printf 'ii  linux-image-1.0-test  1  amd64  image\n' ;;
        -l:failure) return 42 ;;
        -l:malformed) printf 'unexpected inventory output\n' ;;
        -S:installed) printf 'bash: /usr/bin/bash\n' ;;
        -S:failure) return 42 ;;
        *) return 2 ;;
    esac
}
_cc_pkg_family() { printf '%s\n' apt-get; }
# shellcheck disable=SC2329 # Invoked indirectly by package-query helpers.
_cc_pkg_database_program() { printf '%s\n' fixture_dpkg_query; }
# shellcheck disable=SC2329 # Invoked indirectly by kernel correlation checks.
_cc_pkg_version_compare_program() { printf '%s\n' dpkg; }

_cc_pkg_is_installed fixture || fail 'valid installed status was rejected'
CC_TEST_QUERY_SCENARIO=absent
assert_status 1 'package absence did not retain its status' _cc_pkg_is_installed fixture
CC_TEST_QUERY_SCENARIO=failure
assert_status 42 'package query failure was confused with absence' _cc_pkg_is_installed fixture
assert_status 42 'installed inventory query failure was swallowed' _cc_pkg_list_installed
assert_status 42 'ownership query failure was swallowed' _cc_pkg_owners_of_path /usr/bin/bash
CC_TEST_QUERY_SCENARIO=malformed
assert_status 2 'malformed installed status was accepted as absence' _cc_pkg_is_installed fixture
[ -z "$(_cc_pkg_list_installed)" ] || fail 'malformed inventory created installed packages'

CC_TEST_QUERY_SCENARIO=failure
_cc_kernel_inventory_reset
assert_status 42 'kernel inventory swallowed package database failure' _cc_kernel_inventory_capture
[ "${_CC_KERNEL_INVENTORY_STATE:-unknown}" = failed ] || fail 'kernel inventory failure state was not retained'
[ "${#_CC_KERNEL_PACKAGE_RELEASES[@]}" -eq 0 ] || fail 'failed query created kernel releases'
mkdir -p "$TEST_DIR/boot"
printf kernel > "$TEST_DIR/boot/vmlinuz-1.0-test"
CC_KERNEL_RUNNING=1.0-test
CC_KERNEL_BOOT_DIR="$TEST_DIR/boot"
export CC_KERNEL_RUNNING CC_KERNEL_BOOT_DIR
_cc_kernel_boot_filesystem_field() {
    case "$1" in SOURCE) printf '%s\n' /dev/fixture ;; USE%) printf '%s\n' 1% ;; *) return 1 ;; esac
}
_cc_kernel_efi_path() { return 1; }
findings="$(_cc_kernel_health_findings 0 '')"
printf '%s\n' "$findings" | grep -Fq $'FAIL\tPACKAGE_QUERY_FAILURE\t' ||
    fail 'Doctor-facing kernel findings did not expose package query failure'

_cc_pkg_database_program() { printf '%s\n' cc-missing-dpkg-query; }
_cc_pkg_version_compare_program() { printf '%s\n' dpkg; }
if _cc_kernel_can_correlate_packages; then fail 'dpkg-only environment enabled kernel correlation'; fi
_cc_pkg_database_program() { printf '%s\n' dpkg-query; }
_cc_pkg_version_compare_program() { printf '%s\n' cc-missing-dpkg; }
if _cc_kernel_can_correlate_packages; then fail 'dpkg-query-only environment enabled kernel correlation'; fi

_cc_pkg_query_program() { printf '%s\n' cc-missing-apt-cache; }
assert_status 127 'missing apt-cache was treated as package absence' _cc_pkg_is_available fixture
_cc_pkg_manager() { printf '%s\n' cc-missing-apt-get; }
if _cc_pkg_manager_exists; then fail 'missing apt-get provider was accepted by package operations'; fi

mkdir -p "$TEST_DIR/bin"
cat > "$TEST_DIR/bin/dpkg-query-audit-fail" <<'EOF_QUERY_FAIL'
#!/usr/bin/env bash
exit 42
EOF_QUERY_FAIL
cat > "$TEST_DIR/bin/dpkg-audit-compare" <<'EOF_COMPARE'
#!/usr/bin/env bash
exec /usr/bin/dpkg "$@"
EOF_COMPARE
chmod 755 "$TEST_DIR/bin/dpkg-query-audit-fail" "$TEST_DIR/bin/dpkg-audit-compare"
sed \
    -e 's/CC_PKG_DATABASE="dpkg-query"/CC_PKG_DATABASE="dpkg-query-audit-fail"/' \
    -e 's/CC_PKG_VERSION_COMPARE="dpkg"/CC_PKG_VERSION_COMPARE="dpkg-audit-compare"/' \
    "$PROJECT_ROOT/config/programs.conf" > "$TEST_DIR/query-failure.conf"
cleanup_status=0
cleanup_output="$(
    PATH="$TEST_DIR/bin:$PATH" CC_PROGRAMS_CONFIG="$TEST_DIR/query-failure.conf" \
        bash "$PROJECT_ROOT/tools/commands/kernel" cleanup --dry-run 2>&1
)" || cleanup_status=$?
[ "$cleanup_status" -eq 5 ] || fail 'cleanup did not refuse a failed package inventory query'
printf '%s\n' "$cleanup_output" | grep -Fq 'package database query failed' ||
    fail 'cleanup package-query failure was not explicit'
if printf '%s\n' "$cleanup_output" | grep -Fq 'Candidate purge packages:'; then
    fail 'failed package query reached cleanup package planning'
fi

printf 'Debian package-query robustness tests: PASS\n'
