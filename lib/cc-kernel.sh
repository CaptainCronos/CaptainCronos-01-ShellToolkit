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
    # GNU sort -V matches the version syntax used by supported Linux packages.
    # LC_ALL=C keeps ordering stable across host locales.
    LC_ALL=C sort -V -u
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

_cc_kernel_package_releases() {
    local package release
    _cc_kernel_can_correlate_packages || return 0
    while IFS= read -r package; do
        case "$package" in
            linux-image-unsigned-*) release="${package#linux-image-unsigned-}" ;;
            linux-image-*) release="${package#linux-image-}" ;;
            *) continue ;;
        esac
        # Excludes unversioned meta packages such as linux-image-generic/amd64.
        case "$release" in
            [0-9]*.*) printf '%s\n' "$release" ;;
        esac
    done < <(_cc_pkg_list_installed 2>/dev/null || true)
}

_cc_kernel_list() {
    local boot_dir file running
    boot_dir="$(_cc_kernel_boot_dir)"
    _cc_kernel_supported || {
        _cc_kernel_running
        return
    }

    {
        if [ -d "$boot_dir" ]; then
            while IFS= read -r -d '' file; do
                file="${file##*/vmlinuz-}"
                _cc_kernel_artifact_release_safe "$file" || continue
                printf '%s\n' "$file"
            done < <(find "$boot_dir" -xdev -maxdepth 1 -type f -name 'vmlinuz-*' -print0 2>/dev/null)
        fi
        _cc_kernel_package_releases
        running="$(_cc_kernel_running 2>/dev/null || true)"
        [ -z "$running" ] || printf '%s\n' "$running"
    } | awk 'NF && !seen[$0]++' | _cc_kernel_version_order
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

_cc_kernel_protected() {
    local keep_count="${1:-${KEEP_COUNT:-2}}" running kernel
    local -a non_running=()
    _cc_kernel_validate_keep_count "$keep_count" || return 2
    running="$(_cc_kernel_running)" || return 1

    while IFS= read -r kernel; do
        [ -n "$kernel" ] || continue
        [ "$kernel" = "$running" ] || non_running+=("$kernel")
    done < <(_cc_kernel_list)

    {
        printf '%s\n' "$running"
        if [ "$keep_count" -gt 0 ] && [ "${#non_running[@]}" -gt 0 ]; then
            printf '%s\n' "${non_running[@]}" | tail -n "$keep_count"
        fi
    } | awk 'NF && !seen[$0]++' | _cc_kernel_version_order
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
    local -a protected=()
    _cc_kernel_supported || return 3
    running="$(_cc_kernel_running)" || return 1
    mapfile -t protected < <(_cc_kernel_protected "$keep_count") || return
    while IFS= read -r kernel; do
        [ -n "$kernel" ] || continue
        [ "$kernel" = "$running" ] && continue
        _cc_kernel_in_list "$kernel" "${protected[@]}" || printf '%s\n' "$kernel"
    done < <(_cc_kernel_list)
}

_cc_kernel_primary_packages_for_version() {
    [ "$#" -eq 1 ] || return 2
    local version="$1" package
    while IFS= read -r package; do
        case "$package" in
            "linux-image-$version"|"linux-image-unsigned-$version") printf '%s\n' "$package" ;;
        esac
    done < <(_cc_pkg_list_installed 2>/dev/null || true)
}

_cc_kernel_companion_packages_for_version() {
    [ "$#" -eq 1 ] || return 2
    local version="$1" package
    while IFS= read -r package; do
        case "$package" in
            "linux-image-$version"|"linux-image-unsigned-$version"|\
            "linux-modules-$version"|"linux-modules-extra-$version"|\
            "linux-headers-$version"|"linux-tools-$version"|\
            "linux-cloud-tools-$version")
                printf '%s\n' "$package"
                ;;
        esac
    done < <(_cc_pkg_list_installed 2>/dev/null || true)
}

_cc_kernel_packages_for_version() {
    [ "$#" -eq 1 ] || return 2
    local version="$1" boot_path owner
    local -a primary=() owners=() packages=()
    _cc_kernel_can_correlate_packages || return 3
    mapfile -t primary < <(_cc_kernel_primary_packages_for_version "$version")
    [ "${#primary[@]}" -eq 1 ] || return 4

    boot_path="$(_cc_kernel_boot_dir)/vmlinuz-$version"
    if [ -e "$boot_path" ]; then
        mapfile -t owners < <(_cc_pkg_owners_of_path "$boot_path" 2>/dev/null || true)
        [ "${#owners[@]}" -eq 1 ] || return 4
        owner="${owners[0]}"
        [ "$owner" = "${primary[0]}" ] || return 4
    fi

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
    local release="$1" keep_count="${2:-${KEEP_COUNT:-2}}" state=""
    local -a protected=() candidates=()
    mapfile -t protected < <(_cc_kernel_protected "$keep_count")
    if _cc_kernel_supported; then
        mapfile -t candidates < <(_cc_kernel_cleanup_candidates "$keep_count")
    fi
    _cc_kernel_is_running "$release" && state=RUNNING
    _cc_kernel_in_list "$release" "${protected[@]}" && state="${state:+$state,}PROTECTED"
    _cc_kernel_in_list "$release" "${candidates[@]}" && state="${state:+$state,}CANDIDATE"
    printf '%s\n' "${state:-UNCLASSIFIED}"
}

_cc_kernel_cleanup_packages() {
    local keep_count="${1:-${KEEP_COUNT:-2}}" version
    while IFS= read -r version; do
        [ -n "$version" ] || continue
        _cc_kernel_packages_for_version "$version" || true
    done < <(_cc_kernel_cleanup_candidates "$keep_count") | awk 'NF && !seen[$0]++' | sort
}

_cc_kernel_reboot_marker() {
    printf '%s\n' "${CC_KERNEL_REBOOT_MARKER:-/var/run/reboot-required}"
}

_cc_kernel_reboot_state() {
    local running newest marker
    _cc_kernel_supported || { printf '%s\n' unknown; return 0; }
    running="$(_cc_kernel_running 2>/dev/null || true)"
    newest="$(_cc_kernel_newest 2>/dev/null || true)"
    marker="$(_cc_kernel_reboot_marker)"
    if [ -f "$marker" ]; then
        printf '%s\n' required
    elif [ -n "$running" ] && [ -n "$newest" ] && [ "$running" != "$newest" ]; then
        printf '%s\n' newer-kernel-installed
    elif [ -n "$running" ] && [ "$running" = "$newest" ]; then
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
    boot_dir="$(_cc_kernel_boot_dir)"
    warn_threshold="${CC_KERNEL_USAGE_WARN_PERCENT:-90}"
    case "$warn_threshold" in
        ''|*[!0-9]*) warn_threshold=90 ;;
    esac
    if ! _cc_kernel_supported; then
        printf 'WARN\tDetailed boot-artifact inspection is unsupported on %s.\n' "$(_cc_kernel_os)"
        return 0
    fi
    if [ ! -d "$boot_dir" ] || [ ! -r "$boot_dir" ]; then
        printf 'FAIL\tBoot path is inaccessible: %s\n' "$boot_dir"
        return 0
    fi
    if [ -z "$(_cc_kernel_boot_filesystem_field SOURCE 2>/dev/null || true)" ]; then
        printf 'FAIL\tUnable to identify the filesystem containing %s.\n' "$boot_dir"
        issue_count=$((issue_count + 1))
    fi

    running="$(_cc_kernel_running 2>/dev/null || true)"
    if [ -n "$running" ] && [ "$(_cc_kernel_artifact_presence kernel "$running")" != yes ]; then
        printf 'FAIL\tRunning kernel image is missing or unsafe: %s\n' "$running"
        issue_count=$((issue_count + 1))
    fi

    if _cc_kernel_can_correlate_packages; then
        while IFS= read -r release; do
            [ -n "$release" ] || continue
            state="$(_cc_kernel_artifact_state "$release")"
            [ "$state" = MATCHED ] && continue
            severity=WARN
            printf '%s\t%s artifact correlation is %s.\n' "$severity" "$release" "$state"
            issue_count=$((issue_count + 1))
        done < <(_cc_kernel_artifact_releases)
    else
        printf 'WARN\tPackage correlation is unsupported for the %s kernel package family.\n' "$(_cc_kernel_distribution_family)"
        issue_count=$((issue_count + 1))
        while IFS= read -r release; do
            [ -n "$release" ] || continue
            if [ "$(_cc_kernel_artifact_presence kernel "$release")" != yes ] ||
                [ "$(_cc_kernel_artifact_presence initramfs "$release")" != yes ]; then
                printf 'WARN\t%s has an incomplete kernel/initramfs artifact pair.\n' "$release"
                issue_count=$((issue_count + 1))
            fi
        done < <(_cc_kernel_artifact_releases)
    fi

    case "$(_cc_kernel_reboot_state)" in
        required)
            printf 'WARN\tThe host reboot marker is present.\n'
            issue_count=$((issue_count + 1))
            ;;
        newer-kernel-installed)
            printf 'WARN\tA newer installed kernel is not currently running.\n'
            issue_count=$((issue_count + 1))
            ;;
    esac

    boot_usage="$(_cc_kernel_boot_filesystem_field USE% 2>/dev/null || true)"
    boot_usage="$(_cc_kernel_percent_value "$boot_usage")"
    if [[ "$boot_usage" =~ ^[0-9]+$ ]] && [ "$boot_usage" -ge "$warn_threshold" ]; then
        printf 'WARN\tBoot filesystem utilization is %s%%.\n' "$boot_usage"
        issue_count=$((issue_count + 1))
    fi
    efi_path="$(_cc_kernel_efi_path 2>/dev/null || true)"
    if [ -n "$efi_path" ]; then
        efi_source="$(_cc_kernel_efi_filesystem_field SOURCE 2>/dev/null || true)"
        efi_type="$(_cc_kernel_efi_filesystem_field FSTYPE 2>/dev/null || true)"
        if [ -z "$efi_source" ] || [ -z "$efi_type" ]; then
            printf 'WARN\tEFI filesystem metadata could not be read completely.\n'
            issue_count=$((issue_count + 1))
        fi
        efi_usage="$(_cc_kernel_efi_filesystem_field USE% 2>/dev/null || true)"
        efi_usage="$(_cc_kernel_percent_value "$efi_usage")"
        if [[ "$efi_usage" =~ ^[0-9]+$ ]] && [ "$efi_usage" -ge "$warn_threshold" ]; then
            printf 'WARN\tEFI filesystem utilization is %s%%.\n' "$efi_usage"
            issue_count=$((issue_count + 1))
        fi
    fi
    unsafe_count="$(_cc_kernel_artifact_unsafe_count)"
    if [ "$unsafe_count" -gt 0 ]; then
        printf 'WARN\t%s artifact name(s) could not be safely correlated.\n' "$unsafe_count"
        issue_count=$((issue_count + 1))
    fi
    if [ "$issue_count" -eq 0 ]; then
        printf 'PASS\tKernel packages and boot artifacts are consistent.\n'
    fi
}

_cc_kernel_health_severity() {
    local keep_count="${1:-${KEEP_COUNT:-2}}" severity result=PASS
    while IFS=$'\t' read -r severity _; do
        case "$severity" in
            FAIL) result=FAIL ;;
            WARN) [ "$result" = FAIL ] || result=WARN ;;
        esac
    done < <(_cc_kernel_health_findings "$keep_count")
    printf '%s\n' "$result"
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
