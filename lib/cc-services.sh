#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-services.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash uname command
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Provide semantic, scoped service and system-log operations.
# ==============================================================================

if [ -z "${CC_SERVICES_LOADED:-}" ]; then
    _cc_services_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_services_lib_dir/cc-programs.sh"
    # shellcheck disable=SC1091
    source "$_cc_services_lib_dir/cc-platform.sh"
    unset _cc_services_lib_dir
    CC_SERVICES_LOADED=1
fi

_cc_service_validate_scope() {
    case "$1" in
        system|user) return 0 ;;
        *) cc_error "Invalid service scope: $1"; return 2 ;;
    esac
}

_cc_service_scope_args() {
    local scope="$1"
    local -n result="$2"
    _cc_service_validate_scope "$scope" || return $?
    if [ "$scope" = "user" ]; then
        result=(--user)
    else
        # The nameref intentionally clears the caller-owned array.
        # shellcheck disable=SC2034
        result=()
    fi
}

_cc_service_manager() {
    local init_system manager
    init_system="$(cc_platform_init_system)"
    case "$init_system" in
        systemd) manager="$(cc_program_get service-manager)" ;;
        openrc) manager="rc-service" ;;
        freebsd-rc) manager=service ;;
        *) return 1 ;;
    esac
    if declare -F cc_debug_kv >/dev/null 2>&1; then
        cc_debug_kv "service platform adapter" "$init_system"
        cc_debug_kv "selected implementation" "$manager"
    fi
    printf '%s\n' "$manager"
}

_cc_system_log_program() {
    [ "$(cc_platform_init_system)" = "systemd" ] || return 1
    cc_program_get system-log
}

_cc_service_manager_available() {
    local manager
    manager="$(_cc_service_manager)" || return 1
    command -v "$manager" >/dev/null 2>&1
}

_cc_log_available() {
    local log_program
    log_program="$(_cc_system_log_program)" || return 1
    command -v "$log_program" >/dev/null 2>&1
}

_cc_service_exists() {
    [ "$#" -eq 2 ] || return 2
    local scope="$1" unit="$2" manager state
    local -a scope_args=()
    _cc_service_validate_scope "$scope" || return $?
    manager="$(_cc_service_manager)" || return 1
    case "$(cc_platform_init_system)" in
        systemd)
            _cc_service_scope_args "$scope" scope_args || return $?
            state="$("$manager" "${scope_args[@]}" show --property=LoadState --value "$unit" 2>/dev/null || true)"
            [ -n "$state" ] && [ "$state" != "not-found" ]
            ;;
        openrc)
            [ "$scope" = "system" ] || return 1
            [ -x "/etc/init.d/$unit" ]
            ;;
        freebsd-rc)
            [ "$scope" = "system" ] || return 1
            "$manager" -l 2>/dev/null | awk -v unit="$unit" '$0 == unit {found=1} END {exit !found}'
            ;;
        *) return 1 ;;
    esac
}

_cc_service_is_active() {
    [ "$#" -eq 2 ] || return 2
    local scope="$1" unit="$2" manager
    local -a scope_args=()
    _cc_service_validate_scope "$scope" || return $?
    manager="$(_cc_service_manager)" || return 1
    case "$(cc_platform_init_system)" in
        systemd)
            _cc_service_scope_args "$scope" scope_args || return $?
            "$manager" "${scope_args[@]}" is-active --quiet "$unit"
            ;;
        openrc)
            [ "$scope" = "system" ] || return 1
            "$manager" "$unit" status >/dev/null 2>&1
            ;;
        freebsd-rc)
            [ "$scope" = "system" ] || return 1
            "$manager" "$unit" onestatus >/dev/null 2>&1
            ;;
        *) return 1 ;;
    esac
}

_cc_service_is_enabled() {
    [ "$#" -eq 2 ] || return 2
    local scope="$1" unit="$2" manager
    local -a scope_args=()
    _cc_service_validate_scope "$scope" || return $?
    manager="$(_cc_service_manager)" || return 1
    case "$(cc_platform_init_system)" in
        systemd)
            _cc_service_scope_args "$scope" scope_args || return $?
            "$manager" "${scope_args[@]}" is-enabled --quiet "$unit"
            ;;
        openrc)
            [ "$scope" = "system" ] || return 1
            rc-update show 2>/dev/null | awk -v unit="$unit" '$1 == unit {found=1} END {exit !found}'
            ;;
        freebsd-rc)
            [ "$scope" = "system" ] || return 1
            "$manager" "$unit" enabled >/dev/null 2>&1
            ;;
        *) return 1 ;;
    esac
}

_cc_service_status() {
    [ "$#" -eq 2 ] || return 2
    _cc_service_validate_scope "$1" || return $?
    if _cc_service_is_active "$1" "$2"; then
        printf '%s\n' active
    elif _cc_service_exists "$1" "$2"; then
        printf '%s\n' installed-not-active
    else
        printf '%s\n' not-found
    fi
}

_cc_service_print_command() {
    local rendered="DRY RUN:" argument
    for argument in "$@"; do
        printf -v argument '%q' "$argument"
        rendered+=" $argument"
    done
    if [ -n "${CC_SERVICE_REPORTER:-}" ]; then
        "${CC_SERVICE_REPORTER}" "$rendered"
    else
        printf '%s\n' "$rendered"
    fi
}

_cc_service_run_command() {
    local scope="$1"
    shift
    local runner="${CC_SERVICE_RUNNER:-}"
    local -a command scope_args=()
    _cc_service_validate_scope "$scope" || return $?
    _cc_service_scope_args "$scope" scope_args || return $?
    command=("$1" "${scope_args[@]}" "${@:2}")
    if [ "$scope" = "system" ]; then
        command=(sudo "${command[@]}")
    fi
    if [ "${CC_SERVICE_DRY_RUN:-0}" -eq 1 ]; then
        _cc_service_print_command "${command[@]}"
    elif [ -n "$runner" ]; then
        "$runner" "${command[@]}"
    else
        "${command[@]}"
    fi
}

_cc_service_execute() {
    local scope="$1"
    shift
    local manager
    manager="$(_cc_service_manager)" || return 1
    _cc_service_run_command "$scope" "$manager" "$@"
}

_cc_service_action() {
    local action="$1" scope="$2" unit="$3" init_system
    init_system="$(cc_platform_init_system)"
    case "$init_system" in
        systemd) _cc_service_execute "$scope" "$action" "$unit" ;;
        openrc|freebsd-rc)
            [ "$scope" = "system" ] || return 1
            _cc_service_execute system "$unit" "$action"
            ;;
        *) return 1 ;;
    esac
}

# Public Component 5 callers use this variant so system-scope lifecycle work
# never silently invokes sudo.  Permission must be supplied by the invoking
# process; legacy helpers above retain their established behavior.
_cc_service_action_unprivileged() {
    [ "$#" -eq 3 ] || return 2
    local action="$1" scope="$2" unit="$3" manager init_system
    _cc_service_validate_scope "$scope" || return $?
    case "$action" in start|stop|restart) ;; *) return 2;; esac
    manager="$(_cc_service_manager)" || return 1
    init_system="$(cc_platform_init_system)"
    case "$init_system" in
        systemd)
            local -a scope_args=()
            _cc_service_scope_args "$scope" scope_args || return $?
            "$manager" "${scope_args[@]}" "$action" "$unit"
            ;;
        openrc|freebsd-rc)
            [ "$scope" = system ] || return 1
            "$manager" "$unit" "$action"
            ;;
        *) return 1 ;;
    esac
}

# Bounded systemd service enumeration for the public service namespace.
# Individual normalized records remain owned by the existing record helper.
_cc_service_records_tsv() {
    [ "$#" -eq 2 ] || return 2
    local scope="$1" limit="$2" manager line unit count=0
    local -a scope_args=()
    _cc_service_validate_scope "$scope" || return $?
    [[ "$limit" =~ ^[1-9][0-9]*$ ]] || return 2
    [ "$(cc_platform_init_system)" = systemd ] || { printf '%s\tunknown\tunknown\tunknown\tunknown\tunknown\tunknown\tservice\tunknown\tunknown\tunsupported\n' "$scope"; return 0; }
    manager="$(_cc_service_manager)" || { printf '%s\tunknown\tunknown\tunknown\tunknown\tunknown\tunknown\tservice\tunknown\tunknown\trestricted\n' "$scope"; return 0; }
    _cc_service_scope_args "$scope" scope_args || return $?
    while IFS= read -r line; do
        unit="${line%%[[:space:]]*}"; [ -n "$unit" ] || continue
        _cc_service_record_tsv "$scope" "$unit"
        count=$((count + 1)); [ "$count" -lt "$limit" ] || break
    done < <("$manager" "${scope_args[@]}" list-units --all --type=service --no-legend --plain 2>/dev/null)
}

_cc_service_start() { [ "$#" -eq 2 ] || return 2; _cc_service_action start "$1" "$2"; }
_cc_service_stop() { [ "$#" -eq 2 ] || return 2; _cc_service_action stop "$1" "$2"; }
_cc_service_restart() { [ "$#" -eq 2 ] || return 2; _cc_service_action restart "$1" "$2"; }
_cc_service_reload() { [ "$#" -eq 2 ] || return 2; _cc_service_action reload "$1" "$2"; }

_cc_service_enable() {
    [ "$#" -eq 2 ] || return 2
    case "$(cc_platform_init_system)" in
        systemd) _cc_service_execute "$1" enable "$2" ;;
        openrc) [ "$1" = "system" ] && _cc_service_run_command system rc-update add "$2" default ;;
        *) return 1 ;;
    esac
}

_cc_service_disable() {
    [ "$#" -eq 2 ] || return 2
    case "$(cc_platform_init_system)" in
        systemd) _cc_service_execute "$1" disable "$2" ;;
        openrc) [ "$1" = "system" ] && _cc_service_run_command system rc-update del "$2" default ;;
        *) return 1 ;;
    esac
}

_cc_service_enable_now() {
    [ "$#" -eq 2 ] || return 2
    case "$(cc_platform_init_system)" in
        systemd) _cc_service_execute "$1" enable --now "$2" ;;
        *) _cc_service_enable "$1" "$2" && _cc_service_start "$1" "$2" ;;
    esac
}

_cc_service_disable_now() {
    [ "$#" -eq 2 ] || return 2
    case "$(cc_platform_init_system)" in
        systemd) _cc_service_execute "$1" disable --now "$2" ;;
        *) _cc_service_stop "$1" "$2" && _cc_service_disable "$1" "$2" ;;
    esac
}

_cc_service_daemon_reload() {
    [ "$#" -eq 1 ] || return 2
    _cc_service_validate_scope "$1" || return $?
    case "$(cc_platform_init_system)" in
        systemd) _cc_service_execute "$1" daemon-reload ;;
        openrc|freebsd-rc) return 0 ;;
        *) return 1 ;;
    esac
}

_cc_service_list_timers() {
    [ "$#" -eq 1 ] || return 2
    local manager
    local -a scope_args=()
    [ "$(cc_platform_init_system)" = "systemd" ] || return 1
    manager="$(_cc_service_manager)" || return 1
    _cc_service_scope_args "$1" scope_args || return $?
    local rc=0
    if "$manager" "${scope_args[@]}" list-timers --all --no-pager; then
        rc=0
    else
        rc=$?
    fi
    if declare -F cc_debug_kv >/dev/null 2>&1; then
        cc_debug_kv "service operation" "list-timers"
        cc_debug_kv "service scope" "$1"
        cc_debug_kv "underlying exit status" "$rc"
        cc_debug_kv "failure propagation" "service manager -> semantic helper -> caller"
    fi
    return "$rc"
}

_cc_service_list_unit_files() {
    [ "$#" -eq 1 ] || return 2
    local manager
    local -a scope_args=()
    [ "$(cc_platform_init_system)" = "systemd" ] || return 1
    manager="$(_cc_service_manager)" || return 1
    _cc_service_scope_args "$1" scope_args || return $?
    "$manager" "${scope_args[@]}" list-unit-files --no-pager
}

_cc_service_default_target() {
    [ "$#" -eq 1 ] || return 2
    local manager
    local -a scope_args=()
    [ "$(cc_platform_init_system)" = "systemd" ] || return 1
    manager="$(_cc_service_manager)" || return 1
    _cc_service_scope_args "$1" scope_args || return $?
    "$manager" "${scope_args[@]}" get-default
}

_cc_log_scope_args() {
    local scope="$1"
    local -n scope_result="$2"
    _cc_service_validate_scope "$scope" || return $?
    if [ "$scope" = "user" ]; then
        scope_result=(--user)
    else
        # The nameref intentionally clears the caller-owned array.
        # shellcheck disable=SC2034
        scope_result=()
    fi
}

# Canonical read-only journal contract.  All consumers must provide an explicit
# scope, time window, and positive record limit.  It never escalates and never
# permits an unlimited scan.
_cc_log_query() {
    [ "$#" -ge 3 ] && [ "$#" -le 5 ] || return 2
    local scope="$1" since="$2" limit="$3" unit="${4:-}" priority="${5:-}" log_program
    local -a scope_args=() query_args=()
    [ -n "$since" ] && [[ "$limit" =~ ^[1-9][0-9]*$ ]] || return 2
    log_program="$(_cc_system_log_program)" || return 1
    command -v "$log_program" >/dev/null 2>&1 || return 1
    _cc_log_scope_args "$scope" scope_args || return $?
    query_args=("${scope_args[@]}" --since "$since" --no-pager --output=short-iso -n "$limit")
    [ -z "$unit" ] || query_args+=(--unit "$unit")
    [ -z "$priority" ] || query_args+=(--priority "$priority")
    "$log_program" "${query_args[@]}"
}

_cc_log_since() { [ "$#" -eq 3 ] || return 2; _cc_log_query "$1" "$2" "$3"; }

_cc_log_unit() {
    [ "$#" -eq 4 ] || return 2
    _cc_log_query "$1" "$3" "$4" "$2"
}

_cc_log_boot() {
    [ "$#" -eq 3 ] || return 2
    local log_program
    local -a scope_args=()
    [[ "$3" =~ ^[1-9][0-9]*$ ]] || return 2
    log_program="$(_cc_system_log_program)" || return 1
    _cc_log_scope_args "$1" scope_args || return $?
    "$log_program" "${scope_args[@]}" --boot "$2" --no-pager --output=short-iso -n "$3"
}

_cc_log_priority() {
    [ "$#" -eq 4 ] || return 2
    _cc_log_query "$1" "$3" "$4" "" "$2"
}

# Normalized TSV service record:
# scope, unit, description, load_state, active_state, sub_state,
# enabled_state, unit_type, pid, restart_count, collection_state, where, what
_cc_service_unit_type() { case "$1" in *.*) printf '%s\n' "${1##*.}";; *) printf '%s\n' unknown;; esac; }

_cc_service_enabled_state() {
    [ "$#" -eq 2 ] || return 2
    local scope="$1" unit="$2" manager output rc=0
    local -a scope_args=()
    manager="$(_cc_service_manager)" || return 1
    [ "$(cc_platform_init_system)" = systemd ] || return 1
    _cc_service_scope_args "$scope" scope_args || return $?
    output="$("$manager" "${scope_args[@]}" is-enabled "$unit" 2>/dev/null)" || rc=$?
    output="${output%%$'\n'*}"
    case "$output" in enabled|enabled-runtime|linked|linked-runtime|alias|static|indirect|generated|disabled|masked|masked-runtime) printf '%s\n' "$output";; *) [ "$rc" -eq 0 ] && printf '%s\n' enabled || printf '%s\n' unknown;; esac
}

_cc_service_record_tsv() {
    [ "$#" -eq 2 ] || return 2
    local scope="$1" unit="$2" manager description load active sub enabled pid restarts collection=available where what
    local -a scope_args=()
    _cc_service_validate_scope "$scope" || return $?
    if [ "$(cc_platform_init_system)" != systemd ]; then
        printf '%s\t%s\tunknown\tunknown\tunknown\tunknown\tunknown\t%s\tunknown\tunknown\tunsupported\n' "$scope" "$unit" "$(_cc_service_unit_type "$unit")"
        return 0
    fi
    manager="$(_cc_service_manager)" || { printf '%s\t%s\tunknown\tunknown\tunknown\tunknown\tunknown\t%s\tunknown\tunknown\trestricted\n' "$scope" "$unit" "$(_cc_service_unit_type "$unit")"; return 0; }
    _cc_service_scope_args "$scope" scope_args || return $?
    # systemctl --value omits properties whose values are empty.  Query each
    # property separately so an empty MainPID or NRestarts cannot shift Where
    # and What into the wrong columns.
    description="$("$manager" "${scope_args[@]}" show --property=Description --value "$unit" 2>/dev/null || true)"
    load="$("$manager" "${scope_args[@]}" show --property=LoadState --value "$unit" 2>/dev/null || true)"
    active="$("$manager" "${scope_args[@]}" show --property=ActiveState --value "$unit" 2>/dev/null || true)"
    sub="$("$manager" "${scope_args[@]}" show --property=SubState --value "$unit" 2>/dev/null || true)"
    pid="$("$manager" "${scope_args[@]}" show --property=MainPID --value "$unit" 2>/dev/null || true)"
    restarts="$("$manager" "${scope_args[@]}" show --property=NRestarts --value "$unit" 2>/dev/null || true)"
    where="$("$manager" "${scope_args[@]}" show --property=Where --value "$unit" 2>/dev/null || true)"
    what="$("$manager" "${scope_args[@]}" show --property=What --value "$unit" 2>/dev/null || true)"
    [ -n "$load" ] || collection=restricted
    description="${description:-unknown}"; load="${load:-unknown}"; active="${active:-unknown}"; sub="${sub:-unknown}"; pid="${pid:-unknown}"; restarts="${restarts:-unknown}"
    if [ "$load" = not-found ]; then collection=available; active=inactive; sub=dead; fi
    enabled="$(_cc_service_enabled_state "$scope" "$unit" 2>/dev/null || printf unknown)"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$scope" "$unit" "${description//$'\t'/ }" "$load" "$active" "$sub" "$enabled" "$(_cc_service_unit_type "$unit")" "$pid" "$restarts" "$collection" "$where" "$what"
}

# Classify a failed unit without changing the raw failed-unit inventory.
#
# A Snap revision mount is ignored only when systemd identifies it as the
# canonical generated unit and its exact backing revision image is gone.  A
# name prefix alone is deliberately insufficient: live or malformed Snap
# mounts remain unknown/actionable to health callers.
_cc_service_failed_unit_classification() {
    [ "$#" -eq 8 ] || return 2
    local scope="$1" unit="$2" description="$3" load="$4" active="$5" sub="$6" where="$7" what="$8"
    local snap revision snaps_dir decoded_unit
    [ "$scope" = system ] && [ "$(cc_platform_init_system)" = systemd ] || { printf '%s\n' actionable; return 0; }
    [ "$(_cc_service_unit_type "$unit")" = mount ] || { printf '%s\n' actionable; return 0; }
    # Mount unit names use systemd escaping (for example, \x2d for a hyphen).
    # Decode through systemd rather than trying to reverse that escaping here.
    command -v systemd-escape >/dev/null 2>&1 || { printf '%s\n' unknown; return 0; }
    decoded_unit="$(systemd-escape --unescape "$unit" 2>/dev/null || true)"
    if [[ ! "$decoded_unit" =~ ^snap/([A-Za-z0-9][A-Za-z0-9+_.-]*)/([0-9]+)\.mount$ ]]; then
        printf '%s\n' actionable
        return 0
    fi
    snap="${BASH_REMATCH[1]}"; revision="${BASH_REMATCH[2]}"
    [ "$description" = "Mount unit for $snap, revision $revision" ] && [ "$load" = loaded ] && [ "$active" = failed ] && [ "$sub" = failed ] || { printf '%s\n' unknown; return 0; }
    snaps_dir="${CC_SERVICE_SNAPD_SNAPS_DIR:-/var/lib/snapd/snaps}"
    if [ "$where" = "/snap/$snap/$revision" ] && [ "$what" = "$snaps_dir/${snap}_${revision}.snap" ] && [ ! -e "$what" ]; then
        printf '%s\n' ignored-stale-snap
    else
        printf '%s\n' unknown
    fi
}

# TSV: scope, unit, description, load_state, active_state, sub_state,
# enabled_state, unit_type, pid, restart_count, collection_state, where, what
_cc_service_failed_records_tsv() {
    [ "$#" -eq 1 ] || return 2
    local scope="$1" manager line unit
    local -a scope_args=()
    [ "$(cc_platform_init_system)" = systemd ] || return 1
    manager="$(_cc_service_manager)" || return 1
    _cc_service_scope_args "$scope" scope_args || return $?
    while IFS= read -r line; do
        unit="${line%%[[:space:]]*}"; [ -n "$unit" ] || continue
        _cc_service_record_tsv "$scope" "$unit"
    done < <("$manager" "${scope_args[@]}" list-units --state=failed --all --no-legend --plain 2>/dev/null)
}

# Normalized TSV timer record: scope, unit, next_run, last_run, activates,
# active_state, enabled_state, collection_state. Callers request named timers;
# broad timer enumeration remains presentation-specific and bounded by systemd.
_cc_timer_record_tsv() {
    [ "$#" -eq 2 ] || return 2
    local scope="$1" unit="$2" manager output next last activates active enabled collection=available
    local -a scope_args=() values=()
    if [ "$(cc_platform_init_system)" != systemd ]; then printf '%s\t%s\tunknown\tunknown\tunknown\tunknown\tunknown\tunsupported\n' "$scope" "$unit"; return 0; fi
    manager="$(_cc_service_manager)" || { printf '%s\t%s\tunknown\tunknown\tunknown\tunknown\tunknown\trestricted\n' "$scope" "$unit"; return 0; }
    _cc_service_scope_args "$scope" scope_args || return $?
    output="$("$manager" "${scope_args[@]}" show --property=NextElapseUSecRealtime --property=LastTriggerUSec --property=Triggers --property=ActiveState --value "$unit" 2>/dev/null)" || true
    mapfile -t values <<<"$output"; next="${values[0]:-unknown}"; last="${values[1]:-unknown}"; activates="${values[2]:-unknown}"; active="${values[3]:-unknown}"
    [ -n "$output" ] || collection=restricted
    enabled="$(_cc_service_enabled_state "$scope" "$unit" 2>/dev/null || printf unknown)"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$scope" "$unit" "$next" "$last" "$activates" "$active" "$enabled" "$collection"
}
