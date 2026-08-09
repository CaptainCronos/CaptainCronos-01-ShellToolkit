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
Data|yaml|YAML|CC_YAML|required
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

cc_program_is_capability() {
    [ "$#" -eq 1 ] || return 2
    _cc_program_variable "$1" >/dev/null 2>&1
}

cc_program_get() {
    local capability="$1" variable implementation
    [ "$CC_PROGRAMS_LOADED" -eq 1 ] || cc_program_load || return 1
    if ! variable="$(_cc_program_variable "$capability")"; then
        printf '[CC ERROR] Unknown program capability: %s\n' "$capability" >&2
        return 1
    fi
    implementation="${!variable}"
    if declare -F cc_debug_kv >/dev/null 2>&1; then
        cc_debug_kv "capability requested" "$capability"
        cc_debug_kv "capability resolver" "Program Management"
        cc_debug_kv "program configuration" "$(cc_program_config_file)"
        cc_debug_kv "configured implementation" "$implementation"
    fi
    printf '%s\n' "$implementation"
}

cc_program_exists() {
    local program
    program="$(cc_program_get "$1")" || return 1
    command -v "$program" >/dev/null 2>&1
}

_cc_program_compatibility_json() {
    local program="$1" output
    output="$(
        printf '%s\n' '{"captain":"cronos"}' |
            "$program" --exit-status --raw-output '.captain' 2>/dev/null
    )" || return 1
    [ "$output" = "cronos" ]
}

_cc_program_compatibility_yaml() {
    local program="$1" version output transform_filter validation_filter
    version="$("$program" --version 2>&1)" || return 1
    case "$version" in
        yq\ [0-9]*) ;;
        *) return 1 ;;
    esac

    # These are yq expressions, not shell expressions.
    # shellcheck disable=SC2016
    transform_filter='.captain = $cc_value | .positional = $ARGS.positional[0]'
    output="$(
        printf '%s\n' 'captain: "cronos"' |
            "$program" \
                --yaml-roundtrip \
                --yaml-output-grammar-version 1.1 \
                --arg cc_value validated \
                --args \
                "$transform_filter" \
                probe 2>/dev/null
    )" || return 1
    # This is a yq expression, not a shell expression.
    # shellcheck disable=SC2016
    validation_filter='.captain == "validated" and .positional == "probe"'
    printf '%s\n' "$output" |
        "$program" --exit-status "$validation_filter" >/dev/null 2>&1
}

cc_program_compatible() {
    local capability="$1" program validator
    cc_program_exists "$capability" || return 1
    program="$(cc_program_get "$capability")" || return 1
    validator="_cc_program_compatibility_${capability//-/_}"
    if declare -F "$validator" >/dev/null 2>&1; then
        "$validator" "$program"
    else
        return 0
    fi
}

cc_program_status() {
    local capability="$1" status
    if ! cc_program_exists "$capability"; then
        status="MISSING"
    elif cc_program_compatible "$capability"; then
        status="OK"
    else
        status="INCOMPATIBLE"
    fi
    if declare -F cc_debug_kv >/dev/null 2>&1; then
        cc_debug_kv "capability status" "$status"
    fi
    printf '%s\n' "$status"
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
    local capability requirement status
    local missing_required=0 missing_optional=0
    local incompatible_required=0 incompatible_optional=0
    cc_program_load "${1:-$(cc_program_config_file)}" || return 2

    while IFS= read -r capability; do
        [ -n "$capability" ] || continue
        status="$(cc_program_status "$capability")"
        [ "$status" = "OK" ] && continue
        requirement="$(cc_program_requirement "$capability")"
        case "$status:$requirement" in
            MISSING:required) missing_required=$((missing_required + 1)) ;;
            MISSING:optional) missing_optional=$((missing_optional + 1)) ;;
            INCOMPATIBLE:required) incompatible_required=$((incompatible_required + 1)) ;;
            INCOMPATIBLE:optional) incompatible_optional=$((incompatible_optional + 1)) ;;
        esac
    done < <(cc_program_capabilities)

    CC_PROGRAMS_MISSING_REQUIRED="$missing_required"
    CC_PROGRAMS_MISSING_OPTIONAL="$missing_optional"
    CC_PROGRAMS_INCOMPATIBLE_REQUIRED="$incompatible_required"
    CC_PROGRAMS_INCOMPATIBLE_OPTIONAL="$incompatible_optional"
    export CC_PROGRAMS_MISSING_REQUIRED CC_PROGRAMS_MISSING_OPTIONAL
    export CC_PROGRAMS_INCOMPATIBLE_REQUIRED CC_PROGRAMS_INCOMPATIBLE_OPTIONAL
    [ "$missing_required" -eq 0 ] && [ "$incompatible_required" -eq 0 ]
}
