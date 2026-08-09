#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-deps.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash command awk
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Shared dependency and capability check helpers.
# ==============================================================================

if ! declare -F cc_program_get >/dev/null 2>&1; then
    _cc_deps_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_deps_lib_dir/cc-programs.sh"
    unset _cc_deps_lib_dir
fi

cc_dep_exists() {
    command -v "$1" >/dev/null 2>&1
}

cc_dep_status() {
    local dep="$1"
    if cc_dep_exists "$dep"; then
        echo "present"
    else
        echo "missing"
    fi
}

cc_dep_is_program_capability() {
    cc_program_is_capability "$1"
}

cc_dep_resolve_program() {
    local resolver="_cc_dep_resolve_${1//-/_}"
    if declare -F "$resolver" >/dev/null 2>&1; then
        "$resolver"
    elif cc_dep_is_program_capability "$1"; then
        cc_program_get "$1"
    else
        printf '%s\n' "$1"
    fi
}

cc_dep_execution_status() {
    local validator="_cc_dep_status_${1//-/_}"
    if declare -F "$validator" >/dev/null 2>&1; then
        "$validator"
    elif cc_dep_is_program_capability "$1"; then
        cc_program_status "$1"
    elif cc_dep_exists "$1"; then
        printf '%s\n' "OK"
    else
        printf '%s\n' "MISSING"
    fi
}

cc_dep_install_hint() {
    cc_dep_is_program_capability "$1" && return 1
    cc_dep_package_hint "$1"
}

cc_dep_check_list() {
    local missing=0 dep status
    for dep in "$@"; do
        status="$(cc_dep_execution_status "$dep")"
        if [ "$status" = "OK" ]; then
            printf '%-18s %s\n' "$dep" "PASS"
        else
            printf '%-18s %s\n' "$dep" "$status"
            missing=$((missing + 1))
        fi
    done
    return "$missing"
}

cc_dep_core_list() {
    printf '%s\n' bash git awk sed grep find sort head tail cut tr date hostname mkdir chmod install cat printf
}

cc_dep_docs_list() {
    printf '%s\n' python3
}

cc_dep_storage_list() {
    printf '%s\n' lsblk df smartctl
}

cc_dep_optional_list() {
    printf '%s\n' tree bat flatpak snap gh
}

cc_dep_package_hint() {
    local dep="$1"
    case "$dep" in
        smartctl) echo "smartmontools" ;;
        git) echo "git" ;;
        python3) echo "python3" ;;
        jq) echo "jq" ;;
        tree) echo "tree" ;;
        bat) echo "bat" ;;
        gh) echo "gh" ;;
        curl) echo "curl" ;;
        wget) echo "wget" ;;
        *) echo "$dep" ;;
    esac
}

cc_dep_missing_from_list() {
    local dep
    for dep in "$@"; do
        if ! cc_dep_exists "$dep"; then
            echo "$dep"
        fi
    done
}
