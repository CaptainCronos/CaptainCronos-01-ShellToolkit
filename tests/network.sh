#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-network.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[ "$(cc_program_get network)" = "ip" ] || fail "network capability did not resolve to ip"
[ "$(cc_program_get sockets)" = "ss" ] || fail "socket capability did not resolve to ss"
[ "$(_cc_net_network_program)" = "ip" ] || fail "semantic network program did not use the configured capability"
[ "$(_cc_net_socket_program)" = "ss" ] || fail "semantic socket program did not use the configured capability"

interfaces="$(_cc_net_interfaces)" || fail "interface inspection failed"
[ -n "$interfaces" ] || fail "interface inspection returned no records"
addresses="$(_cc_net_addresses)" || fail "address inspection failed"
[ -n "$addresses" ] || fail "address inspection returned no records"
_cc_net_default_route >/dev/null || fail "default-route inspection failed"
_cc_net_routes >/dev/null || fail "route inspection failed"
_cc_net_route_to 127.0.0.1 >/dev/null || fail "destination-route inspection failed"
_cc_net_listeners >/dev/null || fail "listener inspection failed"
_cc_net_connections >/dev/null || fail "connection inspection failed"
listener_status=0
_cc_net_tcp_port_is_listening 22 || listener_status=$?
[ "$listener_status" -le 1 ] || fail "TCP listener query failed"
invalid_status=0
_cc_net_tcp_port_is_listening invalid || invalid_status=$?
[ "$invalid_status" -eq 2 ] || fail "invalid TCP port returned the wrong status"

_cc_net_platform() { printf '%s\n' FreeBSD; }
[ "$(_cc_net_network_program)" = "ifconfig" ] || fail "FreeBSD network abstraction was not preserved"
[ "$(_cc_net_route_program)" = "route" ] || fail "FreeBSD route abstraction was not preserved"
[ "$(_cc_net_socket_program)" = "sockstat" ] || fail "FreeBSD socket abstraction was not preserved"

printf 'Network interface tests: PASS\n'
