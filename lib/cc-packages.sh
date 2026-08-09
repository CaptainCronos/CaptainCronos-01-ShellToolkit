#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-packages.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash command
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Provide semantic, platform-aware system package operations.
# ==============================================================================

if [ -z "${CC_PACKAGES_LOADED:-}" ]; then
    _cc_packages_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_packages_lib_dir/cc-programs.sh"
    # shellcheck disable=SC1091
    source "$_cc_packages_lib_dir/cc-platform.sh"
    unset _cc_packages_lib_dir
    CC_PACKAGES_LOADED=1
fi

_cc_pkg_family() {
    cc_platform_package_manager
}

_cc_pkg_manager() {
    local family
    family="$(_cc_pkg_family)" || return 1
    if [ "$family" = "apt-get" ]; then
        cc_program_get pkg-manager
    else
        printf '%s\n' "$family"
    fi
}

_cc_pkg_query_program() {
    [ "$(_cc_pkg_family)" = "apt-get" ] || return 1
    cc_program_get pkg-query
}

_cc_pkg_database_program() {
    [ "$(_cc_pkg_family)" = "apt-get" ] || return 1
    cc_program_get pkg-database
}

_cc_pkg_manager_exists() {
    local manager
    manager="$(_cc_pkg_manager)" || return 1
    [ "$manager" != "none" ] && command -v "$manager" >/dev/null 2>&1
}

_cc_pkg_print_command() {
    local rendered="DRY RUN:" argument
    for argument in "$@"; do
        printf -v argument '%q' "$argument"
        rendered+=" $argument"
    done
    if [ -n "${CC_PKG_REPORTER:-}" ]; then
        "${CC_PKG_REPORTER}" "$rendered"
    else
        printf '%s\n' "$rendered"
    fi
}

_cc_pkg_run() {
    local runner="${CC_PKG_RUNNER:-}"
    if [ "${CC_PKG_DRY_RUN:-0}" -eq 1 ]; then
        _cc_pkg_print_command sudo "$@"
    elif [ -n "$runner" ]; then
        "$runner" sudo "$@"
    else
        sudo "$@"
    fi
}

_cc_pkg_update() {
    local family manager
    family="$(_cc_pkg_family)" || return 1
    manager="$(_cc_pkg_manager)" || return 1
    case "$family" in
        apt-get) _cc_pkg_run "$manager" update ;;
        dnf|yum) _cc_pkg_run "$manager" makecache ;;
        zypper) _cc_pkg_run "$manager" refresh ;;
        pacman) _cc_pkg_run "$manager" -Sy ;;
        pkg) _cc_pkg_run "$manager" update ;;
        *) printf '[CC ERROR] Unsupported package manager: %s\n' "$manager" >&2; return 1 ;;
    esac
}

_cc_pkg_upgrade() {
    local family manager
    family="$(_cc_pkg_family)" || return 1
    manager="$(_cc_pkg_manager)" || return 1
    case "$family" in
        apt-get) _cc_pkg_run "$manager" upgrade -y ;;
        dnf) _cc_pkg_run "$manager" upgrade -y ;;
        yum) _cc_pkg_run "$manager" update -y ;;
        zypper) _cc_pkg_run "$manager" update -y ;;
        pacman) _cc_pkg_run "$manager" -Syu --noconfirm ;;
        pkg) _cc_pkg_run "$manager" upgrade -y ;;
        *) printf '[CC ERROR] Unsupported package manager: %s\n' "$manager" >&2; return 1 ;;
    esac
}

_cc_pkg_install() {
    [ "$#" -gt 0 ] || return 0
    local family manager
    family="$(_cc_pkg_family)" || return 1
    manager="$(_cc_pkg_manager)" || return 1
    case "$family" in
        apt-get) _cc_pkg_run "$manager" install -y "$@" ;;
        dnf|yum) _cc_pkg_run "$manager" install -y "$@" ;;
        zypper) _cc_pkg_run "$manager" install -y "$@" ;;
        pacman) _cc_pkg_run "$manager" -S --noconfirm "$@" ;;
        pkg) _cc_pkg_run "$manager" install -y "$@" ;;
        *) printf '[CC ERROR] Unsupported package manager: %s\n' "$manager" >&2; return 1 ;;
    esac
}

_cc_pkg_remove() {
    [ "$#" -gt 0 ] || return 0
    local family manager
    family="$(_cc_pkg_family)" || return 1
    manager="$(_cc_pkg_manager)" || return 1
    case "$family" in
        apt-get) _cc_pkg_run "$manager" remove -y "$@" ;;
        dnf|yum) _cc_pkg_run "$manager" remove -y "$@" ;;
        zypper) _cc_pkg_run "$manager" remove -y "$@" ;;
        pacman) _cc_pkg_run "$manager" -R --noconfirm "$@" ;;
        pkg) _cc_pkg_run "$manager" delete -y "$@" ;;
        *) printf '[CC ERROR] Unsupported package manager: %s\n' "$manager" >&2; return 1 ;;
    esac
}

_cc_pkg_purge() {
    [ "$#" -gt 0 ] || return 0
    local family manager
    family="$(_cc_pkg_family)" || return 1
    manager="$(_cc_pkg_manager)" || return 1
    case "$family" in
        apt-get) _cc_pkg_run "$manager" purge -y "$@" ;;
        *) _cc_pkg_remove "$@" ;;
    esac
}

_cc_pkg_autoremove() {
    local family manager
    family="$(_cc_pkg_family)" || return 1
    manager="$(_cc_pkg_manager)" || return 1
    case "$family" in
        apt-get) _cc_pkg_run "$manager" autoremove --purge -y ;;
        dnf) _cc_pkg_run "$manager" autoremove -y ;;
        yum) _cc_pkg_run "$manager" autoremove -y ;;
        zypper|pacman) return 0 ;;
        pkg) _cc_pkg_run "$manager" autoremove -y ;;
        *) printf '[CC ERROR] Unsupported package manager: %s\n' "$manager" >&2; return 1 ;;
    esac
}

_cc_pkg_clean() {
    local family manager
    family="$(_cc_pkg_family)" || return 1
    manager="$(_cc_pkg_manager)" || return 1
    case "$family" in
        apt-get) _cc_pkg_run "$manager" autoclean ;;
        dnf|yum) _cc_pkg_run "$manager" clean all ;;
        zypper) _cc_pkg_run "$manager" clean ;;
        pacman) _cc_pkg_run "$manager" -Sc --noconfirm ;;
        pkg) _cc_pkg_run "$manager" clean -y ;;
        *) printf '[CC ERROR] Unsupported package manager: %s\n' "$manager" >&2; return 1 ;;
    esac
}

_cc_pkg_is_installed() {
    [ "$#" -eq 1 ] || return 2
    local family database
    family="$(_cc_pkg_family)" || return 1
    case "$family" in
        apt-get)
            database="$(_cc_pkg_database_program)" || return 1
            "$database" -s "$1" 2>/dev/null |
                awk '$0 == "Status: install ok installed" {found=1} END {exit !found}'
            ;;
        dnf|yum) rpm -q "$1" >/dev/null 2>&1 ;;
        zypper) rpm -q "$1" >/dev/null 2>&1 ;;
        pacman) pacman -Q "$1" >/dev/null 2>&1 ;;
        pkg) pkg info -e "$1" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

_cc_pkg_is_available() {
    [ "$#" -eq 1 ] || return 2
    local family query
    family="$(_cc_pkg_family)" || return 1
    case "$family" in
        apt-get)
            query="$(_cc_pkg_query_program)" || return 1
            "$query" show "$1" >/dev/null 2>&1
            ;;
        dnf) dnf -q list --available "$1" >/dev/null 2>&1 ;;
        yum) yum -q list available "$1" >/dev/null 2>&1 ;;
        zypper) zypper --non-interactive search --match-exact "$1" >/dev/null 2>&1 ;;
        pacman) pacman -Si "$1" >/dev/null 2>&1 ;;
        pkg) pkg search -e "$1" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

_cc_pkg_find_removable_matching() {
    [ "$#" -eq 1 ] || return 2
    local family database
    family="$(_cc_pkg_family)" || return 1
    case "$family" in
        apt-get)
            database="$(_cc_pkg_database_program)" || return 1
            "$database" -l 2>/dev/null |
                awk -v pattern="$1" '$1 ~ /^(ii|rc)$/ && $2 ~ pattern {print $2}'
            ;;
        dnf|yum|zypper) rpm -qa | awk -v pattern="$1" '$0 ~ pattern {print}' ;;
        pacman) pacman -Qq | awk -v pattern="$1" '$0 ~ pattern {print}' ;;
        pkg) pkg query '%n' | awk -v pattern="$1" '$0 ~ pattern {print}' ;;
        *) return 1 ;;
    esac
}

_cc_pkg_list_installed() {
    local family database
    family="$(_cc_pkg_family)" || return 1
    case "$family" in
        apt-get)
            database="$(_cc_pkg_database_program)" || return 1
            "$database" -l 2>/dev/null |
                awk '$1 == "ii" {print $2}'
            ;;
        dnf|yum|zypper) rpm -qa | sort ;;
        pacman) pacman -Qq ;;
        pkg) pkg query '%n' ;;
        *) return 1 ;;
    esac
}
