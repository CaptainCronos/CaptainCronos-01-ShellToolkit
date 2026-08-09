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
        *) printf '[CC ERROR] Invalid service scope: %s\n' "$1" >&2; return 2 ;;
    esac
}

_cc_service_scope_args() {
    local scope="$1"
    local -n result="$2"
    _cc_service_validate_scope "$scope" || return $?
    if [ "$scope" = "user" ]; then
        result=(--user)
    else
        result=()
    fi
}

_cc_service_manager() {
    case "$(cc_platform_init_system)" in
        systemd) cc_program_get service-manager ;;
        openrc) printf '%s\n' rc-service ;;
        freebsd-rc) printf '%s\n' service ;;
        *) return 1 ;;
    esac
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
    "$manager" "${scope_args[@]}" list-timers --all --no-pager
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
    local -n result="$2"
    _cc_service_validate_scope "$scope" || return $?
    if [ "$scope" = "user" ]; then
        result=(--user)
    else
        result=()
    fi
}

_cc_log_since() {
    [ "$#" -eq 3 ] || return 2
    local log_program
    local -a scope_args=() limit_args=()
    log_program="$(_cc_system_log_program)" || return 1
    _cc_log_scope_args "$1" scope_args || return $?
    if [ "$3" != "all" ]; then
        [[ "$3" =~ ^[0-9]+$ ]] || return 2
        limit_args=(-n "$3")
    fi
    "$log_program" "${scope_args[@]}" --since "$2" --no-pager --output=short-iso "${limit_args[@]}"
}

_cc_log_unit() {
    [ "$#" -eq 4 ] || return 2
    local log_program
    local -a scope_args=()
    log_program="$(_cc_system_log_program)" || return 1
    _cc_log_scope_args "$1" scope_args || return $?
    "$log_program" "${scope_args[@]}" --unit "$2" --since "$3" --no-pager --output=short-iso -n "$4"
}

_cc_log_boot() {
    [ "$#" -eq 3 ] || return 2
    local log_program
    local -a scope_args=()
    log_program="$(_cc_system_log_program)" || return 1
    _cc_log_scope_args "$1" scope_args || return $?
    "$log_program" "${scope_args[@]}" --boot "$2" --no-pager --output=short-iso -n "$3"
}

_cc_log_priority() {
    [ "$#" -eq 4 ] || return 2
    local log_program
    local -a scope_args=()
    log_program="$(_cc_system_log_program)" || return 1
    _cc_log_scope_args "$1" scope_args || return $?
    "$log_program" "${scope_args[@]}" --priority "$2" --since "$3" --no-pager --output=short-iso -n "$4"
}
