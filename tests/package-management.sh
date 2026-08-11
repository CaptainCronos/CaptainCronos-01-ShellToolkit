#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-packages.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[ "$(_cc_pkg_manager)" = "$(cc_program_get pkg-manager)" ] || fail "package manager capability did not resolve"
[ "$(_cc_pkg_query_program)" = "$(cc_program_get pkg-query)" ] || fail "package query capability did not resolve"
[ "$(_cc_pkg_database_program)" = "$(cc_program_get pkg-database)" ] || fail "package database capability did not resolve"
_cc_pkg_database_available || fail "package database availability was not detected"

_cc_pkg_is_installed bash || fail "installed-package detection did not find bash"
if _cc_pkg_is_installed cc-package-that-does-not-exist; then
    fail "installed-package detection accepted a missing package"
fi
_cc_pkg_is_available bash || fail "package availability query did not find bash"
printf '%s\n' "$(_cc_pkg_owners_of_path /usr/bin/bash)" | grep -Fxq bash || fail "package path ownership did not find bash"

dry_run_output="$(CC_PKG_DRY_RUN=1 _cc_pkg_install cc-package-test)"
printf '%s\n' "$dry_run_output" | grep -q 'sudo apt-get install -y cc-package-test' || fail "Debian dry-run command was not standardized"

cc_platform_package_manager() { printf '%s\n' dnf; }
dry_run_output="$(CC_PKG_DRY_RUN=1 _cc_pkg_install cc-package-test)"
printf '%s\n' "$dry_run_output" | grep -q 'sudo dnf install -y cc-package-test' || fail "non-Debian package abstraction did not remain intact"

printf 'Package management tests: PASS\n'
