#!/usr/bin/env bash
#
# Captain Cronos Shell Toolkit
# Script      : cc-host.sh
# Category    : Core
# Purpose     : Compose normalized, read-only observed and configured host facts.

if ! declare -F cc_env_host_id >/dev/null 2>&1; then
    _cc_host_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_host_lib_dir/cc-environment.sh"
    # shellcheck disable=SC1091
    source "$_cc_host_lib_dir/cc-platform.sh"
    unset _cc_host_lib_dir
fi

cc_host_hostname() { hostname -s 2>/dev/null || hostname 2>/dev/null || printf '%s\n' unknown; }

cc_host_static_hostname() {
    if command -v hostnamectl >/dev/null 2>&1; then
        hostnamectl --static 2>/dev/null | awk 'NF {print; exit}'
    fi
}

cc_host_desktop_environment() {
    local desktop="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
    [ -n "$desktop" ] || { printf '%s\n' unknown; return; }
    case "${desktop,,}" in
        *cinnamon*) printf '%s\n' Cinnamon ;; *gnome*) printf '%s\n' GNOME ;;
        *kde*|*plasma*) printf '%s\n' KDE ;; *) printf '%s\n' "$desktop" ;;
    esac
}

cc_host_session_type() {
    case "${XDG_SESSION_TYPE:-}" in x11|wayland|tty) printf '%s\n' "$XDG_SESSION_TYPE" ;;
        '') if [ -n "${DISPLAY:-}" ]; then printf '%s\n' x11; else printf '%s\n' unknown; fi ;;
        *) printf '%s\n' unknown ;;
    esac
}

# Stable TSV, intended for human commands and fixture consumers.  It creates no state.
cc_host_facts_tsv() {
    printf 'toolkit_host_id\t%s\n' "$(cc_env_host_id)"
    printf 'toolkit_host_id_source\t%s\n' "$(cc_config_identity_source)"
    printf 'hostname\t%s\n' "$(cc_host_hostname)"
    printf 'static_hostname\t%s\n' "$(cc_host_static_hostname || printf unknown)"
    printf 'os_id\t%s\n' "$(cc_platform_os_id)"
    printf 'os_like\t%s\n' "$(cc_platform_os_like)"
    printf 'os_version\t%s\n' "$(cc_platform_os_version)"
    printf 'os_name\t%s\n' "$(cc_platform_name)"
    printf 'kernel_release\t%s\n' "$(cc_platform_kernel)"
    printf 'architecture\t%s\n' "$(cc_platform_arch)"
    printf 'platform_type\t%s\n' "$(cc_platform_type)"
    printf 'init_system\t%s\n' "$(cc_platform_init_system)"
    printf 'package_manager\t%s\n' "$(cc_platform_package_manager)"
    printf 'desktop_environment\t%s\n' "$(cc_host_desktop_environment)"
    printf 'session_type\t%s\n' "$(cc_host_session_type)"
    printf 'host_role\t%s\n' "$(cc_env_role)"
    printf 'host_profile\t%s\n' "$(cc_env_profile)"
}
