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
    printf '%s\n' "$text" | grep -Fq -- "$expected" || fail "$label"
}

TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
CC_KERNEL_OS=Linux
CC_TEST_ID=unknown
CC_TEST_LIKE=unknown
CC_TEST_MANAGER=none
export CC_KERNEL_OS

cc_platform_os_id() { printf '%s\n' "$CC_TEST_ID"; }
cc_platform_os_like() { printf '%s\n' "$CC_TEST_LIKE"; }
_cc_pkg_family() { printf '%s\n' "$CC_TEST_MANAGER"; }
_cc_pkg_database_program() { printf '%s\n' true; }

CC_TEST_ID=ubuntu; CC_TEST_LIKE=debian; CC_TEST_MANAGER=apt-get
[ "$(_cc_kernel_distribution_family)" = debian ] || fail 'Debian package family detection failed'
[ "$(_cc_kernel_package_adapter)" = debian ] || fail 'Debian package adapter detection failed'
[ "$(_cc_kernel_image_package_pattern)" = 'linux-image-<release>' ] || fail 'Debian image model changed'
_cc_kernel_can_correlate_packages || fail 'Debian correlation support was not enabled'
_cc_kernel_can_cleanup || fail 'implemented Debian cleanup adapter was disabled'

CC_TEST_ID=fedora; CC_TEST_LIKE='rhel fedora'; CC_TEST_MANAGER=dnf
[ "$(_cc_kernel_distribution_family)" = rpm ] || fail 'RPM-family detection failed'
assert_contains "$(_cc_kernel_package_model)" RPM 'RPM package model was not represented'
if _cc_kernel_can_correlate_packages; then fail 'RPM correlation was enabled without an adapter'; fi
if _cc_kernel_can_cleanup; then fail 'RPM cleanup mutation was enabled'; fi

CC_TEST_ID=arch; CC_TEST_LIKE=arch; CC_TEST_MANAGER=pacman
[ "$(_cc_kernel_distribution_family)" = arch ] || fail 'Arch-family detection failed'
assert_contains "$(_cc_kernel_image_package_pattern)" linux-lts 'Arch pkgbase model was not represented'
if _cc_kernel_can_cleanup; then fail 'Arch cleanup mutation was enabled'; fi

CC_TEST_ID=opensuse-tumbleweed; CC_TEST_LIKE=suse; CC_TEST_MANAGER=zypper
[ "$(_cc_kernel_distribution_family)" = opensuse ] || fail 'openSUSE-family detection failed'
assert_contains "$(_cc_kernel_package_model)" flavor 'openSUSE flavor model was not represented'
if _cc_kernel_can_cleanup; then fail 'openSUSE cleanup mutation was enabled'; fi

CC_TEST_ID=custom; CC_TEST_LIKE=unknown; CC_TEST_MANAGER=none
[ "$(_cc_kernel_distribution_family)" = unknown-linux ] || fail 'unknown Linux family was not explicit'
if _cc_kernel_can_cleanup; then fail 'unknown Linux cleanup mutation was enabled'; fi

CC_KERNEL_OS=FreeBSD
[ "$(_cc_kernel_distribution_family)" = 'not-applicable' ] || fail 'non-Linux package family was not applicable'
[ "$(_cc_kernel_initramfs_provider)" = 'not applicable' ] || fail 'non-Linux initramfs state was not applicable'
if _cc_kernel_can_cleanup; then fail 'non-Linux cleanup mutation was enabled'; fi
CC_KERNEL_OS=Linux

CC_TEST_PROVIDER_COMMANDS=''
CC_TEST_PROVIDER_PACKAGES=''
CC_TEST_PROVIDER_CONFIGS=''
_cc_kernel_provider_command_present() { [[ " $CC_TEST_PROVIDER_COMMANDS " == *" $1 "* ]]; }
_cc_kernel_provider_package_present() { [[ " $CC_TEST_PROVIDER_PACKAGES " == *" $1 "* ]]; }
_cc_kernel_provider_config_present() { [[ " $CC_TEST_PROVIDER_CONFIGS " == *" $1 "* ]]; }

CC_TEST_PROVIDER_COMMANDS='initramfs-tools'
CC_TEST_PROVIDER_PACKAGES='initramfs-tools'
CC_TEST_PROVIDER_CONFIGS='initramfs-tools'
[ "$(_cc_kernel_initramfs_provider)" = initramfs-tools ] || fail 'update-initramfs provider detection failed'
[ "$(_cc_kernel_initramfs_interface)" = update-initramfs ] || fail 'update-initramfs interface mapping failed'
[ "$(_cc_kernel_initramfs_status)" = detected ] || fail 'update-initramfs status changed'

CC_TEST_PROVIDER_COMMANDS=dracut
CC_TEST_PROVIDER_PACKAGES=dracut
CC_TEST_PROVIDER_CONFIGS=dracut
[ "$(_cc_kernel_initramfs_provider)" = dracut ] || fail 'dracut provider detection failed'
[ "$(_cc_kernel_initramfs_interface)" = dracut ] || fail 'dracut interface mapping failed'

CC_TEST_PROVIDER_COMMANDS=mkinitcpio
CC_TEST_PROVIDER_PACKAGES=mkinitcpio
CC_TEST_PROVIDER_CONFIGS=mkinitcpio
[ "$(_cc_kernel_initramfs_provider)" = mkinitcpio ] || fail 'mkinitcpio provider detection failed'

CC_TEST_PROVIDER_COMMANDS=''
CC_TEST_PROVIDER_PACKAGES=''
CC_TEST_PROVIDER_CONFIGS=''
[ "$(_cc_kernel_initramfs_provider)" = none ] || fail 'no-provider state changed'
[ "$(_cc_kernel_initramfs_status)" = 'not detected' ] || fail 'no-provider status changed'

CC_TEST_PROVIDER_COMMANDS='initramfs-tools dracut'
CC_TEST_PROVIDER_PACKAGES='initramfs-tools'
CC_TEST_PROVIDER_CONFIGS='initramfs-tools'
[ "$(_cc_kernel_initramfs_provider)" = initramfs-tools ] || fail 'strong provider evidence did not select the primary'
[ "$(_cc_kernel_initramfs_additional_providers)" = dracut ] || fail 'additional provider was not reported'

CC_TEST_PROVIDER_COMMANDS='dracut mkinitcpio'
CC_TEST_PROVIDER_PACKAGES=''
CC_TEST_PROVIDER_CONFIGS=''
[ "$(_cc_kernel_initramfs_provider)" = ambiguous ] || fail 'equal provider evidence was not ambiguous'
assert_contains "$(_cc_kernel_initramfs_additional_providers)" dracut 'ambiguous providers omitted dracut'
assert_contains "$(_cc_kernel_initramfs_additional_providers)" mkinitcpio 'ambiguous providers omitted mkinitcpio'
if declare -F _cc_kernel_rebuild_initramfs >/dev/null 2>&1; then
    fail 'provider detection exposed an initramfs mutation operation'
fi

CC_KERNEL_FINDMNT_PROGRAM=findmnt
CC_TEST_EFI_FILESYSTEM=absent
_cc_kernel_efi_path() { [ "$CC_TEST_EFI_FILESYSTEM" = present ] && printf '%s\n' /boot/efi; }
CC_TEST_EFI_FILESYSTEM=present
[ "$(_cc_kernel_efi_filesystem_state)" = present ] || fail 'EFI filesystem presence was not detected'
CC_TEST_EFI_FILESYSTEM=absent
[ "$(_cc_kernel_efi_filesystem_state)" = absent ] || fail 'EFI filesystem absence was not detected'

CC_KERNEL_EFI_RUNTIME_PATH="$TEST_DIR/efi-runtime"
export CC_KERNEL_EFI_RUNTIME_PATH
mkdir -p "$CC_KERNEL_EFI_RUNTIME_PATH"
[ "$(_cc_kernel_efi_runtime_state)" = active ] || fail 'active EFI runtime was not detected'
rmdir "$CC_KERNEL_EFI_RUNTIME_PATH"
[ "$(_cc_kernel_efi_runtime_state)" = inactive ] || fail 'inactive EFI runtime was not detected'

CC_KERNEL_BOOT_DIR="$TEST_DIR/boot"
export CC_KERNEL_BOOT_DIR
mkdir -p "$CC_KERNEL_BOOT_DIR/grub"
[ "$(_cc_kernel_bootloader_environment)" = grub ] || fail 'GRUB environment detection failed'
rmdir "$CC_KERNEL_BOOT_DIR/grub"
mkdir -p "$CC_KERNEL_BOOT_DIR/loader"
[ "$(_cc_kernel_bootloader_environment)" = systemd-boot ] || fail 'systemd-boot environment detection failed'
mkdir -p "$CC_KERNEL_BOOT_DIR/grub2"
[ "$(_cc_kernel_bootloader_environment)" = ambiguous ] || fail 'multiple bootloader evidence was not ambiguous'
rmdir "$CC_KERNEL_BOOT_DIR/loader" "$CC_KERNEL_BOOT_DIR/grub2"
[ "$(_cc_kernel_bootloader_environment)" = unknown ] || fail 'unknown bootloader state changed'

platform_output="$(bash "$PROJECT_ROOT/tools/commands/kernel" platform)"
assert_contains "$platform_output" 'Kernel Platform' 'platform command did not load'
assert_contains "$platform_output" 'Initramfs mutation:          not implemented' 'platform output implied initramfs mutation support'
assert_contains "$platform_output" 'Bootloader mutation:         not implemented' 'platform output implied bootloader mutation support'
deps_output="$(bash "$PROJECT_ROOT/tools/commands/kernel" deps)"
assert_contains "$deps_output" 'Detected initramfs providers' 'kernel dependency output omitted provider detection'
assert_contains "$deps_output" 'Mutation support' 'kernel dependency output omitted mutation policy'
non_linux_output="$(CC_KERNEL_OS=FreeBSD bash "$PROJECT_ROOT/tools/commands/kernel" platform)"
assert_contains "$non_linux_output" 'Kernel package model:        not applicable' 'non-Linux platform output applied Linux package semantics'
assert_contains "$non_linux_output" 'Cleanup:                     unsupported' 'non-Linux platform output enabled cleanup'

printf 'Kernel platform capability tests: PASS\n'
