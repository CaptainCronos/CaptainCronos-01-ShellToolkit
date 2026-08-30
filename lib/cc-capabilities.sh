#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-capabilities.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash sort
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Resolve core, program, and plugin-provided host capabilities.
# ==============================================================================

if ! declare -F cc_platform_capability_exists >/dev/null 2>&1; then
    _cc_capabilities_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_capabilities_lib_dir/cc-platform.sh"
    unset _cc_capabilities_lib_dir
fi
if ! declare -F cc_plugin_inventory_tsv >/dev/null 2>&1; then
    _cc_capabilities_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_capabilities_lib_dir/cc-plugins.sh"
    unset _cc_capabilities_lib_dir
fi

cc_capability_result() {
    local capability="$1" status plugin_cap plugin_id plugin_state _origin reason
    local selected_id="" selected_state="" selected_reason="" selected_priority=0 priority=0
    if cc_program_is_capability "$capability"; then
        status="$(cc_program_status "$capability")"
        case "$status" in
            OK) printf 'available\tPASS\tcore/program\tconfigured provider is available\n' ;;
            MISSING) printf 'missing-dependency\tFAIL\tcore/program\tconfigured provider is missing\n' ;;
            *) printf 'unavailable\tFAIL\tcore/program\tconfigured provider is incompatible\n' ;;
        esac
        return
    fi
    if cc_platform_capability_known "$capability"; then
        if cc_platform_capability_exists "$capability"; then
            printf 'available\tPASS\tcore/platform\tdetected on this host\n'
        else
            printf 'unavailable\tFAIL\tcore/platform\tnot detected on this host\n'
        fi
        return
    fi
    while IFS=$'\t' read -r plugin_cap plugin_id plugin_state _origin reason; do
        [ -n "$plugin_cap" ] || continue
        case "$plugin_state:$reason" in
            PASS:*|WARN:*) priority=4 ;;
            FAIL:*) priority=3 ;;
            SKIP:disabled*) priority=2 ;;
            *) priority=1 ;;
        esac
        if [ "$priority" -gt "$selected_priority" ]; then
            selected_priority="$priority" selected_id="$plugin_id"
            selected_state="$plugin_state" selected_reason="$reason"
        fi
    done < <(cc_plugin_capability_tsv "$capability")
    if [ -z "$selected_id" ]; then
        printf 'unavailable\tFAIL\tnone\tunknown capability\n'
        return
    fi
    case "$selected_state" in
        PASS) printf 'available\tPASS\tplugin/%s\t%s\n' "$selected_id" "$selected_reason" ;;
        WARN) printf 'available\tWARN\tplugin/%s\t%s\n' "$selected_id" "$selected_reason" ;;
        SKIP)
            case "$selected_reason" in
                disabled*) printf 'disabled\tSKIP\tplugin/%s\t%s\n' "$selected_id" "$selected_reason" ;;
                *) printf 'unsupported\tSKIP\tplugin/%s\t%s\n' "$selected_id" "$selected_reason" ;;
            esac
            ;;
        FAIL)
            case "$selected_reason" in
                missing\ required\ dependency:*) printf 'missing-dependency\tFAIL\tplugin/%s\t%s\n' "$selected_id" "$selected_reason" ;;
                *) printf 'unavailable\tFAIL\tplugin/%s\t%s\n' "$selected_id" "$selected_reason" ;;
            esac
            ;;
    esac
}

cc_capability_exists() {
    local semantic _rest
    IFS=$'\t' read -r semantic _rest < <(cc_capability_result "$1")
    [ "$semantic" = available ]
}

cc_capability_status() {
    local semantic _result _provider _detail
    IFS=$'\t' read -r semantic _result _provider _detail < <(cc_capability_result "$1")
    printf '%s\n' "$semantic"
}

cc_capability_list() {
    {
        cc_platform_capability_list
        cc_program_capabilities
        cc_plugin_capability_tsv | cut -f1
    } | LC_ALL=C sort -u
}
