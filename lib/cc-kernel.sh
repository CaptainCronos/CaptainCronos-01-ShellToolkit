#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-kernel.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash uname find sort awk df
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

_cc_kernel_version_order() {
    # GNU sort -V matches the version syntax used by supported Linux packages.
    # LC_ALL=C keeps ordering stable across host locales.
    LC_ALL=C sort -V -u
}

_cc_kernel_package_releases() {
    local package release
    _cc_kernel_supported || return 0
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
            while IFS= read -r file; do
                file="${file##*/vmlinuz-}"
                case "$file" in
                    ''|*.safe|*recovery*) continue ;;
                esac
                printf '%s\n' "$file"
            done < <(find "$boot_dir" -maxdepth 1 -type f -name 'vmlinuz-*' -print 2>/dev/null)
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
    _cc_kernel_supported || return 3
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

_cc_kernel_boot_usage() {
    local boot_dir
    boot_dir="$(_cc_kernel_boot_dir)"
    [ -e "$boot_dir" ] || { printf '%s\n' unavailable; return 0; }
    df -hP "$boot_dir" 2>/dev/null | awk 'NR == 2 {printf "%s used (%s of %s), %s available\n", $5, $3, $2, $4}'
}

_cc_kernel_cleanup_supported() {
    _cc_kernel_supported || return 1
    case "$(_cc_pkg_family 2>/dev/null || true)" in
        apt-get) return 0 ;;
        *) return 1 ;;
    esac
}

_cc_kernel_refresh_bootloader() {
    # Debian-family kernel packages refresh boot artifacts from package lifecycle
    # hooks. The kernel subsystem deliberately performs no independent refresh.
    _cc_kernel_cleanup_supported || return 3
    printf '%s\n' package-lifecycle-managed
}
