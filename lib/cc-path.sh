#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-path.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash stat mv chmod cmp
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Own managed PATH inspection, startup normalization, and repair.
# ==============================================================================

if [ -z "${CC_TEMP_LOADED:-}" ]; then
    _cc_path_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_path_lib_dir/cc-temp.sh"
    unset _cc_path_lib_dir
fi

CC_PATH_BLOCK_BEGIN="# Captain Cronos managed PATH: begin"
CC_PATH_BLOCK_END="# Captain Cronos managed PATH: end"

cc_path_count_entry() {
    [ "$#" -eq 2 ] || return 2
    local path_value="$1" needle="$2" remaining entry more count=0
    remaining="$path_value"
    while :; do
        if [[ "$remaining" == *:* ]]; then
            entry="${remaining%%:*}"
            remaining="${remaining#*:}"
            more=1
        else
            entry="$remaining"
            more=0
        fi
        [ "$entry" != "$needle" ] || count=$((count + 1))
        [ "$more" -eq 1 ] || break
    done
    printf '%s\n' "$count"
}

cc_path_deduplicated() {
    [ "$#" -eq 1 ] || return 2
    local path_value="$1" remaining entry more output="" separator=""
    local -A seen=()
    remaining="$path_value"
    while :; do
        if [[ "$remaining" == *:* ]]; then
            entry="${remaining%%:*}"
            remaining="${remaining#*:}"
            more=1
        else
            entry="$remaining"
            more=0
        fi
        if [ -n "$entry" ] && [ -z "${seen["$entry"]:-}" ]; then
            output+="${separator}${entry}"
            separator=:
            seen["$entry"]=1
        fi
        [ "$more" -eq 1 ] || break
    done
    printf '%s\n' "$output"
}

cc_path_managed_block() {
    cat <<'EOF_PATH_BLOCK'
# Captain Cronos managed PATH: begin
_cc_path_normalize_managed() {
    local _cc_path_remaining="${PATH:-}" _cc_path_entry _cc_path_output=""
    local _cc_path_separator="" _cc_path_more _cc_path_keep
    local _cc_path_home_bin_seen=0 _cc_path_local_bin_seen=0

    while :; do
        if [[ "$_cc_path_remaining" == *:* ]]; then
            _cc_path_entry="${_cc_path_remaining%%:*}"
            _cc_path_remaining="${_cc_path_remaining#*:}"
            _cc_path_more=1
        else
            _cc_path_entry="$_cc_path_remaining"
            _cc_path_more=0
        fi
        _cc_path_keep=1
        case "$_cc_path_entry" in
            "$HOME/bin")
                [ "$_cc_path_home_bin_seen" -eq 0 ] || _cc_path_keep=0
                _cc_path_home_bin_seen=1
                ;;
            "$HOME/.local/bin")
                [ "$_cc_path_local_bin_seen" -eq 0 ] || _cc_path_keep=0
                _cc_path_local_bin_seen=1
                ;;
        esac
        if [ "$_cc_path_keep" -eq 1 ]; then
            _cc_path_output+="${_cc_path_separator}${_cc_path_entry}"
            _cc_path_separator=:
        fi
        [ "$_cc_path_more" -eq 1 ] || break
    done

    if [ "$_cc_path_home_bin_seen" -eq 0 ]; then
        _cc_path_output="$HOME/bin${_cc_path_separator}${_cc_path_output}"
        _cc_path_separator=:
    fi
    if [ "$_cc_path_local_bin_seen" -eq 0 ]; then
        _cc_path_output="$HOME/.local/bin${_cc_path_separator}${_cc_path_output}"
    fi
    export PATH="$_cc_path_output"
}
_cc_path_normalize_managed
unset -f _cc_path_normalize_managed
# Captain Cronos managed PATH: end
EOF_PATH_BLOCK
}

_cc_path_normalize_space() {
    [ "$#" -eq 1 ] || return 2
    local value="$1" double_space="  "
    value="${value//$'\t'/ }"
    while [[ "$value" == *"$double_space"* ]]; do value="${value//$double_space/ }"; done
    while [[ "$value" == " "* ]]; do value="${value# }"; done
    while [[ "$value" == *" " ]]; do value="${value% }"; done
    printf '%s\n' "$value"
}

# Stored shell syntax is deliberately matched as literal data.
# shellcheck disable=SC2016
_cc_path_is_legacy_line() {
    [ "$#" -eq 1 ] || return 2
    local line condition candidate reference path_suffix
    local -a references=()
    line="$(_cc_path_normalize_space "$1")"

    for path_suffix in bin .local/bin; do
        references=("\$HOME/$path_suffix" "\${HOME}/$path_suffix" "$HOME/$path_suffix")
        for reference in "${references[@]}"; do
            for condition in "[ -d \"$reference\" ]" "[ -d $reference ]" \
                "test -d \"$reference\"" "test -d $reference"; do
                printf -v candidate '%s && export PATH="%s:$PATH"' "$condition" "$reference"
                [ "$line" != "$candidate" ] || return 0
                printf -v candidate '%s && export PATH="%s:${PATH}"' "$condition" "$reference"
                [ "$line" != "$candidate" ] || return 0
                printf -v candidate '%s && export PATH=%s:$PATH' "$condition" "$reference"
                [ "$line" != "$candidate" ] || return 0
                printf -v candidate '%s && export PATH=%s:${PATH}' "$condition" "$reference"
                [ "$line" != "$candidate" ] || return 0
            done
        done
    done
    return 1
}

# shellcheck disable=SC2016
_cc_path_legacy_guard_length() {
    [ "$#" -eq 2 ] || return 2
    local array_name="$1" index="$2" marker label suffix dir reference
    local -n lines_ref="$array_name"
    [ "$((index + 4))" -lt "${#lines_ref[@]}" ] || return 1
    marker="${lines_ref[$index]}"
    case "$marker" in
        '# Captain Cronos PATH guard: home bin') label="home bin"; suffix=bin ;;
        '# Captain Cronos PATH guard: local bin') label="local bin"; suffix=.local/bin ;;
        *) return 1 ;;
    esac
    [ "${lines_ref[$index]}" = "# Captain Cronos PATH guard: $label" ] || return 1
    [ "$(_cc_path_normalize_space "${lines_ref[$((index + 1))]}")" = 'case ":$PATH:" in' ] || return 1
    for dir in "$HOME/$suffix" "\$HOME/$suffix" "\${HOME}/$suffix"; do
        printf -v reference '*":%s:"*) ;;' "$dir"
        [ "$(_cc_path_normalize_space "${lines_ref[$((index + 2))]}")" != "$reference" ] || {
            printf -v reference '*) export PATH="%s:$PATH" ;;' "$dir"
            [ "$(_cc_path_normalize_space "${lines_ref[$((index + 3))]}")" = "$reference" ] || return 1
            [ "$(_cc_path_normalize_space "${lines_ref[$((index + 4))]}")" = "esac" ] || return 1
            printf '5\n'
            return 0
        }
    done
    return 1
}

# shellcheck disable=SC2016
_cc_path_line_mentions_managed_assignment() {
    [ "$#" -eq 1 ] || return 2
    local line="$1"
    [[ "$line" == *PATH=* || "$line" == *"export PATH"* ]] || return 1
    [[ "$line" == *'$HOME/bin'* || "$line" == *'${HOME}/bin'* ||
        "$line" == *'$HOME/.local/bin'* || "$line" == *'${HOME}/.local/bin'* ||
        "$line" == *"$HOME/bin"* || "$line" == *"$HOME/.local/bin"* ]]
}

cc_path_startup_audit() {
    [ "$#" -eq 1 ] || return 2
    local file="$1" index=0 skip=0 in_canonical=0 guard_length
    local -a lines=()
    CC_PATH_CANONICAL_BLOCKS=0
    CC_PATH_CANONICAL_ENDS=0
    CC_PATH_CANONICAL_MALFORMED=0
    CC_PATH_LEGACY_LINES=0
    CC_PATH_LEGACY_GUARDS=0
    CC_PATH_AMBIGUOUS_LINES=0
    [ -e "$file" ] || return 0
    [ -f "$file" ] && [ ! -L "$file" ] || return 2
    mapfile -t lines < "$file"

    while [ "$index" -lt "${#lines[@]}" ]; do
        if [ "$skip" -gt 0 ]; then
            skip=$((skip - 1))
            index=$((index + 1))
            continue
        fi
        if [ "${lines[$index]}" = "$CC_PATH_BLOCK_BEGIN" ]; then
            [ "$in_canonical" -eq 0 ] || CC_PATH_CANONICAL_MALFORMED=1
            CC_PATH_CANONICAL_BLOCKS=$((CC_PATH_CANONICAL_BLOCKS + 1))
            in_canonical=1
            index=$((index + 1))
            continue
        fi
        if [ "${lines[$index]}" = "$CC_PATH_BLOCK_END" ]; then
            [ "$in_canonical" -eq 1 ] || CC_PATH_CANONICAL_MALFORMED=1
            CC_PATH_CANONICAL_ENDS=$((CC_PATH_CANONICAL_ENDS + 1))
            in_canonical=0
            index=$((index + 1))
            continue
        fi
        if [ "$in_canonical" -eq 1 ]; then
            index=$((index + 1))
            continue
        fi
        if guard_length="$(_cc_path_legacy_guard_length lines "$index" 2>/dev/null)"; then
            CC_PATH_LEGACY_GUARDS=$((CC_PATH_LEGACY_GUARDS + 1))
            skip=$((guard_length - 1))
        elif _cc_path_is_legacy_line "${lines[$index]}"; then
            CC_PATH_LEGACY_LINES=$((CC_PATH_LEGACY_LINES + 1))
        elif _cc_path_line_mentions_managed_assignment "${lines[$index]}"; then
            CC_PATH_AMBIGUOUS_LINES=$((CC_PATH_AMBIGUOUS_LINES + 1))
        fi
        index=$((index + 1))
    done
    [ "$in_canonical" -eq 0 ] || CC_PATH_CANONICAL_MALFORMED=1
}

cc_path_repair_bashrc() {
    [ "$#" -eq 1 ] || return 2
    local file="$1" parent temporary="" status=0 identity="" current_identity=""
    local index=0 skip=0 in_canonical=0 guard_length line
    local -a lines=() output=()

    parent="$(dirname "$file")"
    [ -d "$parent" ] && [ ! -L "$file" ] || {
        printf '[CC ERROR] Refusing unsafe shell startup target: %s\n' "$file" >&2
        return 1
    }
    if [ -e "$file" ]; then
        [ -f "$file" ] || {
            printf '[CC ERROR] Shell startup target is not a regular file: %s\n' "$file" >&2
            return 1
        }
        identity="$(stat -c '%d:%i' -- "$file")" || return 1
        mapfile -t lines < "$file"
    fi
    cc_path_startup_audit "$file" || return
    if [ "$CC_PATH_CANONICAL_BLOCKS" -ne "$CC_PATH_CANONICAL_ENDS" ] ||
        [ "$CC_PATH_CANONICAL_MALFORMED" -ne 0 ]; then
        printf '[CC ERROR] Refusing malformed Captain Cronos PATH block in %s\n' "$file" >&2
        return 1
    fi

    while [ "$index" -lt "${#lines[@]}" ]; do
        line="${lines[$index]}"
        if [ "$in_canonical" -eq 1 ]; then
            if [ "$line" = "$CC_PATH_BLOCK_END" ]; then in_canonical=0; fi
            index=$((index + 1))
            continue
        fi
        if [ "$line" = "$CC_PATH_BLOCK_BEGIN" ]; then
            in_canonical=1
            [ "${#output[@]}" -eq 0 ] || [ -n "${output[-1]}" ] || unset 'output[-1]'
            index=$((index + 1))
            continue
        fi
        if guard_length="$(_cc_path_legacy_guard_length lines "$index" 2>/dev/null)"; then
            [ "${#output[@]}" -eq 0 ] || [ -n "${output[-1]}" ] || unset 'output[-1]'
            index=$((index + guard_length))
            continue
        fi
        if _cc_path_is_legacy_line "$line"; then
            index=$((index + 1))
            continue
        fi
        output+=("$line")
        index=$((index + 1))
    done

    cc_temp_file temporary "$parent/.cc-path-bashrc.XXXXXX" || return 1
    if [ -e "$file" ]; then
        chmod --reference="$file" "$temporary" || status=$?
    else
        chmod 0644 "$temporary" || status=$?
    fi
    if [ "$status" -eq 0 ]; then
        {
            for line in "${output[@]}"; do printf '%s\n' "$line"; done
            [ "${#output[@]}" -eq 0 ] || [ -z "${output[-1]}" ] || printf '\n'
            cc_path_managed_block
        } > "$temporary" || status=$?
    fi
    if [ "$status" -eq 0 ]; then
        if [ -n "$identity" ]; then
            current_identity="$(stat -c '%d:%i' -- "$file" 2>/dev/null || true)"
            [ "$current_identity" = "$identity" ] || status=1
        elif [ -e "$file" ] || [ -L "$file" ]; then
            status=1
        fi
    fi
    if [ "$status" -eq 0 ] && [ -n "$identity" ] && cmp -s "$temporary" "$file"; then
        cc_temp_remove "$temporary"
        return 0
    fi
    if [ "$status" -eq 0 ]; then
        if mv -f -- "$temporary" "$file"; then
            cc_temp_unregister "$temporary"
            return 0
        else
            status=$?
        fi
    fi
    cc_temp_remove "$temporary" || :
    printf '[CC ERROR] PATH startup repair failed without replacing %s\n' "$file" >&2
    [ "$status" -ne 0 ] || status=1
    return "$status"
}
