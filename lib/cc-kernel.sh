#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-kernel.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash uname find sort awk
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Provide safe, reusable kernel inspection and classification.
# ==============================================================================

if [ -z "${CC_KERNEL_LOADED:-}" ]; then
    _cc_kernel_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_kernel_lib_dir/cc-packages.sh"
    # shellcheck disable=SC1091
    source "$_cc_kernel_lib_dir/cc-platform.sh"
    unset _cc_kernel_lib_dir
    CC_KERNEL_LOADED=1
fi

_cc_kernel_os() {
    if [ -n "${CC_KERNEL_OS:-}" ]; then
        printf '%s\n' "$CC_KERNEL_OS"
    else
        uname -s 2>/dev/null || printf '%s\n' unknown
    fi
}

_cc_kernel_supported() {
    [ "$(_cc_kernel_os)" = Linux ]
}

_cc_kernel_distribution_family() {
    local id like manager
    _cc_kernel_supported || { printf '%s\n' not-applicable; return 0; }
    id="$(cc_platform_os_id 2>/dev/null || printf unknown)"
    like="$(cc_platform_os_like 2>/dev/null || printf unknown)"
    manager="$(_cc_pkg_family 2>/dev/null || printf none)"
    case "$id" in
        debian|ubuntu|linuxmint|pop|elementary|kali) printf '%s\n' debian; return 0 ;;
        fedora|rhel|centos|rocky|almalinux|ol) printf '%s\n' rpm; return 0 ;;
        arch|manjaro|endeavouros|garuda) printf '%s\n' arch; return 0 ;;
        opensuse*|sles|sled) printf '%s\n' opensuse; return 0 ;;
    esac
    if printf '%s\n' "$like" | grep -qw debian; then printf '%s\n' debian
    elif printf '%s\n' "$like" | grep -Eqw 'fedora|rhel|centos'; then printf '%s\n' rpm
    elif printf '%s\n' "$like" | grep -qw arch; then printf '%s\n' arch
    elif printf '%s\n' "$like" | grep -Eqw 'suse|opensuse'; then printf '%s\n' opensuse
    else
        case "$manager" in
            apt-get) printf '%s\n' debian ;;
            dnf|yum) printf '%s\n' rpm ;;
            pacman) printf '%s\n' arch ;;
            zypper) printf '%s\n' opensuse ;;
            *) printf '%s\n' unknown-linux ;;
        esac
    fi
}

_cc_kernel_package_model() {
    case "$(_cc_kernel_distribution_family)" in
        debian) printf '%s\n' 'Debian linux-image packages' ;;
        rpm) printf '%s\n' 'RPM versioned kernel packages' ;;
        arch) printf '%s\n' 'Arch kernel pkgbase packages' ;;
        opensuse) printf '%s\n' 'openSUSE kernel flavor packages' ;;
        not-applicable) printf '%s\n' 'not applicable' ;;
        *) printf '%s\n' 'unknown Linux package model' ;;
    esac
}

_cc_kernel_image_package_pattern() {
    case "$(_cc_kernel_distribution_family)" in
        debian) printf '%s\n' 'linux-image-<release>' ;;
        rpm) printf '%s\n' 'kernel-core/kernel-modules <version-release.arch>' ;;
        arch) printf '%s\n' 'linux/linux-lts/linux-zen/linux-hardened pkgbase' ;;
        opensuse) printf '%s\n' 'kernel-<flavor> with versioned RPM instances' ;;
        not-applicable) printf '%s\n' 'not applicable' ;;
        *) printf '%s\n' unknown ;;
    esac
}

_cc_kernel_package_adapter() {
    case "$(_cc_kernel_distribution_family)" in
        debian) printf '%s\n' debian ;;
        rpm) printf '%s\n' rpm-observation-only ;;
        arch) printf '%s\n' arch-pkgbase-observation-only ;;
        opensuse) printf '%s\n' opensuse-flavor-observation-only ;;
        not-applicable) printf '%s\n' 'not applicable' ;;
        *) printf '%s\n' none ;;
    esac
}

_cc_kernel_can_inspect() {
    _cc_kernel_running >/dev/null 2>&1
}

_cc_kernel_can_inspect_artifacts() {
    _cc_kernel_supported && [ -d "$(_cc_kernel_boot_dir)" ] && [ -r "$(_cc_kernel_boot_dir)" ] &&
        command -v find >/dev/null 2>&1
}

_cc_kernel_can_correlate_packages() {
    _cc_kernel_supported && [ "$(_cc_kernel_distribution_family)" = debian ] &&
        [ "$(_cc_pkg_family 2>/dev/null || true)" = apt-get ] &&
        command -v "$(_cc_pkg_database_program 2>/dev/null || printf cc-missing-package-database)" >/dev/null 2>&1
}

_cc_kernel_can_cleanup() {
    _cc_kernel_can_correlate_packages && [ "$(_cc_kernel_package_adapter)" = debian ]
}

_cc_kernel_support_word() {
    if "$@"; then printf '%s\n' supported; else printf '%s\n' unsupported; fi
}

_cc_kernel_provider_config_present() {
    [ "$#" -eq 1 ] || return 2
    case "$1" in
        initramfs-tools)
            [ -d "${CC_KERNEL_INITRAMFS_TOOLS_DIR:-/etc/initramfs-tools}" ]
            ;;
        dracut)
            [ -f "${CC_KERNEL_DRACUT_CONFIG:-/etc/dracut.conf}" ] ||
                [ -d "${CC_KERNEL_DRACUT_CONFIG_DIR:-/etc/dracut.conf.d}" ]
            ;;
        mkinitcpio)
            [ -f "${CC_KERNEL_MKINITCPIO_CONFIG:-/etc/mkinitcpio.conf}" ] ||
                [ -d "${CC_KERNEL_MKINITCPIO_PRESET_DIR:-/etc/mkinitcpio.d}" ]
            ;;
        *) return 2 ;;
    esac
}

_cc_kernel_provider_interface_name() {
    case "$1" in
        initramfs-tools) printf '%s\n' update-initramfs ;;
        dracut) printf '%s\n' dracut ;;
        mkinitcpio) printf '%s\n' mkinitcpio ;;
        *) return 1 ;;
    esac
}

_cc_kernel_provider_package_name() {
    case "$1" in
        initramfs-tools) printf '%s\n' initramfs-tools ;;
        dracut) printf '%s\n' dracut ;;
        mkinitcpio) printf '%s\n' mkinitcpio ;;
        *) return 1 ;;
    esac
}

_cc_kernel_provider_command_present() {
    local interface
    interface="$(_cc_kernel_provider_interface_name "$1")" || return
    command -v "$interface" >/dev/null 2>&1
}

_cc_kernel_provider_package_present() {
    local package
    package="$(_cc_kernel_provider_package_name "$1")" || return
    _cc_pkg_is_installed "$package" >/dev/null 2>&1
}

_cc_kernel_provider_score() {
    [ "$#" -eq 1 ] || return 2
    local provider="$1" score=0
    _cc_kernel_provider_interface_name "$provider" >/dev/null || return
    _cc_kernel_provider_command_present "$provider" && score=$((score + 1))
    _cc_kernel_provider_package_present "$provider" && score=$((score + 2))
    _cc_kernel_provider_config_present "$provider" && score=$((score + 2))
    printf '%s\n' "$score"
}

_cc_kernel_initramfs_providers() {
    local provider score
    _cc_kernel_supported || return 0
    for provider in initramfs-tools dracut mkinitcpio; do
        score="$(_cc_kernel_provider_score "$provider")"
        [ "$score" -gt 0 ] && printf '%s\n' "$provider"
    done
}

_cc_kernel_initramfs_provider() {
    local provider score top_score=-1 top_provider=none tied=0
    _cc_kernel_supported || { printf '%s\n' 'not applicable'; return 0; }
    while IFS= read -r provider; do
        [ -n "$provider" ] || continue
        score="$(_cc_kernel_provider_score "$provider")"
        if [ "$score" -gt "$top_score" ]; then
            top_score="$score"
            top_provider="$provider"
            tied=0
        elif [ "$score" -eq "$top_score" ]; then
            tied=1
        fi
    done < <(_cc_kernel_initramfs_providers)
    if [ "$top_provider" = none ]; then printf '%s\n' none
    elif [ "$tied" -eq 1 ]; then printf '%s\n' ambiguous
    else printf '%s\n' "$top_provider"
    fi
}

_cc_kernel_initramfs_additional_providers() {
    local primary provider first=1
    primary="$(_cc_kernel_initramfs_provider)"
    while IFS= read -r provider; do
        [ -n "$provider" ] || continue
        [ "$primary" != ambiguous ] && [ "$provider" = "$primary" ] && continue
        if [ "$first" -eq 0 ]; then printf ', '; fi
        printf '%s' "$provider"
        first=0
    done < <(_cc_kernel_initramfs_providers)
    [ "$first" -eq 0 ] && printf '\n' || printf '%s\n' none
}

_cc_kernel_initramfs_interface() {
    local provider
    provider="$(_cc_kernel_initramfs_provider)"
    case "$provider" in
        initramfs-tools|dracut|mkinitcpio) _cc_kernel_provider_interface_name "$provider" ;;
        'not applicable') printf '%s\n' 'not applicable' ;;
        *) printf '%s\n' "$provider" ;;
    esac
}

_cc_kernel_initramfs_status() {
    local provider
    provider="$(_cc_kernel_initramfs_provider)"
    case "$provider" in
        ambiguous) printf '%s\n' ambiguous ;;
        none) printf '%s\n' 'not detected' ;;
        'not applicable') printf '%s\n' 'not applicable' ;;
        *)
            if _cc_kernel_provider_command_present "$provider"; then printf '%s\n' detected
            else printf '%s\n' evidence-only
            fi
            ;;
    esac
}

_cc_kernel_efi_filesystem_state() {
    _cc_kernel_supported || { printf '%s\n' unknown; return 0; }
    command -v "${CC_KERNEL_FINDMNT_PROGRAM:-findmnt}" >/dev/null 2>&1 || {
        printf '%s\n' unknown
        return 0
    }
    if _cc_kernel_efi_path >/dev/null 2>&1; then printf '%s\n' present; else printf '%s\n' absent; fi
}

_cc_kernel_efi_runtime_state() {
    _cc_kernel_supported || { printf '%s\n' unknown; return 0; }
    if [ -d "${CC_KERNEL_EFI_RUNTIME_PATH:-/sys/firmware/efi}" ]; then
        printf '%s\n' active
    else
        printf '%s\n' inactive
    fi
}

_cc_kernel_running() {
    if [ -n "${CC_KERNEL_RUNNING:-}" ]; then
        printf '%s\n' "$CC_KERNEL_RUNNING"
    else
        uname -r 2>/dev/null || return 1
    fi
}

_cc_kernel_boot_dir() {
    printf '%s\n' "${CC_KERNEL_BOOT_DIR:-/boot}"
}

_cc_kernel_efi_candidates() {
    if [ -n "${CC_KERNEL_EFI_PATH:-}" ]; then
        printf '%s\n' "$CC_KERNEL_EFI_PATH"
    else
        printf '%s\n' /boot/efi /efi
    fi
}

_cc_kernel_mount_field() {
    [ "$#" -eq 3 ] || return 2
    local mode="$1" path="$2" field="$3" program
    case "$field" in
        SOURCE|FSTYPE|TARGET|SIZE|USED|AVAIL|USE%) ;;
        *) return 2 ;;
    esac
    program="${CC_KERNEL_FINDMNT_PROGRAM:-findmnt}"
    case "$mode" in
        target) "$program" -nro "$field" --target "$path" 2>/dev/null | head -n 1 ;;
        mountpoint) "$program" -nro "$field" --mountpoint "$path" 2>/dev/null | head -n 1 ;;
        *) return 2 ;;
    esac
}

_cc_kernel_boot_filesystem_field() {
    [ "$#" -eq 1 ] || return 2
    _cc_kernel_mount_field target "$(_cc_kernel_boot_dir)" "$1"
}

_cc_kernel_efi_path() {
    local candidate target
    while IFS= read -r candidate; do
        [ -d "$candidate" ] || continue
        target="$(_cc_kernel_mount_field mountpoint "$candidate" TARGET 2>/dev/null || true)"
        [ "$target" = "$candidate" ] || continue
        printf '%s\n' "$candidate"
        return 0
    done < <(_cc_kernel_efi_candidates)
    return 1
}

_cc_kernel_efi_filesystem_field() {
    [ "$#" -eq 1 ] || return 2
    local efi_path
    efi_path="$(_cc_kernel_efi_path)" || return 1
    _cc_kernel_mount_field mountpoint "$efi_path" "$1"
}

_cc_kernel_boot_usage_bytes() {
    local boot_dir blocks program
    boot_dir="$(_cc_kernel_boot_dir)"
    [ -d "$boot_dir" ] && [ -r "$boot_dir" ] || return 1
    program="${CC_KERNEL_DU_PROGRAM:-du}"
    command -v "$program" >/dev/null 2>&1 || return 1
    blocks="$("$program" -skx -- "$boot_dir" 2>/dev/null | awk 'NR == 1 {print $1}')"
    case "$blocks" in
        ''|*[!0-9]*) return 1 ;;
    esac
    printf '%s\n' "$((blocks * 1024))"
}

_cc_kernel_human_bytes() {
    [ "$#" -eq 1 ] || return 2
    awk -v bytes="$1" 'BEGIN {
        split("B KiB MiB GiB TiB", unit, " ")
        value = bytes + 0
        idx = 1
        while (value >= 1024 && idx < 5) {value /= 1024; idx++}
        if (idx == 1) printf "%d %s\n", value, unit[idx]
        else printf "%.1f %s\n", value, unit[idx]
    }'
}

_cc_kernel_version_order() {
    local version candidate inserted index
    local -a ordered=() input=()
    while IFS= read -r version; do
        [ -n "$version" ] || continue
        _cc_kernel_in_list "$version" "${input[@]}" || input+=("$version")
    done
    for version in "${input[@]}"; do
        inserted=0
        for index in "${!ordered[@]}"; do
            candidate="${ordered[$index]}"
            if _cc_kernel_version_lt "$version" "$candidate"; then
                ordered=("${ordered[@]:0:$index}" "$version" "${ordered[@]:$index}")
                inserted=1
                break
            fi
        done
        [ "$inserted" -eq 1 ] || ordered+=("$version")
    done
    [ "${#ordered[@]}" -eq 0 ] || printf '%s\n' "${ordered[@]}"
}

_cc_kernel_version_compare_program() {
    if [ -n "${CC_KERNEL_DPKG_PROGRAM:-}" ]; then
        printf '%s\n' "$CC_KERNEL_DPKG_PROGRAM"
    else
        _cc_pkg_database_program
    fi
}

_cc_kernel_version_lt() {
    [ "$#" -eq 2 ] || return 2
    local program
    program="$(_cc_kernel_version_compare_program 2>/dev/null)" || return 1
    "$program" --compare-versions "$1" lt "$2"
}

_cc_kernel_version_gt() {
    [ "$#" -eq 2 ] || return 2
    local program
    program="$(_cc_kernel_version_compare_program 2>/dev/null)" || return 1
    "$program" --compare-versions "$1" gt "$2"
}

_cc_kernel_artifact_name_release() {
    [ "$#" -eq 1 ] || return 2
    local initramfs_release
    case "$1" in
        vmlinuz-*) printf '%s\n' "${1#vmlinuz-}" ;;
        initrd.img-*) printf '%s\n' "${1#initrd.img-}" ;;
        initramfs-*)
            initramfs_release="${1#initramfs-}"
            printf '%s\n' "${initramfs_release%.img}"
            ;;
        System.map-*) printf '%s\n' "${1#System.map-}" ;;
        config-*) printf '%s\n' "${1#config-}" ;;
        *) return 1 ;;
    esac
}

_cc_kernel_artifact_release_safe() {
    [ "$#" -eq 1 ] || return 2
    case "$1" in
        ''|*/*|*$'\n'*|*$'\r'*|*$'\t'*|*.safe|*recovery*) return 1 ;;
        *) return 0 ;;
    esac
}

_cc_kernel_artifact_releases() {
    local boot_dir path name release
    _cc_kernel_supported || return 3
    boot_dir="$(_cc_kernel_boot_dir)"
    {
        _cc_kernel_list
        if [ -d "$boot_dir" ] && [ -r "$boot_dir" ]; then
            while IFS= read -r -d '' path; do
                name="${path##*/}"
                release="$(_cc_kernel_artifact_name_release "$name" 2>/dev/null || true)"
                _cc_kernel_artifact_release_safe "$release" || continue
                printf '%s\n' "$release"
            done < <(
                find "$boot_dir" -xdev -maxdepth 1 \( -type f -o -type l \) \
                    \( -name 'vmlinuz-*' -o -name 'initrd.img-*' -o -name 'initramfs-*' \
                    -o -name 'System.map-*' -o -name 'config-*' \) -print0 2>/dev/null
            )
        fi
    } | awk 'NF && !seen[$0]++' | _cc_kernel_version_order
}

_cc_kernel_artifact_path() {
    [ "$#" -eq 2 ] || return 2
    local type="$1" release="$2" boot_dir path
    _cc_kernel_artifact_release_safe "$release" || return 2
    boot_dir="$(_cc_kernel_boot_dir)"
    case "$type" in
        kernel) path="$boot_dir/vmlinuz-$release" ;;
        initramfs)
            path="$boot_dir/initrd.img-$release"
            if [ ! -e "$path" ] && [ ! -L "$path" ]; then
                path="$boot_dir/initramfs-$release.img"
            fi
            if [ ! -e "$path" ] && [ ! -L "$path" ]; then
                path="$boot_dir/initramfs-$release"
            fi
            ;;
        system-map) path="$boot_dir/System.map-$release" ;;
        config) path="$boot_dir/config-$release" ;;
        *) return 2 ;;
    esac
    printf '%s\n' "$path"
}

_cc_kernel_artifact_presence() {
    [ "$#" -eq 2 ] || return 2
    local path
    path="$(_cc_kernel_artifact_path "$1" "$2")" || return
    if [ -L "$path" ]; then
        printf '%s\n' unknown
    elif [ -f "$path" ]; then
        printf '%s\n' yes
    else
        printf '%s\n' no
    fi
}

_cc_kernel_artifact_size_bytes() {
    [ "$#" -eq 1 ] || return 2
    local release="$1" type path size total=0 program
    program="${CC_KERNEL_STAT_PROGRAM:-stat}"
    command -v "$program" >/dev/null 2>&1 || return 1
    for type in kernel initramfs system-map config; do
        path="$(_cc_kernel_artifact_path "$type" "$release")" || return
        [ -f "$path" ] && [ ! -L "$path" ] || continue
        size="$("$program" -c %s -- "$path" 2>/dev/null || true)"
        case "$size" in
            ''|*[!0-9]*) continue ;;
        esac
        total=$((total + size))
    done
    printf '%s\n' "$total"
}

_cc_kernel_artifact_unsafe_count() {
    local boot_dir path name release count=0
    boot_dir="$(_cc_kernel_boot_dir)"
    [ -d "$boot_dir" ] || { printf '0\n'; return 0; }
    while IFS= read -r -d '' path; do
        name="${path##*/}"
        release="$(_cc_kernel_artifact_name_release "$name" 2>/dev/null || true)"
        case "$release" in *.safe|*recovery*) continue ;; esac
        _cc_kernel_artifact_release_safe "$release" || count=$((count + 1))
    done < <(
        find "$boot_dir" -xdev -maxdepth 1 \( -type f -o -type l \) \
            \( -name 'vmlinuz-*' -o -name 'initrd.img-*' -o -name 'initramfs-*' \
            -o -name 'System.map-*' -o -name 'config-*' \) -print0 2>/dev/null
    )
    printf '%s\n' "$count"
}

_cc_kernel_inventory_capture() {
    local package release
    [ "${_CC_KERNEL_INVENTORY_READY:-0}" -eq 0 ] || return 0
    declare -ga _CC_KERNEL_INSTALLED_PACKAGES=()
    declare -ga _CC_KERNEL_PACKAGE_RELEASES=()
    _CC_KERNEL_INSTALLED_PACKAGES=()
    _CC_KERNEL_PACKAGE_RELEASES=()
    while IFS= read -r package; do
        [ -n "$package" ] || continue
        _CC_KERNEL_INSTALLED_PACKAGES+=("$package")
        case "$package" in
            linux-image-unsigned-*) release="${package#linux-image-unsigned-}" ;;
            linux-image-*) release="${package#linux-image-}" ;;
            *) continue ;;
        esac
        case "$release" in [0-9]*.*) _CC_KERNEL_PACKAGE_RELEASES+=("$release") ;; esac
    done < <(_cc_pkg_list_installed 2>/dev/null || true)
    if [ "${#_CC_KERNEL_PACKAGE_RELEASES[@]}" -gt 0 ]; then
        mapfile -t _CC_KERNEL_PACKAGE_RELEASES < <(
            printf '%s\n' "${_CC_KERNEL_PACKAGE_RELEASES[@]}" | _cc_kernel_version_order
        )
    fi
    _CC_KERNEL_INVENTORY_READY=1
}

_cc_kernel_inventory_reset() {
    _CC_KERNEL_INVENTORY_READY=0
    _CC_KERNEL_INSTALLED_PACKAGES=()
    _CC_KERNEL_PACKAGE_RELEASES=()
}

_cc_kernel_package_releases() {
    _cc_kernel_can_correlate_packages || return 0
    _cc_kernel_inventory_capture
    [ "${#_CC_KERNEL_PACKAGE_RELEASES[@]}" -eq 0 ] || printf '%s\n' "${_CC_KERNEL_PACKAGE_RELEASES[@]}"
}

_cc_kernel_list() {
    local running
    _cc_kernel_supported || {
        _cc_kernel_running
        return
    }
    if _cc_kernel_can_correlate_packages; then
        _cc_kernel_package_releases
    else
        running="$(_cc_kernel_running 2>/dev/null || true)"
        [ -z "$running" ] || printf '%s\n' "$running"
    fi
}

_cc_kernel_newest() {
    _cc_kernel_list | tail -n 1
}

_cc_kernel_is_running() {
    [ "$#" -eq 1 ] || return 2
    [ "$1" = "$(_cc_kernel_running)" ]
}

_cc_kernel_validate_keep_count() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

_cc_kernel_set_mapping_state() {
    [ "$#" -eq 1 ] || return 2
    local release="$1" boot_path owner
    local -a primary=() owners=()
    _cc_kernel_can_correlate_packages || { printf '%s\n' unsupported; return 0; }
    mapfile -t primary < <(_cc_kernel_primary_packages_for_version "$release")
    [ "${#primary[@]}" -eq 1 ] || {
        if [ "${#primary[@]}" -eq 0 ]; then printf '%s\n' missing-image; else printf '%s\n' ambiguous-image; fi
        return 0
    }
    boot_path="$(_cc_kernel_boot_dir)/vmlinuz-$release"
    [ -f "$boot_path" ] && [ ! -L "$boot_path" ] || { printf '%s\n' missing-artifact; return 0; }
    mapfile -t owners < <(_cc_pkg_owners_of_path "$boot_path" 2>/dev/null || true)
    [ "${#owners[@]}" -eq 1 ] || { printf '%s\n' uncertain-ownership; return 0; }
    owner="${owners[0]}"
    [ "$owner" = "${primary[0]}" ] || { printf '%s\n' ownership-mismatch; return 0; }
    printf '%s\n' verified
}

_cc_kernel_verified_sets() {
    local release
    _cc_kernel_inventory_capture
    for release in "${_CC_KERNEL_PACKAGE_RELEASES[@]}"; do
        [ -n "$release" ] || continue
        [ "$(_cc_kernel_set_mapping_state "$release")" = verified ] && printf '%s\n' "$release"
    done
}

_cc_kernel_newer_installed() {
    local running release
    local -a verified=()
    running="$(_cc_kernel_running)" || return 1
    mapfile -t verified < <(_cc_kernel_verified_sets)
    for release in "${verified[@]}"; do
        _cc_kernel_version_gt "$release" "$running" && printf '%s\n' "$release"
    done
}

_cc_kernel_pending_release() {
    local running
    local -a verified=()
    running="$(_cc_kernel_running)" || return 1
    mapfile -t verified < <(_cc_kernel_verified_sets)
    _cc_kernel_select_pending "$running" "${verified[@]}"
}

_cc_kernel_fallback_release() {
    local running
    local -a verified=()
    running="$(_cc_kernel_running)" || return 1
    mapfile -t verified < <(_cc_kernel_verified_sets)
    _cc_kernel_select_fallback "$running" "${verified[@]}"
}

_cc_kernel_select_pending() {
    [ "$#" -ge 1 ] || return 2
    local running="$1" newest
    shift
    [ "$#" -gt 0 ] || return 0
    newest="${!#}"
    _cc_kernel_version_gt "$newest" "$running" && printf '%s\n' "$newest"
}

_cc_kernel_select_fallback() {
    [ "$#" -ge 1 ] || return 2
    local running="$1" release previous=''
    shift
    for release in "$@"; do
        if [ "$release" = "$running" ]; then
            [ -z "$previous" ] || printf '%s\n' "$previous"
            [ -z "$previous" ] || return 0
            break
        fi
        if _cc_kernel_version_gt "$release" "$running"; then break; fi
        previous="$release"
    done
    if [ -n "$previous" ]; then
        printf '%s\n' "$previous"
    fi
}

_cc_kernel_protected() {
    local keep_count="${1:-${KEEP_COUNT:-2}}" running pending fallback
    local -a verified=()
    _cc_kernel_validate_keep_count "$keep_count" || return 2
    running="$(_cc_kernel_running)" || return 1
    _cc_kernel_inventory_capture
    mapfile -t verified < <(_cc_kernel_verified_sets)
    pending="$(_cc_kernel_select_pending "$running" "${verified[@]}" 2>/dev/null || true)"
    fallback="$(_cc_kernel_select_fallback "$running" "${verified[@]}" 2>/dev/null || true)"
    _cc_kernel_select_protected_inventory "$keep_count" "$running" "$pending" "$fallback" \
        "${_CC_KERNEL_PACKAGE_RELEASES[@]}"
}

_cc_kernel_select_protected() {
    [ "$#" -ge 2 ] || return 2
    local keep_count="$1" running="$2" kernel pending fallback additional=0
    local -a releases=()
    shift 2
    pending="$(_cc_kernel_select_pending "$running" "$@" 2>/dev/null || true)"
    fallback="$(_cc_kernel_select_fallback "$running" "$@" 2>/dev/null || true)"
    releases=("$@")
    _cc_kernel_select_protected_inventory "$keep_count" "$running" "$pending" "$fallback" "${releases[@]}"
}

_cc_kernel_select_protected_inventory() {
    [ "$#" -ge 4 ] || return 2
    local keep_count="$1" running="$2" pending="$3" fallback="$4" kernel additional=0
    local -a non_running=() selected=()
    shift 4
    selected+=("$running")
    [ -z "$pending" ] || selected+=("$pending")
    [ -z "$fallback" ] || selected+=("$fallback")
    for kernel in "$@"; do
        [ -n "$kernel" ] || continue
        [ "$kernel" = "$running" ] || non_running+=("$kernel")
    done
    for ((kernel = ${#non_running[@]} - 1; kernel >= 0 && additional < keep_count; kernel--)); do
        if ! _cc_kernel_in_list "${non_running[$kernel]}" "${selected[@]}"; then
            selected+=("${non_running[$kernel]}")
        fi
        additional=$((additional + 1))
    done
    printf '%s\n' "${selected[@]}" | awk 'NF && !seen[$0]++' | _cc_kernel_version_order
}

_cc_kernel_in_list() {
    [ "$#" -ge 1 ] || return 2
    local needle="$1" item
    shift
    for item in "$@"; do
        [ "$item" = "$needle" ] && return 0
    done
    return 1
}

_cc_kernel_cleanup_candidates() {
    local keep_count="${1:-${KEEP_COUNT:-2}}" kernel running
    local -a protected=() verified=()
    _cc_kernel_supported || return 3
    running="$(_cc_kernel_running)" || return 1
    mapfile -t verified < <(_cc_kernel_verified_sets)
    mapfile -t protected < <(_cc_kernel_protected "$keep_count") || return
    for kernel in "${verified[@]}"; do
        [ -n "$kernel" ] || continue
        [ "$kernel" = "$running" ] && continue
        _cc_kernel_in_list "$kernel" "${protected[@]}" || printf '%s\n' "$kernel"
    done
}

_cc_kernel_primary_packages_for_version() {
    [ "$#" -eq 1 ] || return 2
    local version="$1" package
    _cc_kernel_inventory_capture
    for package in "${_CC_KERNEL_INSTALLED_PACKAGES[@]}"; do
        case "$package" in
            "linux-image-$version"|"linux-image-unsigned-$version") printf '%s\n' "$package" ;;
        esac
    done
}

_cc_kernel_companion_packages_for_version() {
    [ "$#" -eq 1 ] || return 2
    local version="$1" package header_base
    header_base="${version%-*}"
    _cc_kernel_inventory_capture
    for package in "${_CC_KERNEL_INSTALLED_PACKAGES[@]}"; do
        case "$package" in
            "linux-image-$version"|"linux-image-unsigned-$version"|\
            "linux-modules-$version"|"linux-modules-extra-$version"|\
            "linux-headers-$version"|"linux-tools-$version"|\
            "linux-cloud-tools-$version")
                printf '%s\n' "$package"
                ;;
            "linux-headers-$header_base")
                _cc_kernel_in_list "linux-headers-$version" "${_CC_KERNEL_INSTALLED_PACKAGES[@]}" && printf '%s\n' "$package"
                ;;
        esac
    done
}

_cc_kernel_packages_for_version() {
    [ "$#" -eq 1 ] || return 2
    local version="$1" boot_path owner
    local -a primary=() owners=() packages=()
    _cc_kernel_can_correlate_packages || return 3
    mapfile -t primary < <(_cc_kernel_primary_packages_for_version "$version")
    [ "${#primary[@]}" -eq 1 ] || return 4

    [ "$(_cc_kernel_set_mapping_state "$version")" = verified ] || return 4

    mapfile -t packages < <(_cc_kernel_companion_packages_for_version "$version")
    [ "${#packages[@]}" -gt 0 ] || return 4
    printf '%s\n' "${packages[@]}" | awk 'NF && !seen[$0]++' | sort
}

_cc_kernel_package_state() {
    [ "$#" -eq 1 ] || return 2
    local -a packages=()
    _cc_kernel_can_correlate_packages || { printf '%s\n' unsupported; return 0; }
    mapfile -t packages < <(_cc_kernel_primary_packages_for_version "$1")
    case "${#packages[@]}" in
        0) printf '%s\n' absent ;;
        1) printf '%s\n' installed ;;
        *) printf '%s\n' ambiguous ;;
    esac
}

_cc_kernel_artifact_ownership() {
    [ "$#" -eq 1 ] || return 2
    local release="$1" path
    local -a packages=() owners=()
    _cc_kernel_can_correlate_packages || { printf '%s\n' unsupported; return 0; }
    [ "$(_cc_kernel_artifact_presence kernel "$release")" = yes ] || {
        printf '%s\n' missing
        return 0
    }
    mapfile -t packages < <(_cc_kernel_primary_packages_for_version "$release")
    [ "${#packages[@]}" -eq 1 ] || {
        if [ "${#packages[@]}" -gt 1 ]; then printf '%s\n' ambiguous; else printf '%s\n' unknown; fi
        return 0
    }
    path="$(_cc_kernel_artifact_path kernel "$release")"
    mapfile -t owners < <(_cc_pkg_owners_of_path "$path" 2>/dev/null || true)
    case "${#owners[@]}" in
        0) printf '%s\n' unknown ;;
        1)
            if [ "${owners[0]}" = "${packages[0]}" ]; then
                printf '%s\n' matched
            else
                printf '%s\n' unmatched
            fi
            ;;
        *) printf '%s\n' ambiguous ;;
    esac
}

_cc_kernel_artifact_state() {
    [ "$#" -eq 1 ] || return 2
    local release="$1" kernel initramfs system_map config package ownership
    kernel="$(_cc_kernel_artifact_presence kernel "$release")"
    initramfs="$(_cc_kernel_artifact_presence initramfs "$release")"
    system_map="$(_cc_kernel_artifact_presence system-map "$release")"
    config="$(_cc_kernel_artifact_presence config "$release")"
    package="$(_cc_kernel_package_state "$release")"

    if [ "$package" = unsupported ]; then
        if [ "$kernel" = no ] || [ "$initramfs" = no ]; then
            printf '%s\n' MISSING
        else
            printf '%s\n' UNKNOWN
        fi
        return 0
    fi
    if [ "$package" = ambiguous ] || [ "$kernel" = unknown ] || [ "$initramfs" = unknown ] || \
        [ "$system_map" = unknown ] || [ "$config" = unknown ]; then
        printf '%s\n' UNKNOWN
        return 0
    fi
    if [ "$package" = absent ]; then
        if [ "$kernel" = yes ] || [ "$initramfs" = yes ] || [ "$system_map" = yes ] || [ "$config" = yes ]; then
            printf '%s\n' UNMATCHED
        else
            printf '%s\n' UNKNOWN
        fi
        return 0
    fi
    if [ "$kernel" = no ] || [ "$initramfs" = no ]; then
        printf '%s\n' MISSING
        return 0
    fi
    ownership="$(_cc_kernel_artifact_ownership "$release")"
    if [ "$ownership" != matched ]; then
        printf '%s\n' UNKNOWN
    elif [ "$system_map" = no ] || [ "$config" = no ]; then
        printf '%s\n' PARTIAL
    else
        printf '%s\n' MATCHED
    fi
}

_cc_kernel_classification() {
    [ "$#" -ge 1 ] || return 2
    local release="$1" keep_count="${2:-${KEEP_COUNT:-2}}" state="" pending fallback
    local -a protected=() candidates=()
    mapfile -t protected < <(_cc_kernel_protected "$keep_count")
    if _cc_kernel_supported; then
        mapfile -t candidates < <(_cc_kernel_cleanup_candidates "$keep_count")
    fi
    pending="$(_cc_kernel_pending_release 2>/dev/null || true)"
    fallback="$(_cc_kernel_fallback_release 2>/dev/null || true)"
    _cc_kernel_is_running "$release" && state=RUNNING
    [ -z "$pending" ] || [ "$release" != "$pending" ] || state="${state:+$state,}PENDING"
    [ -z "$fallback" ] || [ "$release" != "$fallback" ] || state="${state:+$state,}FALLBACK"
    _cc_kernel_in_list "$release" "${protected[@]}" && state="${state:+$state,}PROTECTED"
    _cc_kernel_in_list "$release" "${candidates[@]}" && state="${state:+$state,}CANDIDATE"
    printf '%s\n' "${state:-UNCLASSIFIED}"
}

_cc_kernel_component_state() {
    [ "$#" -eq 2 ] || return 2
    local release="$1" component="$2" package header_base
    header_base="${release%-*}"
    _cc_kernel_inventory_capture
    case "$component" in
        image)
            [ "$(_cc_kernel_set_mapping_state "$release")" = verified ] && printf '%s\n' present || printf '%s\n' missing
            ;;
        modules)
            for package in "${_CC_KERNEL_INSTALLED_PACKAGES[@]}"; do
                case "$package" in "linux-modules-$release"|"linux-modules-extra-$release") printf '%s\n' present; return 0 ;; esac
            done
            if [ -d "${CC_KERNEL_MODULES_DIR:-/lib/modules}/$release" ]; then printf '%s\n' present
            else printf '%s\n' bundled-or-unavailable
            fi
            ;;
        headers)
            for package in "${_CC_KERNEL_INSTALLED_PACKAGES[@]}"; do
                case "$package" in "linux-headers-$release"|"linux-headers-$header_base") printf '%s\n' present; return 0 ;; esac
            done
            printf '%s\n' optional-missing
            ;;
        *) return 2 ;;
    esac
}

_cc_kernel_cleanup_packages() {
    local keep_count="${1:-${KEEP_COUNT:-2}}" version package release shared
    local -a candidates=() packages=() installed=()
    mapfile -t candidates < <(_cc_kernel_cleanup_candidates "$keep_count")
    mapfile -t installed < <(_cc_kernel_package_releases)
    for version in "${candidates[@]}"; do
        while IFS= read -r package; do
            [ -n "$package" ] || continue
            shared=0
            for release in "${installed[@]}"; do
                _cc_kernel_in_list "$release" "${candidates[@]}" && continue
                if _cc_kernel_package_matches_release "$package" "$release"; then shared=1; break; fi
            done
            [ "$shared" -eq 1 ] || packages+=("$package")
        done < <(_cc_kernel_packages_for_version "$version" || true)
    done
    [ "${#packages[@]}" -eq 0 ] || printf '%s\n' "${packages[@]}" | awk 'NF && !seen[$0]++' | sort
}

_cc_kernel_package_matches_release() {
    [ "$#" -eq 2 ] || return 2
    local package="$1" release="$2" header_base
    header_base="${release%-*}"
    case "$package" in
        "linux-image-$release"|"linux-image-unsigned-$release"|\
        "linux-modules-$release"|"linux-modules-extra-$release"|\
        "linux-headers-$release"|"linux-tools-$release"|\
        "linux-cloud-tools-$release") return 0 ;;
        "linux-headers-$header_base")
            _cc_kernel_inventory_capture
            _cc_kernel_in_list "linux-headers-$release" "${_CC_KERNEL_INSTALLED_PACKAGES[@]}"
            ;;
        *) return 1 ;;
    esac
}

_cc_kernel_package_mark() {
    [ "$#" -eq 1 ] || return 2
    local program="${CC_KERNEL_APT_MARK_PROGRAM:-apt-mark}" package="$1"
    command -v "$program" >/dev/null 2>&1 || { printf '%s\n' unknown; return 0; }
    if "$program" showmanual "$package" 2>/dev/null | grep -Fxq -- "$package"; then printf '%s\n' manual
    elif "$program" showauto "$package" 2>/dev/null | grep -Fxq -- "$package"; then printf '%s\n' automatic
    else printf '%s\n' unknown
    fi
}

_cc_kernel_set_mark_state() {
    [ "$#" -eq 1 ] || return 2
    local package mark manual=0 automatic=0 unknown=0
    while IFS= read -r package; do
        mark="$(_cc_kernel_package_mark "$package")"
        case "$mark" in manual) manual=1 ;; automatic) automatic=1 ;; *) unknown=1 ;; esac
    done < <(_cc_kernel_companion_packages_for_version "$1")
    if [ "$manual" -eq 1 ] && [ "$automatic" -eq 1 ]; then printf '%s\n' mixed
    elif [ "$manual" -eq 1 ]; then printf '%s\n' manual
    elif [ "$automatic" -eq 1 ]; then printf '%s\n' automatic
    elif [ "$unknown" -eq 1 ]; then printf '%s\n' unknown
    else printf '%s\n' unknown
    fi
}

_cc_kernel_package_installed_kib() {
    [ "$#" -gt 0 ] || { printf '0\n'; return 0; }
    local database package line total=0
    database="$(_cc_pkg_database_program)" || return 1
    for package in "$@"; do
        # dpkg-query expands this format expression; the shell must not.
        # shellcheck disable=SC2016
        line="$("$database" -W -f='${Installed-Size}\n' "$package" 2>/dev/null || true)"
        case "$line" in ''|*[!0-9]*) return 1 ;; esac
        total=$((total + line))
    done
    printf '%s\n' "$total"
}

_cc_kernel_package_issue_records() {
    local database
    _cc_kernel_can_correlate_packages || return 0
    database="$(_cc_pkg_database_program)" || return 1
    # dpkg-query expands these fields; the shell must not.
    # shellcheck disable=SC2016
    "$database" -W -f='${db:Status-Status}\t${Package}\n' 2>/dev/null |
        awk -F '\t' '$2 ~ /^linux-(image(-unsigned)?|modules(-extra)?|headers)-[0-9]/ && $1 != "installed" {print}'
}

_cc_kernel_direct_image_dependency_releases() {
    [ "$#" -eq 1 ] || return 2
    local query package="$1"
    query="${CC_KERNEL_DPKG_QUERY_PROGRAM:-dpkg-query}"
    command -v "$query" >/dev/null 2>&1 || return 1
    # A companion association is trustworthy only when the installed package's
    # own metadata directly names an exact signed or unsigned kernel image.
    # shellcheck disable=SC2016
    "$query" -W -f='${db:Status-Status}\t${Depends}\n' -- "$package" 2>/dev/null |
        awk -F '\t' '$1 == "installed" {
            dependencies = substr($0, index($0, "\t") + 1)
            count = split(dependencies, alternatives, /[,|]/)
            for (field_index = 1; field_index <= count; field_index++) {
                dependency = alternatives[field_index]
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", dependency)
                sub(/[[:space:]]*\(.*/, "", dependency)
                sub(/:[[:alnum:]-]+$/, "", dependency)
                if (dependency ~ /^linux-image-unsigned-[0-9]/) {
                    sub(/^linux-image-unsigned-/, "", dependency)
                    if (!seen[dependency]++) print dependency
                } else if (dependency ~ /^linux-image-[0-9]/) {
                    sub(/^linux-image-/, "", dependency)
                    if (!seen[dependency]++) print dependency
                }
            }
        }'
}

_cc_kernel_companion_module_release() {
    [ "$#" -eq 1 ] || return 2
    local package="$1" release stem
    local -a releases=()
    case "$package" in
        linux-modules-*-*[0-9].*) ;;
        *) return 1 ;;
    esac
    mapfile -t releases < <(_cc_kernel_direct_image_dependency_releases "$package") || return 1
    [ "${#releases[@]}" -eq 1 ] || return 1
    release="${releases[0]}"
    case "$release" in [0-9]*.*) ;; *) return 1 ;; esac
    stem="${package%-"$release"}"
    [ "$stem" != "$package" ] || return 1
    case "$stem" in
        linux-modules-?*) printf '%s\n' "$release" ;;
        *) return 1 ;;
    esac
}

_cc_kernel_orphan_component_records() {
    local package release image
    _cc_kernel_inventory_capture
    for package in "${_CC_KERNEL_INSTALLED_PACKAGES[@]}"; do
        case "$package" in
            linux-modules-extra-[0-9]*.*) release="${package#linux-modules-extra-}" ;;
            linux-modules-[0-9]*.*) release="${package#linux-modules-}" ;;
            linux-modules-*-*[0-9].*)
                release="$(_cc_kernel_companion_module_release "$package" 2>/dev/null || true)"
                [ -n "$release" ] || { printf '%s\n' "$package"; continue; }
                ;;
            linux-headers-[0-9]*-*) release="${package#linux-headers-}" ;;
            *) continue ;;
        esac
        image=0
        while IFS= read -r version; do
            [ "$release" = "$version" ] || [[ "$version" == "$release-"* ]] || continue
            image=1
            break
        done < <(_cc_kernel_package_releases)
        [ "$image" -eq 1 ] || printf '%s\n' "$package"
    done
}

_cc_kernel_reboot_marker() {
    printf '%s\n' "${CC_KERNEL_REBOOT_MARKER:-/var/run/reboot-required}"
}

_cc_kernel_reboot_state() {
    local running newer marker
    _cc_kernel_supported || { printf '%s\n' unknown; return 0; }
    running="$(_cc_kernel_running 2>/dev/null || true)"
    newer="$(_cc_kernel_pending_release 2>/dev/null || true)"
    marker="$(_cc_kernel_reboot_marker)"
    if [ -f "$marker" ]; then
        printf '%s\n' required
    elif [ -n "$running" ] && [ -n "$newer" ]; then
        printf '%s\n' newer-kernel-installed
    elif [ -n "$running" ]; then
        printf '%s\n' not-required
    else
        printf '%s\n' unknown
    fi
}

_cc_kernel_percent_value() {
    [ "$#" -eq 1 ] || return 2
    case "$1" in
        *%) printf '%s\n' "${1%%%}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

_cc_kernel_bootloader_environment() {
    local boot_dir efi_path grub_present=0 systemd_boot_present=0
    _cc_kernel_supported || { printf '%s\n' unknown; return 0; }
    boot_dir="$(_cc_kernel_boot_dir)"
    efi_path="$(_cc_kernel_efi_path 2>/dev/null || true)"
    if [ -d "$boot_dir/loader" ] && [ ! -L "$boot_dir/loader" ]; then systemd_boot_present=1; fi
    if { [ -d "$boot_dir/grub" ] && [ ! -L "$boot_dir/grub" ]; } ||
        { [ -d "$boot_dir/grub2" ] && [ ! -L "$boot_dir/grub2" ]; }; then
        grub_present=1
    fi
    if [ "$systemd_boot_present" -eq 1 ] && [ "$grub_present" -eq 1 ]; then
        printf '%s\n' ambiguous
    elif [ "$systemd_boot_present" -eq 1 ]; then
        printf '%s\n' systemd-boot
    elif [ "$grub_present" -eq 1 ]; then
        printf '%s\n' grub
    elif [ -n "$efi_path" ] && [ -d "$efi_path/EFI" ] && [ ! -L "$efi_path/EFI" ]; then
        printf '%s\n' efi-present
    else
        printf '%s\n' unknown
    fi
}

_cc_kernel_health_findings() {
    local keep_count="${1:-${KEEP_COUNT:-2}}" boot_dir running release state severity
    local boot_usage efi_path efi_source efi_type efi_usage unsafe_count issue_count=0 warn_threshold
    local artifact_states="${2:-}" mapping package_issue orphan
    boot_dir="$(_cc_kernel_boot_dir)"
    warn_threshold="${CC_KERNEL_USAGE_WARN_PERCENT:-90}"
    case "$warn_threshold" in
        ''|*[!0-9]*) warn_threshold=90 ;;
    esac
    if ! _cc_kernel_supported; then
        printf 'WARN\tREDUCED_INSPECTION\tDetailed boot-artifact inspection is unsupported on %s.\n' "$(_cc_kernel_os)"
        return 0
    fi
    if [ ! -d "$boot_dir" ] || [ ! -r "$boot_dir" ]; then
        printf 'FAIL\tBOOT_PATH_INACCESSIBLE\tBoot path is inaccessible: %s\n' "$boot_dir"
        return 0
    fi
    if [ -z "$(_cc_kernel_boot_filesystem_field SOURCE 2>/dev/null || true)" ]; then
        printf 'FAIL\tBOOT_FILESYSTEM_UNKNOWN\tUnable to identify the filesystem containing %s.\n' "$boot_dir"
        issue_count=$((issue_count + 1))
    fi

    running="$(_cc_kernel_running 2>/dev/null || true)"
    if [ -n "$running" ] && [ "$(_cc_kernel_artifact_presence kernel "$running")" != yes ]; then
        printf 'FAIL\tRUNNING_KERNEL_ARTIFACT_FAILURE\tRunning kernel image is missing or unsafe: %s\n' "$running"
        issue_count=$((issue_count + 1))
    fi
    if _cc_kernel_can_correlate_packages && [ -n "$running" ]; then
        mapping="$(_cc_kernel_set_mapping_state "$running")"
        if [ "$mapping" != verified ]; then
            printf 'FAIL\tRUNNING_KERNEL_PACKAGE_FAILURE\tRunning kernel package mapping is %s: %s\n' "$mapping" "$running"
            issue_count=$((issue_count + 1))
        fi
    fi

    if [ "$#" -lt 2 ]; then
        artifact_states="$(_cc_kernel_artifact_states)"
    fi

    if _cc_kernel_can_correlate_packages; then
        while IFS=$'\t' read -r release state; do
            [ -n "$release" ] || continue
            [ "$state" = MATCHED ] && continue
            severity=WARN
            printf '%s\tARTIFACT_%s\t%s artifact correlation is %s.\n' "$severity" "$state" "$release" "$state"
            issue_count=$((issue_count + 1))
        done <<< "$artifact_states"
        while IFS= read -r package_issue; do
            [ -n "$package_issue" ] || continue
            printf 'WARN\tPACKAGE_STATE_INCOMPLETE\tKernel package database state is incomplete: %s\n' "$package_issue"
            issue_count=$((issue_count + 1))
        done < <(_cc_kernel_package_issue_records)
        while IFS= read -r orphan; do
            [ -n "$orphan" ] || continue
            case "$orphan" in
                linux-modules-*) printf 'WARN\tORPHAN_MODULES\tModules package has no matching installed image set: %s\n' "$orphan" ;;
                linux-headers-*) printf 'WARN\tORPHAN_HEADERS\tHeaders package has no matching installed image set: %s\n' "$orphan" ;;
                *) printf 'WARN\tORPHAN_COMPONENT\tKernel component has no matching installed image set: %s\n' "$orphan" ;;
            esac
            issue_count=$((issue_count + 1))
        done < <(_cc_kernel_orphan_component_records)
    else
        printf 'WARN\tPACKAGE_CORRELATION_UNSUPPORTED\tPackage correlation is unsupported for the %s kernel package family.\n' "$(_cc_kernel_distribution_family)"
        issue_count=$((issue_count + 1))
        while IFS=$'\t' read -r release state; do
            [ -n "$release" ] || continue
            if [ "$state" = MISSING ]; then
                printf 'WARN\tARTIFACT_PARTIAL\t%s has an incomplete kernel/initramfs artifact pair.\n' "$release"
                issue_count=$((issue_count + 1))
            fi
        done <<< "$artifact_states"
    fi

    boot_usage="$(_cc_kernel_boot_filesystem_field USE% 2>/dev/null || true)"
    boot_usage="$(_cc_kernel_percent_value "$boot_usage")"
    if [[ "$boot_usage" =~ ^[0-9]+$ ]] && [ "$boot_usage" -ge "$warn_threshold" ]; then
        printf 'WARN\tBOOT_USAGE_HIGH\tBoot filesystem utilization is %s%%.\n' "$boot_usage"
        issue_count=$((issue_count + 1))
    fi
    efi_path="$(_cc_kernel_efi_path 2>/dev/null || true)"
    if [ -n "$efi_path" ]; then
        efi_source="$(_cc_kernel_efi_filesystem_field SOURCE 2>/dev/null || true)"
        efi_type="$(_cc_kernel_efi_filesystem_field FSTYPE 2>/dev/null || true)"
        if [ -z "$efi_source" ] || [ -z "$efi_type" ]; then
            printf 'WARN\tEFI_METADATA_UNKNOWN\tEFI filesystem metadata could not be read completely.\n'
            issue_count=$((issue_count + 1))
        fi
        efi_usage="$(_cc_kernel_efi_filesystem_field USE% 2>/dev/null || true)"
        efi_usage="$(_cc_kernel_percent_value "$efi_usage")"
        if [[ "$efi_usage" =~ ^[0-9]+$ ]] && [ "$efi_usage" -ge "$warn_threshold" ]; then
            printf 'WARN\tEFI_USAGE_HIGH\tEFI filesystem utilization is %s%%.\n' "$efi_usage"
            issue_count=$((issue_count + 1))
        fi
    fi
    unsafe_count="$(_cc_kernel_artifact_unsafe_count)"
    if [ "$unsafe_count" -gt 0 ]; then
        printf 'WARN\tARTIFACT_UNKNOWN\t%s artifact name(s) could not be safely correlated.\n' "$unsafe_count"
        issue_count=$((issue_count + 1))
    fi
    if [ "$issue_count" -eq 0 ]; then
        printf 'PASS\tCONSISTENT\tKernel packages and boot artifacts are consistent.\n'
    fi
}

_cc_kernel_health_status_from_findings() {
    local severity result=PASS
    while IFS=$'\t' read -r severity _; do
        case "$severity" in
            FAIL) result=FAIL ;;
            WARN) [ "$result" = FAIL ] || result=WARN ;;
        esac
    done
    printf '%s\n' "$result"
}

_cc_kernel_health_severity() {
    local keep_count="${1:-${KEEP_COUNT:-2}}"
    _cc_kernel_health_findings "$keep_count" | _cc_kernel_health_status_from_findings
}

_cc_kernel_health_status() {
    _cc_kernel_health_severity "${1:-${KEEP_COUNT:-2}}"
}

_cc_kernel_artifact_states() {
    local release
    while IFS= read -r release; do
        [ -n "$release" ] || continue
        printf '%s\t%s\n' "$release" "$(_cc_kernel_artifact_state "$release")"
    done < <(_cc_kernel_artifact_releases)
}

_cc_kernel_artifact_state_counts() {
    local artifact_states="${1:-}" release state matched=0 partial=0 unmatched=0 missing=0 unknown=0
    if [ "$#" -lt 1 ]; then artifact_states="$(_cc_kernel_artifact_states)"; fi
    while IFS=$'\t' read -r release state; do
        [ -n "$release" ] || continue
        case "$state" in
            MATCHED) matched=$((matched + 1)) ;;
            PARTIAL) partial=$((partial + 1)) ;;
            UNMATCHED) unmatched=$((unmatched + 1)) ;;
            MISSING) missing=$((missing + 1)) ;;
            *) unknown=$((unknown + 1)) ;;
        esac
    done <<< "$artifact_states"
    printf 'matched\t%s\npartial\t%s\nunmatched\t%s\nmissing\t%s\nunknown\t%s\n' \
        "$matched" "$partial" "$unmatched" "$missing" "$unknown"
}

_cc_kernel_snapshot_capture() {
    local keep_count="${1:-${KEEP_COUNT:-2}}" running newest pending fallback running_newest=unknown
    local artifact_states='' findings status boot_bytes boot_usage efi_usage key value
    local release older_count=0 manual_count=0 automatic_count=0 mixed_count=0 mark
    local -a kernels=() protected=() candidates=()
    declare -gA _CC_KERNEL_SNAPSHOT=()
    declare -ga _CC_KERNEL_SNAPSHOT_FINDINGS=()
    _CC_KERNEL_SNAPSHOT=()
    _CC_KERNEL_SNAPSHOT_FINDINGS=()

    _cc_kernel_validate_keep_count "$keep_count" || return 2
    running="$(_cc_kernel_running 2>/dev/null || printf unknown)"
    mapfile -t kernels < <(_cc_kernel_list 2>/dev/null || true)
    newest="$(_cc_kernel_newest 2>/dev/null || true)"
    pending="$(_cc_kernel_pending_release 2>/dev/null || true)"
    fallback="$(_cc_kernel_fallback_release 2>/dev/null || true)"
    mapfile -t protected < <(_cc_kernel_protected "$keep_count" 2>/dev/null || true)
    if _cc_kernel_can_cleanup; then
        mapfile -t candidates < <(_cc_kernel_cleanup_candidates "$keep_count" 2>/dev/null || true)
    fi
    [ -n "$newest" ] || newest=unknown
    if [ "$running" != unknown ] && [ "$newest" != unknown ]; then
        if [ "$running" = "$newest" ]; then running_newest=yes; else running_newest=no; fi
    fi
    for release in "${kernels[@]}"; do
        if [ "$running" != unknown ] && _cc_kernel_version_lt "$release" "$running"; then
            older_count=$((older_count + 1))
        fi
        mark="$(_cc_kernel_set_mark_state "$release" 2>/dev/null || printf unknown)"
        case "$mark" in
            manual) manual_count=$((manual_count + 1)) ;;
            automatic) automatic_count=$((automatic_count + 1)) ;;
            mixed) mixed_count=$((mixed_count + 1)) ;;
        esac
    done

    if _cc_kernel_can_inspect_artifacts; then
        artifact_states="$(_cc_kernel_artifact_states)"
    fi
    findings="$(_cc_kernel_health_findings "$keep_count" "$artifact_states")"
    status="$(printf '%s\n' "$findings" | _cc_kernel_health_status_from_findings)"
    while IFS= read -r value; do
        [ -n "$value" ] && _CC_KERNEL_SNAPSHOT_FINDINGS+=("$value")
    done <<< "$findings"

    boot_bytes=''
    boot_usage='not applicable'
    efi_usage='not applicable'
    if _cc_kernel_can_inspect_artifacts; then
        boot_bytes="$(_cc_kernel_boot_usage_bytes 2>/dev/null || true)"
        boot_usage="$(_cc_kernel_boot_filesystem_field USE% 2>/dev/null || printf unknown)"
        efi_usage="$(_cc_kernel_efi_filesystem_field USE% 2>/dev/null || printf 'not applicable')"
    fi

    _CC_KERNEL_SNAPSHOT[health_status]="$status"
    _CC_KERNEL_SNAPSHOT[running]="$running"
    _CC_KERNEL_SNAPSHOT[newest]="$newest"
    _CC_KERNEL_SNAPSHOT[pending]="${pending:-none}"
    _CC_KERNEL_SNAPSHOT[fallback]="${fallback:-none}"
    _CC_KERNEL_SNAPSHOT[running_is_newest]="$running_newest"
    _CC_KERNEL_SNAPSHOT[reboot_state]="$(_cc_kernel_reboot_state)"
    _CC_KERNEL_SNAPSHOT[os]="$(_cc_kernel_os)"
    _CC_KERNEL_SNAPSHOT[distribution_family]="$(_cc_kernel_distribution_family)"
    _CC_KERNEL_SNAPSHOT[package_model]="$(_cc_kernel_package_model)"
    _CC_KERNEL_SNAPSHOT[initramfs_provider]="$(_cc_kernel_initramfs_provider)"
    _CC_KERNEL_SNAPSHOT[bootloader]="$(_cc_kernel_bootloader_environment)"
    _CC_KERNEL_SNAPSHOT[efi_filesystem_state]="$(_cc_kernel_efi_filesystem_state)"
    _CC_KERNEL_SNAPSHOT[efi_runtime_state]="$(_cc_kernel_efi_runtime_state)"
    _CC_KERNEL_SNAPSHOT[installed_count]="${#kernels[@]}"
    _CC_KERNEL_SNAPSHOT[older_count]="$older_count"
    _CC_KERNEL_SNAPSHOT[protected_count]="${#protected[@]}"
    _CC_KERNEL_SNAPSHOT[cleanup_candidate_count]="${#candidates[@]}"
    _CC_KERNEL_SNAPSHOT[manual_set_count]="$manual_count"
    _CC_KERNEL_SNAPSHOT[automatic_set_count]="$automatic_count"
    _CC_KERNEL_SNAPSHOT[mixed_set_count]="$mixed_count"
    _CC_KERNEL_SNAPSHOT[boot_path]="$(_cc_kernel_boot_dir)"
    _CC_KERNEL_SNAPSHOT[boot_filesystem]='not applicable'
    _CC_KERNEL_SNAPSHOT[boot_filesystem_mount]='not applicable'
    if _cc_kernel_can_inspect_artifacts; then
        _CC_KERNEL_SNAPSHOT[boot_filesystem]="$(_cc_kernel_boot_filesystem_field SOURCE 2>/dev/null || printf unknown)"
        _CC_KERNEL_SNAPSHOT[boot_filesystem_mount]="$(_cc_kernel_boot_filesystem_field TARGET 2>/dev/null || printf unknown)"
    fi
    _CC_KERNEL_SNAPSHOT[boot_filesystem_usage]="$boot_usage"
    _CC_KERNEL_SNAPSHOT[boot_artifact_bytes]="${boot_bytes:-unknown}"
    if [ -n "$boot_bytes" ]; then
        _CC_KERNEL_SNAPSHOT[boot_artifact_usage]="$(_cc_kernel_human_bytes "$boot_bytes")"
    else
        _CC_KERNEL_SNAPSHOT[boot_artifact_usage]=unavailable
    fi
    _CC_KERNEL_SNAPSHOT[efi_usage]="$efi_usage"

    if _cc_kernel_can_inspect_artifacts; then
        while IFS=$'\t' read -r key value; do
            _CC_KERNEL_SNAPSHOT[artifact_$key]="$value"
        done < <(_cc_kernel_artifact_state_counts "$artifact_states")
    else
        for key in matched partial unmatched missing unknown; do
            _CC_KERNEL_SNAPSHOT[artifact_$key]=unavailable
        done
    fi
}

_cc_kernel_snapshot_get() {
    [ "$#" -eq 1 ] || return 2
    [ -n "${_CC_KERNEL_SNAPSHOT[$1]+set}" ] || return 1
    printf '%s\n' "${_CC_KERNEL_SNAPSHOT[$1]}"
}

_cc_kernel_snapshot_findings() {
    [ "${#_CC_KERNEL_SNAPSHOT_FINDINGS[@]}" -gt 0 ] || return 0
    printf '%s\n' "${_CC_KERNEL_SNAPSHOT_FINDINGS[@]}"
}

_cc_kernel_cleanup_supported() {
    _cc_kernel_can_cleanup
}

_cc_kernel_refresh_bootloader() {
    # Debian-family kernel packages refresh boot artifacts from package lifecycle
    # hooks. The kernel subsystem deliberately performs no independent refresh.
    _cc_kernel_cleanup_supported || return 3
    printf '%s\n' package-lifecycle-managed
}
