#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-requirements.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# Fully mocked capability and package adapters: no real package query or runner.
CC_TEST_SMART=missing
cc_platform_package_manager() { printf '%s\n' apt-get; }
_cc_pkg_is_available() { [ "$1" = smartmontools ]; }
cc_capability_result() {
    case "$1" in
        smart) if [ "$CC_TEST_SMART" = available ]; then printf 'available\tPASS\tfixture\tdetected\n'; else printf 'missing\tFAIL\tfixture\tabsent\n'; fi ;;
        zfs) printf 'unknown\tFAIL\tfixture\tprobe unavailable\n' ;;
        systemd) printf 'incompatible\tFAIL\tfixture\twrong implementation\n' ;;
        git) printf 'available\tPASS\tfixture\tdetected\n' ;;
        *) printf 'unknown\tFAIL\tnone\tunknown capability\n' ;;
    esac
}

plan="$(cc_requirements_resolve nas)"
printf '%s\n' "$plan" | grep -q $'nas\tsmart\trequired\tmissing/installable\tsmartmontools' || fail 'missing smart was not installable'
printf '%s\n' "$plan" | grep -q $'nas\tzfs\toptional\toptional/unknown/unresolved' || fail 'optional unresolved zfs was not classified'
IFS=$'\t' read -r outcome _ < <(_cc_requirement_state systemd)
[ "$outcome" = incompatible ] || fail 'incompatible capability was not preserved'

# Unknown Linux/non-Linux-style no-manager cases are unsupported, never plans.
cc_platform_package_manager() { printf '%s\n' none; }
no_manager_plan="$(cc_requirements_resolve nas)"
IFS=$'\t' read -r _ _ _ outcome _ <<< "${no_manager_plan%%$'\n'*}"
[ "$outcome" = unsupported ] || fail 'no package manager was not unsupported'
cc_platform_package_manager() { printf '%s\n' apt-get; }
[ -z "$(cc_requirements_resolve custom)" ] || fail 'custom role manufactured requirements'

calls=0
_cc_pkg_install() { calls=$((calls + 1)); [ "$1" = smartmontools ] || return 1; CC_TEST_SMART=available; }
cc_requirements_apply nas || fail 'mocked apply did not revalidate successfully'
[ "$calls" -eq 1 ] || fail 'apply did not use exactly one semantic package operation'

CC_TEST_SMART=missing
_cc_pkg_is_available() { return 1; }
calls=0
cc_requirements_apply nas && fail 'unresolved required requirement returned success'
[ "$calls" -eq 0 ] || fail 'unknown package availability mutated'
printf 'Requirements foundation tests: PASS\n'
