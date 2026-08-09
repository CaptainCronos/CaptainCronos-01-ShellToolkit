#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-programs.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash command
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Resolve and validate preferred command-line program interfaces.
# ==============================================================================

CC_PROGRAMS_LOADED=0

cc_program_config_file() {
    if [ -n "${CC_PROGRAMS_CONFIG:-}" ]; then
        printf '%s\n' "$CC_PROGRAMS_CONFIG"
        return 0
    fi

    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    printf '%s/config/programs.conf\n' "${TOOLKIT_ROOT:-${PROJECT_ROOT:-${lib_dir}/..}}"
}

_cc_program_metadata() {
    cat <<'EOF_PROGRAMS'
Package Management|pkg-manager|Operations|CC_PKG_MANAGER|required
Package Management|pkg-query|Queries|CC_PKG_QUERY|required
Package Management|pkg-database|Database|CC_PKG_DATABASE|required
Networking|network|Network|CC_NETWORK|required
Networking|sockets|Sockets|CC_SOCKETS|required
HTTP|download|Downloads|CC_DOWNLOAD|required
HTTP|http-api|API Client|CC_HTTP_API|required
Services|service-manager|Manager|CC_SERVICE_MANAGER|required
Services|system-log|Logs|CC_SYSTEM_LOG|required
Data|json|JSON|CC_JSON|optional
Data|yaml|YAML|CC_YAML|optional
Files|sync|Sync|CC_SYNC|optional
Files|archive|Archive|CC_ARCHIVE|required
EOF_PROGRAMS
}

_cc_program_variable() {
    local capability="$1" row _section _label _variable _requirement
    while IFS='|' read -r _section row _label _variable _requirement; do
        if [ "$row" = "$capability" ]; then
            printf '%s\n' "$_variable"
            return 0
        fi
    done < <(_cc_program_metadata)
    return 1
}

_cc_program_known_variable() {
    local candidate="$1" variable _section _capability _label _requirement
    while IFS='|' read -r _section _capability _label variable _requirement; do
        [ "$variable" = "$candidate" ] && return 0
    done < <(_cc_program_metadata)
    return 1
}

cc_program_load() {
    local config line key value line_number=0
    local capability _section _label _requirement
    config="${1:-$(cc_program_config_file)}"
    CC_PROGRAMS_LOADED=0

    if [ ! -f "$config" ]; then
        printf '[CC ERROR] Missing program configuration: %s\n' "$config" >&2
        return 1
    fi

    while IFS='|' read -r _section _capability _label key _requirement; do
        printf -v "$key" '%s' ''
    done < <(_cc_program_metadata)

    while IFS= read -r line || [ -n "$line" ]; do
        line_number=$((line_number + 1))
        case "$line" in
            ''|'#'*) continue ;;
        esac

        if [[ "$line" =~ ^(CC_[A-Z0-9_]+)=\"([A-Za-z0-9][A-Za-z0-9._+-]*)\"$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
        else
            printf '[CC ERROR] Invalid program configuration at %s:%s\n' "$config" "$line_number" >&2
            return 1
        fi

        if ! _cc_program_known_variable "$key"; then
            printf '[CC ERROR] Unknown program setting at %s:%s: %s\n' "$config" "$line_number" "$key" >&2
            return 1
        fi
        if [ -n "${!key:-}" ]; then
            printf '[CC ERROR] Duplicate program setting at %s:%s: %s\n' "$config" "$line_number" "$key" >&2
            return 1
        fi
        printf -v "$key" '%s' "$value"
    done < "$config"

    while IFS='|' read -r _section capability _label key _requirement; do
        if [ -z "${!key:-}" ]; then
            printf '[CC ERROR] Missing program setting for capability: %s\n' "$capability" >&2
            return 1
        fi
    done < <(_cc_program_metadata)

    CC_PROGRAMS_LOADED=1
}

cc_program_capabilities() {
    local _section capability _label _variable _requirement
    while IFS='|' read -r _section capability _label _variable _requirement; do
        printf '%s\n' "$capability"
    done < <(_cc_program_metadata)
}

cc_program_get() {
    local capability="$1" variable
    [ "$CC_PROGRAMS_LOADED" -eq 1 ] || cc_program_load || return 1
    if ! variable="$(_cc_program_variable "$capability")"; then
        printf '[CC ERROR] Unknown program capability: %s\n' "$capability" >&2
        return 1
    fi
    printf '%s\n' "${!variable}"
}

cc_program_exists() {
    local program
    program="$(cc_program_get "$1")" || return 1
    command -v "$program" >/dev/null 2>&1
}

cc_program_status() {
    if cc_program_exists "$1"; then
        printf '%s\n' "OK"
    else
        printf '%s\n' "MISSING"
    fi
}

cc_program_requirement() {
    local capability="$1" row requirement _section _label _variable
    while IFS='|' read -r _section row _label _variable requirement; do
        if [ "$row" = "$capability" ]; then
            printf '%s\n' "$requirement"
            return 0
        fi
    done < <(_cc_program_metadata)
    printf '[CC ERROR] Unknown program capability: %s\n' "$capability" >&2
    return 1
}

cc_program_missing() {
    local capability program requirement
    [ "$CC_PROGRAMS_LOADED" -eq 1 ] || cc_program_load || return 1
    while IFS= read -r capability; do
        [ -n "$capability" ] || continue
        cc_program_exists "$capability" && continue
        program="$(cc_program_get "$capability")"
        requirement="$(cc_program_requirement "$capability")"
        printf '%s\t%s\t%s\n' "$capability" "$program" "$requirement"
    done < <(cc_program_capabilities)
}

cc_program_validate() {
    local capability requirement missing_required=0 missing_optional=0
    cc_program_load "${1:-$(cc_program_config_file)}" || return 2

    while IFS= read -r capability; do
        [ -n "$capability" ] || continue
        if ! cc_program_exists "$capability"; then
            requirement="$(cc_program_requirement "$capability")"
            if [ "$requirement" = "required" ]; then
                missing_required=$((missing_required + 1))
            else
                missing_optional=$((missing_optional + 1))
            fi
        fi
    done < <(cc_program_capabilities)

    CC_PROGRAMS_MISSING_REQUIRED="$missing_required"
    CC_PROGRAMS_MISSING_OPTIONAL="$missing_optional"
    export CC_PROGRAMS_MISSING_REQUIRED CC_PROGRAMS_MISSING_OPTIONAL
    [ "$missing_required" -eq 0 ]
}
