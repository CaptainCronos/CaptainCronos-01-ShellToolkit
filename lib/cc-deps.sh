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

cc_dep_check_list() {
    local missing=0 dep status
    for dep in "$@"; do
        status="$(cc_dep_status "$dep")"
        if [ "$status" = "present" ]; then
            printf '%-18s %s\n' "$dep" "PASS"
        else
            printf '%-18s %s\n' "$dep" "MISSING"
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
    printf '%s\n' curl wget jq tree bat flatpak snap gh systemctl
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
