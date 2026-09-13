#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-network.sh"
source "$PROJECT_ROOT/lib/cc-http.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# Fixture adapters: no host commands, root privileges, or external network.
SCENARIO=ethernet
_cc_net_platform() { printf '%s\n' Linux; }
_cc_net_interfaces() { case "$SCENARIO" in ethernet) printf '2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP\n';; wifi) printf '3: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP\n';; multiple) printf '1: lo: <LOOPBACK,UP> mtu 65536 state UNKNOWN\n2: eth0: <UP> mtu 1500 state UP\n3: eth1: <BROADCAST> mtu 1500 state DOWN\n';; down) printf '2: eth0: <BROADCAST> mtu 1500 state DOWN\n';; esac; }
_cc_net_addresses() { case "$SCENARIO" in ethernet) printf '2: eth0    inet 192.0.2.10/24 scope global eth0\n';; wifi) printf '3: wlan0    inet6 2001:db8::10/64 scope global\n';; multiple) printf '1: lo    inet 127.0.0.1/8 scope host lo\n2: eth0    inet 192.0.2.10/24 scope global eth0\n';; esac; }
_cc_net_routes() { case "$SCENARIO" in noroute|down) :;; *) printf 'default via 192.0.2.1 dev eth0 proto dhcp metric 100\n192.0.2.0/24 dev eth0 proto kernel src 192.0.2.10\n';; esac; }
cc_network_sockets_tsv() { case "$SCENARIO" in sockets) printf 'tcp\t0.0.0.0\t22\tLISTEN\tsshd\tavailable\nudp\t127.0.0.1\t53\tUNCONN\tunknown\trestricted\n';; esac; }
_cc_net_route_to() { [ "$SCENARIO" != externalfail ]; }
cc_network_resolve_host() { [ "$SCENARIO" != dnsfail ]; }
_cc_http_probe_head() { [ "$SCENARIO" != httpfail ]; }
command() { if [ "$1" = -v ] && [ "$2" = ping ]; then return 1; fi; builtin command "$@"; }
assert_find() { local expected="$1" output; shift; output="$("$@")" || fail "fixture command failed"; grep -Fq -- "$expected" <<<"$output" || fail "missing fixture result: $expected"; }
cc_network_snapshot_reset; SCENARIO=ethernet; assert_find $'PASS\tUSABLE_INTERFACE\tinterface' cc_network_local_findings_tsv
cc_network_snapshot_reset; SCENARIO=wifi; assert_find $'PASS\tUSABLE_ADDRESS\taddress' cc_network_local_findings_tsv
cc_network_snapshot_reset; SCENARIO=multiple; assert_find '1 usable non-loopback' cc_network_local_findings_tsv
cc_network_snapshot_reset; SCENARIO=down; assert_find $'FAIL\tNO_USABLE_INTERFACE' cc_network_local_findings_tsv
cc_network_snapshot_reset; SCENARIO=noaddress; assert_find $'FAIL\tNO_USABLE_ADDRESS' cc_network_local_findings_tsv
cc_network_snapshot_reset; SCENARIO=noroute; assert_find $'FAIL\tNO_DEFAULT_ROUTE' cc_network_local_findings_tsv
cc_network_snapshot_reset; SCENARIO=externalfail; assert_find $'FAIL\tEXTERNAL_CONNECTIVITY_FAILED' cc_network_diagnose_tsv 1.1.1.1 example.com https://example.com 1
cc_network_snapshot_reset; SCENARIO=dnsfail; assert_find $'FAIL\tHOST_RESOLUTION_FAILED' cc_network_diagnose_tsv 1.1.1.1 example.com https://example.com 1
cc_network_snapshot_reset; SCENARIO=httpfail; assert_find $'FAIL\tHTTPS_PROBE_FAILED' cc_network_diagnose_tsv 1.1.1.1 example.com https://example.com 1
cc_network_snapshot_reset; SCENARIO=sockets; assert_find $'tcp\t0.0.0.0\t22\tLISTEN\tsshd\tavailable' cc_network_sockets_tsv
cc_network_snapshot_reset; SCENARIO=ethernet; assert_find $'SKIP\tGATEWAY_ICMP_NOT_TESTED' cc_network_diagnose_tsv 1.1.1.1 example.com https://example.com 1
_cc_net_platform() { printf '%s\n' FreeBSD; }
_cc_net_network_program() { printf '%s\n' ifconfig; }; _cc_net_route_program() { printf '%s\n' route; }; _cc_net_socket_program() { printf '%s\n' sockstat; }
[ "$(_cc_net_network_program)" = ifconfig ] || fail 'FreeBSD adapter was not preserved'
[ "$(_cc_net_route_program)" = route ] || fail 'FreeBSD route adapter was not preserved'
[ "$(_cc_net_socket_program)" = sockstat ] || fail 'FreeBSD socket adapter was not preserved'
printf 'Network fixture tests: PASS\n'
