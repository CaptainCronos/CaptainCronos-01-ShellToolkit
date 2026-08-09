#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-network.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash uname command
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Provide semantic, platform-aware network state inspection.
# ==============================================================================

if [ -z "${CC_NETWORK_LOADED:-}" ]; then
    _cc_network_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_network_lib_dir/cc-programs.sh"
    unset _cc_network_lib_dir
    CC_NETWORK_LOADED=1
fi

_cc_net_platform() {
    uname -s 2>/dev/null || printf '%s\n' unknown
}

_cc_net_network_program() {
    case "$(_cc_net_platform)" in
        Linux) cc_program_get network ;;
        FreeBSD) printf '%s\n' ifconfig ;;
        *) return 1 ;;
    esac
}

_cc_net_socket_program() {
    case "$(_cc_net_platform)" in
        Linux) cc_program_get sockets ;;
        FreeBSD) printf '%s\n' sockstat ;;
        *) return 1 ;;
    esac
}

_cc_net_route_program() {
    case "$(_cc_net_platform)" in
        Linux) cc_program_get network ;;
        FreeBSD) printf '%s\n' route ;;
        *) return 1 ;;
    esac
}

_cc_net_network_available() {
    local program
    program="$(_cc_net_network_program)" || return 1
    command -v "$program" >/dev/null 2>&1
}

_cc_net_sockets_available() {
    local program
    program="$(_cc_net_socket_program)" || return 1
    command -v "$program" >/dev/null 2>&1
}

_cc_net_interfaces() {
    local program
    program="$(_cc_net_network_program)" || return 1
    case "$(_cc_net_platform)" in
        Linux) "$program" -o link show ;;
        FreeBSD) "$program" -l ;;
        *) return 1 ;;
    esac
}

_cc_net_addresses() {
    local program
    program="$(_cc_net_network_program)" || return 1
    case "$(_cc_net_platform)" in
        Linux) "$program" -o addr show ;;
        FreeBSD) "$program" -a ;;
        *) return 1 ;;
    esac
}

_cc_net_default_route() {
    local program
    program="$(_cc_net_route_program)" || return 1
    case "$(_cc_net_platform)" in
        Linux) "$program" -o route show default ;;
        FreeBSD) "$program" -n get default ;;
        *) return 1 ;;
    esac
}

_cc_net_routes() {
    local program
    program="$(_cc_net_route_program)" || return 1
    case "$(_cc_net_platform)" in
        Linux) "$program" -o route show ;;
        FreeBSD) netstat -rn ;;
        *) return 1 ;;
    esac
}

_cc_net_route_to() {
    [ "$#" -eq 1 ] || return 2
    local program
    program="$(_cc_net_route_program)" || return 1
    case "$(_cc_net_platform)" in
        Linux) "$program" -o route get "$1" ;;
        FreeBSD) "$program" -n get "$1" ;;
        *) return 1 ;;
    esac
}

_cc_net_listeners() {
    local program
    program="$(_cc_net_socket_program)" || return 1
    case "$(_cc_net_platform)" in
        Linux) "$program" -H -ltn ;;
        FreeBSD) "$program" -l -4 -6 ;;
        *) return 1 ;;
    esac
}

_cc_net_connections() {
    local program
    program="$(_cc_net_socket_program)" || return 1
    case "$(_cc_net_platform)" in
        Linux) "$program" -H -nt state established ;;
        FreeBSD) "$program" -c -4 -6 ;;
        *) return 1 ;;
    esac
}

_cc_net_tcp_port_is_listening() {
    [ "$#" -eq 1 ] || return 2
    [[ "$1" =~ ^[0-9]+$ ]] || return 2
    local program output
    program="$(_cc_net_socket_program)" || return 1
    case "$(_cc_net_platform)" in
        Linux)
            output="$("$program" -H -ltn sport = ":$1")" || return 1
            [ -n "$output" ]
            ;;
        FreeBSD)
            "$program" -l -P tcp -p "$1" 2>/dev/null | awk 'NR > 1 {found=1} END {exit !found}'
            ;;
        *) return 1 ;;
    esac
}
