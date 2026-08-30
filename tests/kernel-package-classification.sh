#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-kernel.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    local text="$1" expected="$2" label="$3"
    printf '%s\n' "$text" | grep -Fxq -- "$expected" || fail "$label"
}

assert_not_contains() {
    local text="$1" unexpected="$2" label="$3"
    if printf '%s\n' "$text" | grep -Fxq -- "$unexpected"; then fail "$label"; fi
}

declare -A TEST_DEPENDENCY_RELEASES=()

fixture_package_database() {
    local package="${!#}"
    case "$package" in
        linux-modules-vendor-7.0.0-1016-nvidia)
            printf 'installed\tlibc6 (>= 2.39), linux-image-7.0.0-1016-nvidia | linux-image-unsigned-7.0.0-1016-nvidia\n'
            ;;
        linux-modules-vendor-incomplete)
            printf 'config-files\tlinux-image-7.0.0-1016-nvidia\n'
            ;;
        *) return 1 ;;
    esac
}
_cc_pkg_database_program() { printf '%s\n' fixture_package_database; }
metadata_releases="$(_cc_kernel_direct_image_dependency_releases linux-modules-vendor-7.0.0-1016-nvidia)"
[ "$metadata_releases" = 7.0.0-1016-nvidia ] || fail 'exact alternative image dependencies were not normalized'
[ -z "$(_cc_kernel_direct_image_dependency_releases linux-modules-vendor-incomplete)" ] ||
    fail 'non-installed package metadata was accepted'

_cc_kernel_inventory_capture() { :; }
_cc_kernel_can_correlate_packages() { return 0; }
_cc_kernel_package_releases() {
    [ "${#_CC_KERNEL_PACKAGE_RELEASES[@]}" -eq 0 ] || printf '%s\n' "${_CC_KERNEL_PACKAGE_RELEASES[@]}"
}
_cc_kernel_direct_image_dependency_releases() {
    local value="${TEST_DEPENDENCY_RELEASES[$1]-__unavailable__}"
    [ "$value" != __unavailable__ ] || return 1
    [ -z "$value" ] || printf '%s\n' "$value"
}

_CC_KERNEL_PACKAGE_RELEASES=(
    7.0.0-1014-nvidia
    7.0.0-1015-nvidia
    7.0.0-1016-nvidia
)
_CC_KERNEL_INSTALLED_PACKAGES=(
    linux-image-7.0.0-1014-nvidia
    linux-modules-7.0.0-1014-nvidia
    linux-modules-extra-7.0.0-1014-nvidia
    linux-modules-nvidia-fs-7.0.0-1014-nvidia
    linux-image-7.0.0-1015-nvidia
    linux-modules-7.0.0-1015-nvidia
    linux-modules-nvidia-fs-7.0.0-1015-nvidia
    linux-image-7.0.0-1016-nvidia
    linux-modules-7.0.0-1016-nvidia
    linux-modules-nvidia-fs-7.0.0-1016-nvidia
)
TEST_DEPENDENCY_RELEASES[linux-modules-nvidia-fs-7.0.0-1014-nvidia]=7.0.0-1014-nvidia
TEST_DEPENDENCY_RELEASES[linux-modules-nvidia-fs-7.0.0-1015-nvidia]=7.0.0-1015-nvidia
TEST_DEPENDENCY_RELEASES[linux-modules-nvidia-fs-7.0.0-1016-nvidia]=7.0.0-1016-nvidia

orphans="$(_cc_kernel_orphan_component_records)"
[ -z "$orphans" ] || fail 'valid ordinary, extra, and NVIDIA-FS packages were diagnosed as orphaned'
[ "$(_cc_kernel_companion_module_release linux-modules-nvidia-fs-7.0.0-1016-nvidia)" = 7.0.0-1016-nvidia ] ||
    fail 'running NVIDIA companion did not associate with its exact image release'
[ "$(_cc_kernel_companion_module_release linux-modules-nvidia-fs-7.0.0-1015-nvidia)" = 7.0.0-1015-nvidia ] ||
    fail 'fallback NVIDIA companion did not associate with its exact image release'
[ "$(_cc_kernel_companion_module_release linux-modules-nvidia-fs-7.0.0-1014-nvidia)" = 7.0.0-1014-nvidia ] ||
    fail 'additional installed NVIDIA companion did not associate with its exact image release'
if _cc_kernel_in_list linux-modules-nvidia-fs-7.0.0-1016-nvidia "${_CC_KERNEL_PACKAGE_RELEASES[@]}"; then
    fail 'companion package created a bootable kernel release'
fi
protected_text="$(_cc_kernel_select_protected 0 7.0.0-1016-nvidia "${_CC_KERNEL_PACKAGE_RELEASES[@]}")"
assert_contains "$protected_text" 7.0.0-1016-nvidia 'running image release was not protected'
assert_contains "$protected_text" 7.0.0-1015-nvidia 'fallback image release was not protected'
assert_not_contains "$protected_text" 7.0.0-1014-nvidia \
    'additional image release unexpectedly became protected with KEEP_COUNT=0'

_CC_KERNEL_INSTALLED_PACKAGES+=(linux-modules-nvidia-fs-7.0.0-1013-nvidia)
TEST_DEPENDENCY_RELEASES[linux-modules-nvidia-fs-7.0.0-1013-nvidia]=7.0.0-1013-nvidia
orphans="$(_cc_kernel_orphan_component_records)"
assert_contains "$orphans" linux-modules-nvidia-fs-7.0.0-1013-nvidia \
    'companion for an absent image release was not diagnosed'

_CC_KERNEL_INSTALLED_PACKAGES+=(linux-modules-nvidia-fs-7.0.0-1012-nvidia)
orphans="$(_cc_kernel_orphan_component_records)"
assert_contains "$orphans" linux-modules-nvidia-fs-7.0.0-1012-nvidia \
    'unavailable companion metadata did not fail closed'

_CC_KERNEL_INSTALLED_PACKAGES+=(linux-modules-vendor-7.0.0-1011-nvidia)
TEST_DEPENDENCY_RELEASES[linux-modules-vendor-7.0.0-1011-nvidia]=$'7.0.0-1011-nvidia\n7.0.0-1010-nvidia'
orphans="$(_cc_kernel_orphan_component_records)"
assert_contains "$orphans" linux-modules-vendor-7.0.0-1011-nvidia \
    'ambiguous companion metadata did not fail closed'

_CC_KERNEL_INSTALLED_PACKAGES+=(
    linux-modules-nvidia-fs-helper
    linux-modules-vendor-malformed
)
orphans="$(_cc_kernel_orphan_component_records)"
assert_not_contains "$orphans" linux-modules-nvidia-fs-helper \
    'similar-looking unrelated package was treated as a release companion'
assert_not_contains "$orphans" linux-modules-vendor-malformed \
    'malformed package name was treated as a release companion'

TEST_DEPENDENCY_RELEASES[linux-modules-vendor-7.0.0-1014-nvidia]=7.0.0-9999-nvidia
_CC_KERNEL_INSTALLED_PACKAGES+=(linux-modules-vendor-7.0.0-1014-nvidia)
orphans="$(_cc_kernel_orphan_component_records)"
assert_contains "$orphans" linux-modules-vendor-7.0.0-1014-nvidia \
    'name/metadata mismatch did not fail closed'

# Companion packages are intentionally diagnostic-only and do not broaden the
# immutable cleanup mapping for any running, fallback, or additional image set.
cleanup_mapping="$(_cc_kernel_companion_packages_for_version 7.0.0-1015-nvidia)"
assert_not_contains "$cleanup_mapping" linux-modules-nvidia-fs-7.0.0-1015-nvidia \
    'diagnostic companion association broadened cleanup package planning'
additional_cleanup_mapping="$(_cc_kernel_companion_packages_for_version 7.0.0-1014-nvidia)"
assert_not_contains "$additional_cleanup_mapping" linux-modules-nvidia-fs-7.0.0-1014-nvidia \
    'additional-release companion broadened cleanup package planning'

printf 'Kernel package classification tests: PASS\n'
