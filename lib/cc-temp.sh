#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-temp.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash mktemp stat rm
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Own secure temporary resources for one shell invocation.
# ==============================================================================

if [ -z "${CC_TEMP_LOADED:-}" ]; then
    declare -ag CC_TEMP_PATHS=()
    declare -Ag CC_TEMP_KINDS=()
    declare -Ag CC_TEMP_IDENTITIES=()
    CC_TEMP_REGISTRY_PID="${BASHPID:-$$}"
    CC_TEMP_HOOKS_INSTALLED=0
    CC_TEMP_CLEANING=0
    CC_TEMP_CREATION_DEPTH=0
    CC_TEMP_PENDING_SIGNAL=""
    CC_TEMP_PRIOR_EXIT_ACTION=""
    CC_TEMP_PRIOR_INT_ACTION=""
    CC_TEMP_PRIOR_TERM_ACTION=""
    CC_TEMP_PRIOR_INT_SET=0
    CC_TEMP_PRIOR_TERM_SET=0
    CC_TEMP_LOADED=1
fi

_cc_temp_error() {
    printf '[CC TEMP ERROR] %s\n' "$*" >&2
}

_cc_temp_path_safe() {
    [ "$#" -eq 1 ] || return 2
    local path="$1" component remainder
    [ -n "$path" ] || return 1
    [ "$path" != / ] || return 1
    [[ "$path" == /* ]] || return 1

    remainder="${path#/}"
    while :; do
        component="${remainder%%/*}"
        [ "$component" != .. ] || return 1
        [ "$remainder" != "$component" ] || break
        remainder="${remainder#*/}"
    done
}

_cc_temp_identity() {
    [ "$#" -eq 1 ] || return 2
    stat -c '%u:%d:%i' -- "$1" 2>/dev/null
}

_cc_temp_reset_for_process() {
    local current_pid="${BASHPID:-$$}"
    [ "$CC_TEMP_REGISTRY_PID" = "$current_pid" ] && return 0
    CC_TEMP_PATHS=()
    CC_TEMP_KINDS=()
    CC_TEMP_IDENTITIES=()
    CC_TEMP_REGISTRY_PID="$current_pid"
    CC_TEMP_CLEANING=0
}

_cc_temp_capture_trap_action() {
    [ "$#" -ge 2 ] && [ "$#" -le 3 ] || return 2
    local signal="$1" output_name="$2" set_name="${3:-}" specification quoted_action action="" is_set=0
    specification="$(trap -p "$signal")"
    if [ -n "$specification" ]; then
        is_set=1
        quoted_action="${specification#trap -- }"
        quoted_action="${quoted_action% *}"
        eval "action=$quoted_action"
    fi
    printf -v "$output_name" '%s' "$action"
    [ -z "$set_name" ] || printf -v "$set_name" '%s' "$is_set"
}

_cc_temp_run_prior_action() {
    [ "$#" -eq 2 ] || return 2
    local action="$1" original_status="$2" prior_status had_errexit=0
    [ -n "$action" ] || return 0
    [[ $- == *e* ]] && had_errexit=1
    set +e
    (exit "$original_status")
    eval -- "$action"
    prior_status=$?
    [ "$had_errexit" -eq 0 ] || set -e
    return "$prior_status"
}

_cc_temp_on_exit() {
    local original_status="${1:-0}"
    cc_temp_cleanup_all || :
    _cc_temp_run_prior_action "$CC_TEMP_PRIOR_EXIT_ACTION" "$original_status" || :
    exit "$original_status"
}

_cc_temp_on_signal() {
    local signal="$1" signal_status="$2" prior_action=""
    if [ "$CC_TEMP_CREATION_DEPTH" -gt 0 ]; then
        [ -n "$CC_TEMP_PENDING_SIGNAL" ] || CC_TEMP_PENDING_SIGNAL="$signal"
        return 0
    fi
    case "$signal" in
        INT) prior_action="$CC_TEMP_PRIOR_INT_ACTION" ;;
        TERM) prior_action="$CC_TEMP_PRIOR_TERM_ACTION" ;;
        *) return 2 ;;
    esac
    cc_temp_cleanup_all || :
    _cc_temp_run_prior_action "$prior_action" "$signal_status" || :
    trap - "$signal"
    exit "$signal_status"
}

_cc_temp_install_hooks() {
    [ "$CC_TEMP_HOOKS_INSTALLED" -eq 0 ] || return 0
    _cc_temp_capture_trap_action EXIT CC_TEMP_PRIOR_EXIT_ACTION
    _cc_temp_capture_trap_action INT CC_TEMP_PRIOR_INT_ACTION CC_TEMP_PRIOR_INT_SET
    _cc_temp_capture_trap_action TERM CC_TEMP_PRIOR_TERM_ACTION CC_TEMP_PRIOR_TERM_SET
    trap '_cc_temp_on_exit "$?"' EXIT
    if [ "$CC_TEMP_PRIOR_INT_SET" -eq 1 ] && [ -z "$CC_TEMP_PRIOR_INT_ACTION" ]; then
        trap '' INT
    else
        trap '_cc_temp_on_signal INT 130' INT
    fi
    if [ "$CC_TEMP_PRIOR_TERM_SET" -eq 1 ] && [ -z "$CC_TEMP_PRIOR_TERM_ACTION" ]; then
        trap '' TERM
    else
        trap '_cc_temp_on_signal TERM 143' TERM
    fi
    CC_TEMP_HOOKS_INSTALLED=1
}

_cc_temp_creation_begin() {
    _cc_temp_install_hooks || return
    CC_TEMP_CREATION_DEPTH=$((CC_TEMP_CREATION_DEPTH + 1))
}

_cc_temp_creation_end() {
    local pending
    [ "$CC_TEMP_CREATION_DEPTH" -gt 0 ] || return 2
    CC_TEMP_CREATION_DEPTH=$((CC_TEMP_CREATION_DEPTH - 1))
    [ "$CC_TEMP_CREATION_DEPTH" -eq 0 ] || return 0
    pending="$CC_TEMP_PENDING_SIGNAL"
    CC_TEMP_PENDING_SIGNAL=""
    case "$pending" in
        INT) _cc_temp_on_signal INT 130 ;;
        TERM) _cc_temp_on_signal TERM 143 ;;
    esac
}

_cc_temp_register_created() {
    [ "$#" -eq 2 ] || return 2
    local path="$1" kind="$2" identity owner
    _cc_temp_reset_for_process
    _cc_temp_path_safe "$path" || {
        _cc_temp_error "Refusing unsafe temporary path: ${path:-<empty>}"
        return 2
    }
    case "$kind" in
        file) [ -f "$path" ] && [ ! -L "$path" ] || return 2 ;;
        directory) [ -d "$path" ] && [ ! -L "$path" ] || return 2 ;;
        *) return 2 ;;
    esac
    identity="$(_cc_temp_identity "$path")" || return 1
    owner="${identity%%:*}"
    [ "$owner" = "$EUID" ] || {
        _cc_temp_error "Refusing temporary resource owned by uid $owner: $path"
        return 2
    }
    if [ -z "${CC_TEMP_KINDS["$path"]:-}" ]; then
        CC_TEMP_PATHS+=("$path")
    fi
    CC_TEMP_KINDS["$path"]="$kind"
    CC_TEMP_IDENTITIES["$path"]="$identity"
}

_cc_temp_template() {
    [ "$#" -eq 2 ] || return 2
    local template="$1" output_name="$2" directory basename canonical
    [ -n "$template" ] || return 2
    case "$template" in
        */*) directory="${template%/*}"; basename="${template##*/}" ;;
        *) directory=.; basename="$template" ;;
    esac
    [[ "$basename" =~ X{3,} ]] || return 2
    [ "$basename" != . ] && [ "$basename" != .. ] || return 2
    canonical="$(cd -- "$directory" 2>/dev/null && pwd -P)" || return 1
    printf -v "$output_name" '%s/%s' "$canonical" "$basename"
}

cc_temp_file() {
    [ "$#" -ge 1 ] && [ "$#" -le 2 ] || return 2
    local output_name="$1" template path="" canonical_template="" base
    [[ "$output_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 2
    local -n output_ref="$output_name"
    if [ "$#" -eq 2 ]; then
        template="$2"
    else
        base="${TMPDIR:-/tmp}"
        template="${base%/}/cc-temp.XXXXXX"
    fi
    _cc_temp_template "$template" canonical_template || return
    _cc_temp_creation_begin || return
    if path="$(mktemp -- "$canonical_template")"; then
        :
    else
        _cc_temp_creation_end
        return 1
    fi
    if ! _cc_temp_register_created "$path" file; then
        command rm -f -- "$path"
        _cc_temp_creation_end
        return 1
    fi
    _cc_temp_creation_end
    # shellcheck disable=SC2034 # nameref writes the caller-selected variable.
    output_ref="$path"
}

cc_temp_dir() {
    [ "$#" -ge 1 ] && [ "$#" -le 2 ] || return 2
    local output_name="$1" template path="" canonical_template="" base
    [[ "$output_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 2
    local -n output_ref="$output_name"
    if [ "$#" -eq 2 ]; then
        template="$2"
    else
        base="${TMPDIR:-/tmp}"
        template="${base%/}/cc-temp.XXXXXX"
    fi
    _cc_temp_template "$template" canonical_template || return
    _cc_temp_creation_begin || return
    if path="$(mktemp -d -- "$canonical_template")"; then
        :
    else
        _cc_temp_creation_end
        return 1
    fi
    if ! _cc_temp_register_created "$path" directory; then
        command rm -rf -- "$path"
        _cc_temp_creation_end
        return 1
    fi
    _cc_temp_creation_end
    # shellcheck disable=SC2034 # nameref writes the caller-selected variable.
    output_ref="$path"
}

cc_temp_unregister() {
    [ "$#" -eq 1 ] || return 2
    local path="$1"
    _cc_temp_path_safe "$path" || return 2
    unset 'CC_TEMP_KINDS[$path]' 'CC_TEMP_IDENTITIES[$path]'
}

cc_temp_remove() {
    [ "$#" -eq 1 ] || return 2
    local path="$1" kind identity current_identity
    _cc_temp_path_safe "$path" || return 2
    kind="${CC_TEMP_KINDS["$path"]:-}"
    [ -n "$kind" ] || return 0
    identity="${CC_TEMP_IDENTITIES["$path"]:-}"
    unset 'CC_TEMP_KINDS[$path]' 'CC_TEMP_IDENTITIES[$path]'
    [ -e "$path" ] || [ -L "$path" ] || return 0
    current_identity="$(_cc_temp_identity "$path")" || return 1
    if [ "$current_identity" != "$identity" ]; then
        _cc_temp_error "Temporary path identity changed; leaving it untouched: $path"
        return 1
    fi
    case "$kind" in
        file)
            [ ! -d "$path" ] || {
                _cc_temp_error "Temporary file became a directory; leaving it untouched: $path"
                return 1
            }
            command rm -f -- "$path"
            ;;
        directory)
            [ -d "$path" ] && [ ! -L "$path" ] || {
                _cc_temp_error "Temporary directory changed type; leaving it untouched: $path"
                return 1
            }
            command rm -rf -- "$path"
            ;;
        *) return 2 ;;
    esac
}

cc_temp_cleanup_all() {
    local index path cleanup_failed=0
    _cc_temp_reset_for_process
    [ "$CC_TEMP_CLEANING" -eq 0 ] || return 0
    CC_TEMP_CLEANING=1
    for ((index = ${#CC_TEMP_PATHS[@]} - 1; index >= 0; index--)); do
        path="${CC_TEMP_PATHS[$index]}"
        cc_temp_remove "$path" || cleanup_failed=1
    done
    CC_TEMP_CLEANING=0
    return "$cleanup_failed"
}
