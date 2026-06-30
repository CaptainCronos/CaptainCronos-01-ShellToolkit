#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-platform.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash uname hostname awk grep command
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Detect platform, package manager, init system, and host capabilities.
# ==============================================================================

cc_platform_os_value() {
    local key="$1"
    if [ -f /etc/os-release ]; then
        awk -F= -v key="$key" '$1==key {gsub(/^"|"$/, "", $2); print $2; exit}' /etc/os-release
    fi
}

cc_platform_os_id() { local v; v="$(cc_platform_os_value ID)"; echo "${v:-unknown}"; }
cc_platform_os_like() { local v; v="$(cc_platform_os_value ID_LIKE)"; echo "${v:-unknown}"; }
cc_platform_os_version() { local v; v="$(cc_platform_os_value VERSION_ID)"; echo "${v:-unknown}"; }
cc_platform_name() { local v; v="$(cc_platform_os_value PRETTY_NAME)"; echo "${v:-$(uname -s 2>/dev/null || echo unknown)}"; }
cc_platform_kernel() { uname -r 2>/dev/null || echo unknown; }
cc_platform_arch() { uname -m 2>/dev/null || echo unknown; }

cc_platform_package_manager() {
    if command -v apt >/dev/null 2>&1; then echo apt
    elif command -v dnf >/dev/null 2>&1; then echo dnf
    elif command -v yum >/dev/null 2>&1; then echo yum
    elif command -v zypper >/dev/null 2>&1; then echo zypper
    elif command -v pacman >/dev/null 2>&1; then echo pacman
    elif command -v pkg >/dev/null 2>&1; then echo pkg
    else echo none
    fi
}

cc_platform_init_system() {
    if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then echo systemd
    elif command -v rc-service >/dev/null 2>&1; then echo openrc
    else echo unknown
    fi
}

cc_platform_type() {
    local id like
    id="$(cc_platform_os_id)"
    like="$(cc_platform_os_like)"
    if command -v midclt >/dev/null 2>&1; then echo truenas-scale
    elif [ "$id" = "linuxmint" ]; then echo linuxmint
    elif [ "$id" = "ubuntu" ]; then echo ubuntu
    elif [ "$id" = "debian" ]; then echo debian
    elif printf '%s' "$like" | grep -qw debian; then echo debian-like
    elif [ "$(uname -s 2>/dev/null || true)" = "FreeBSD" ]; then echo freebsd
    else echo linux
    fi
}

cc_capability_exists() {
    local cap="$1"
    case "$cap" in
        apt) command -v apt >/dev/null 2>&1 ;;
        battery) [ -d /sys/class/power_supply ] && ls /sys/class/power_supply/BAT* >/dev/null 2>&1 ;;
        docker) command -v docker >/dev/null 2>&1 ;;
        git) command -v git >/dev/null 2>&1 ;;
        network) command -v ip >/dev/null 2>&1 || command -v nmcli >/dev/null 2>&1 ;;
        podman) command -v podman >/dev/null 2>&1 ;;
        smart) command -v smartctl >/dev/null 2>&1 ;;
        storage) command -v lsblk >/dev/null 2>&1 ;;
        systemd) [ "$(cc_platform_init_system)" = "systemd" ] ;;
        truenas) command -v midclt >/dev/null 2>&1 ;;
        zfs) command -v zpool >/dev/null 2>&1 || command -v zfs >/dev/null 2>&1 ;;
        *) command -v "$cap" >/dev/null 2>&1 ;;
    esac
}

cc_capability_status() { if cc_capability_exists "$1"; then echo yes; else echo no; fi; }
cc_capability_list() { printf '%s\n' git apt systemd storage smart zfs truenas docker podman network battery; }

cc_platform_infer_profile() {
    case "$(cc_platform_type)" in
        truenas-scale) echo truenas-scale ;;
        ubuntu|linuxmint|debian|debian-like) echo developer ;;
        *) echo default ;;
    esac
}

cc_platform_summary() {
    printf '%-18s %s\n' "Platform:" "$(cc_platform_name)"
    printf '%-18s %s\n' "OS ID:" "$(cc_platform_os_id)"
    printf '%-18s %s\n' "OS Like:" "$(cc_platform_os_like)"
    printf '%-18s %s\n' "Version:" "$(cc_platform_os_version)"
    printf '%-18s %s\n' "Type:" "$(cc_platform_type)"
    printf '%-18s %s\n' "Kernel:" "$(cc_platform_kernel)"
    printf '%-18s %s\n' "Arch:" "$(cc_platform_arch)"
    printf '%-18s %s\n' "Package mgr:" "$(cc_platform_package_manager)"
    printf '%-18s %s\n' "Init system:" "$(cc_platform_init_system)"
}
