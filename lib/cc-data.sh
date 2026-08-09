#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-data.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash command mktemp cp mv rm
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Provide semantic JSON and YAML processing operations.
# ==============================================================================

# Single-quoted jq/yq programs must reach the configured processor literally.
# shellcheck disable=SC2016

if [ -z "${CC_DATA_LOADED:-}" ]; then
    _cc_data_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_data_lib_dir/cc-programs.sh"
    unset _cc_data_lib_dir
    CC_DATA_LOADED=1
fi

_cc_json_program() {
    cc_program_get json
}

_cc_yaml_program() {
    cc_program_get yaml
}

_cc_json_available() {
    [ "$(cc_program_status json)" = "OK" ]
}

_cc_yaml_available() {
    [ "$(cc_program_status yaml)" = "OK" ]
}

_cc_json_validate() {
    [ "$#" -le 1 ] || return 2
    local program
    program="$(_cc_json_program)" || return 1
    if [ "$#" -eq 1 ]; then
        "$program" empty -- "$1" >/dev/null 2>&1
    else
        "$program" empty >/dev/null 2>&1
    fi
}

_cc_json_query() {
    [ "$#" -ge 1 ] && [ "$#" -le 2 ] || return 2
    local program expression="$1"
    program="$(_cc_json_program)" || return 1
    if [ "$#" -eq 2 ]; then
        "$program" -- "$expression" "$2"
    else
        "$program" -- "$expression"
    fi
}

_cc_json_query_raw() {
    [ "$#" -ge 1 ] && [ "$#" -le 2 ] || return 2
    local program expression="$1"
    program="$(_cc_json_program)" || return 1
    if [ "$#" -eq 2 ]; then
        "$program" --raw-output -- "$expression" "$2"
    else
        "$program" --raw-output -- "$expression"
    fi
}

_cc_json_generate() {
    [ "$#" -ge 1 ] || return 2
    local program expression="$1"
    shift
    program="$(_cc_json_program)" || return 1
    "$program" --null-input "$@" -- "$expression"
}

_cc_yaml_validate() {
    [ "$#" -le 1 ] || return 2
    local program
    program="$(_cc_yaml_program)" || return 1
    if [ "$#" -eq 1 ]; then
        "$program" '.' -- "$1" >/dev/null 2>&1
    else
        "$program" '.' >/dev/null 2>&1
    fi
}

_cc_yaml_query() {
    [ "$#" -ge 1 ] && [ "$#" -le 2 ] || return 2
    local program expression="$1"
    program="$(_cc_yaml_program)" || return 1
    if [ "$#" -eq 2 ]; then
        "$program" -- "$expression" "$2"
    else
        "$program" -- "$expression"
    fi
}

_cc_yaml_query_raw() {
    [ "$#" -ge 1 ] && [ "$#" -le 2 ] || return 2
    local program expression="$1"
    program="$(_cc_yaml_program)" || return 1
    if [ "$#" -eq 2 ]; then
        "$program" --raw-output -- "$expression" "$2"
    else
        "$program" --raw-output -- "$expression"
    fi
}

_cc_data_atomic_output() {
    [ "$#" -ge 2 ] || return 2
    local destination="$1" temporary status
    shift
    temporary="$(mktemp "${destination}.tmp.XXXXXX")" || return 1
    if [ -f "$destination" ]; then
        cp -p "$destination" "$temporary" || {
            rm -f "$temporary"
            return 1
        }
    fi
    if "$@" > "$temporary"; then
        mv "$temporary" "$destination"
    else
        status=$?
        rm -f "$temporary"
        return "$status"
    fi
}

_cc_yaml_write_map() {
    [ "$#" -ge 1 ] || return 2
    local destination="$1" program
    shift
    [ $(( $# % 2 )) -eq 0 ] || return 2
    program="$(_cc_yaml_program)" || return 1
    _cc_data_atomic_output "$destination" \
        "$program" \
        --null-input \
        --yaml-output \
        --yaml-output-grammar-version 1.1 \
        --args \
        '$ARGS.positional as $items | reduce range(0; $items | length; 2) as $index ({}; .[$items[$index]] = $items[$index + 1])' \
        "$@" </dev/null
}

_cc_yaml_get_string() {
    [ "$#" -eq 2 ] || return 2
    local file="$1" key="$2" program
    program="$(_cc_yaml_program)" || return 1
    "$program" --raw-output --arg cc_key "$key" '.[$cc_key] // empty' -- "$file"
}

_cc_yaml_get_nested_string() {
    [ "$#" -eq 3 ] || return 2
    local file="$1" section="$2" key="$3" program
    program="$(_cc_yaml_program)" || return 1
    "$program" \
        --raw-output \
        --arg cc_section "$section" \
        --arg cc_key "$key" \
        '.[$cc_section][$cc_key] // empty' \
        -- "$file"
}

_cc_yaml_set_string() {
    [ "$#" -eq 3 ] || return 2
    local file="$1" key="$2" value="$3" program
    program="$(_cc_yaml_program)" || return 1
    _cc_data_atomic_output "$file" \
        "$program" \
        --yaml-roundtrip \
        --yaml-output-grammar-version 1.1 \
        --arg cc_key "$key" \
        --arg cc_value "$value" \
        '.[$cc_key] = $cc_value' \
        -- "$file"
}

_cc_yaml_set_nested_string() {
    [ "$#" -eq 4 ] || return 2
    local file="$1" section="$2" key="$3" value="$4" program
    program="$(_cc_yaml_program)" || return 1
    _cc_data_atomic_output "$file" \
        "$program" \
        --yaml-roundtrip \
        --yaml-output-grammar-version 1.1 \
        --arg cc_section "$section" \
        --arg cc_key "$key" \
        --arg cc_value "$value" \
        '.[$cc_section][$cc_key] = $cc_value' \
        -- "$file"
}
