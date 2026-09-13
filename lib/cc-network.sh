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

# Normalized record schemas (all TSV):
# interface: name, state, kind, flags
# address: interface, family, address, scope, state
# route: destination, gateway, interface, source, flags
# socket: transport, local_address, port, state, owner, owner_state
# finding: state, code, layer, message
# Raw platform output remains confined to this library.
cc_network_snapshot_reset() { CC_NET_SNAPSHOT_READY=0; CC_NET_INTERFACES=""; CC_NET_ADDRESSES=""; CC_NET_ROUTES=""; CC_NET_SOCKETS=""; }

_cc_net_linux_interfaces_tsv() {
    _cc_net_interfaces | awk -F': ' '{ split($1, a, ":"); name=$2; split($3, b, " "); state="unknown"; flags=""; if (match($3, /<[^>]*>/)) flags=substr($3, RSTART+1, RLENGTH-2); if ($0 ~ /state UP/) state="up"; else if ($0 ~ /state DOWN/) state="down"; else if (flags ~ /UP/) state="up"; kind=(name=="lo" ? "loopback" : "physical-or-virtual"); print name "\t" state "\t" kind "\t" flags }'
}
_cc_net_freebsd_interfaces_tsv() { _cc_net_interfaces | tr ' ' '\n' | awk 'NF {print $1 "\tunknown\tphysical-or-virtual\t"}'; }
cc_network_interfaces_tsv() { case "$(_cc_net_platform)" in Linux) _cc_net_linux_interfaces_tsv;; FreeBSD) _cc_net_freebsd_interfaces_tsv;; *) return 1;; esac; }

_cc_net_linux_addresses_tsv() {
    _cc_net_addresses | awk '{ iface=$2; sub(/:$/, "", iface); for (i=3;i<=NF;i++) if ($i=="inet" || $i=="inet6") { family=($i=="inet" ? "ipv4" : "ipv6"); addr=$(i+1); scope=""; for(j=i+2;j<=NF;j++) if($(j)=="scope") {scope=$(j+1); break}; print iface "\t" family "\t" addr "\t" scope "\t" "observed" } }'
}
_cc_net_freebsd_addresses_tsv() { _cc_net_addresses | awk '/^[^[:space:]]/ {iface=$1} /inet[6]? / {family=($1=="inet6"?"ipv6":"ipv4"); print iface "\t" family "\t" $2 "\tunknown\tobserved"}'; }
cc_network_addresses_tsv() { case "$(_cc_net_platform)" in Linux) _cc_net_linux_addresses_tsv;; FreeBSD) _cc_net_freebsd_addresses_tsv;; *) return 1;; esac; }

_cc_net_linux_routes_tsv() {
    _cc_net_routes | awk '{dest=$1; gateway=""; iface=""; source=""; flags=""; for(i=2;i<=NF;i++) {if($i=="via") gateway=$(i+1); if($i=="dev") iface=$(i+1); if($i=="src") source=$(i+1); if($i=="metric") flags="metric=" $(i+1)}; print dest "\t" gateway "\t" iface "\t" source "\t" flags}'
}
_cc_net_freebsd_routes_tsv() { _cc_net_default_route | awk '/gateway:/{g=$2} /interface:/{i=$2} END {if(g!="") print "default\t" g "\t" i "\t\t"}'; }
cc_network_routes_tsv() { case "$(_cc_net_platform)" in Linux) _cc_net_linux_routes_tsv;; FreeBSD) _cc_net_freebsd_routes_tsv;; *) return 1;; esac; }
cc_network_default_route_tsv() { cc_network_routes_tsv | awk -F '\t' '$1=="default" {print; exit}'; }

_cc_net_linux_sockets_tsv() {
    local program
    program="$(_cc_net_socket_program)" || return 1
    "$program" -H -ltnup 2>/dev/null | awk '
      { proto=$1; local=$5; state=($1 ~ /^udp/ ? "UNCONN" : $2); owner="unknown"; owner_state="unknown";
        if (match($0, /users:\(\([^)]*\)/)) { text=substr($0,RSTART,RLENGTH); sub(/^users:\(\("/,"",text); sub(/".*/,"",text); owner=text; owner_state="available" }
        else if ($0 ~ /users:/) owner_state="restricted";
        port=local; sub(/^.*:/,"",port); addr=local; sub(/:[^:]*$/, "", addr); print proto "\t" addr "\t" port "\t" state "\t" owner "\t" owner_state
      }'
}
_cc_net_freebsd_sockets_tsv() { _cc_net_listeners | awk 'NR>1 {print "unknown\t" $6 "\t" $7 "\tLISTEN\t" $2 "\tavailable"}'; }
cc_network_sockets_tsv() { case "$(_cc_net_platform)" in Linux) _cc_net_linux_sockets_tsv;; FreeBSD) _cc_net_freebsd_sockets_tsv;; *) return 1;; esac; }

cc_network_snapshot() {
    [ "${CC_NET_SNAPSHOT_READY:-0}" -eq 1 ] && return 0
    CC_NET_INTERFACES="$(cc_network_interfaces_tsv 2>/dev/null || true)"
    CC_NET_ADDRESSES="$(cc_network_addresses_tsv 2>/dev/null || true)"
    CC_NET_ROUTES="$(cc_network_routes_tsv 2>/dev/null || true)"
    CC_NET_SOCKETS="$(cc_network_sockets_tsv 2>/dev/null || true)"
    export CC_NET_INTERFACES CC_NET_ADDRESSES CC_NET_ROUTES CC_NET_SOCKETS
    CC_NET_SNAPSHOT_READY=1
}

cc_network_local_findings_tsv() {
    cc_network_snapshot
    local usable=0 addresses=0
    while IFS=$'\t' read -r _ state kind _; do [ "$kind" = loopback ] || [ "$state" != up ] || usable=$((usable+1)); done <<<"$CC_NET_INTERFACES"
    while IFS=$'\t' read -r iface family address scope _; do
        [ -n "$address" ] || continue
        [ "$iface" = lo ] && continue
        case "$family:$address:$scope" in ipv4:127.*:*|ipv6:::*:*|*:*/128:host) ;; *) addresses=$((addresses+1));; esac
    done <<<"$CC_NET_ADDRESSES"
    if [ "$usable" -gt 0 ]; then printf 'PASS\tUSABLE_INTERFACE\tinterface\t%s usable non-loopback interface(s) observed\n' "$usable"; else printf 'FAIL\tNO_USABLE_INTERFACE\tinterface\tno usable non-loopback interface observed\n'; fi
    if [ "$addresses" -gt 0 ]; then printf 'PASS\tUSABLE_ADDRESS\taddress\t%s usable address(es) observed\n' "$addresses"; else printf 'FAIL\tNO_USABLE_ADDRESS\taddress\tno usable non-loopback address observed\n'; fi
    if cc_network_default_route_tsv | grep -q .; then printf 'PASS\tDEFAULT_ROUTE\troute\tdefault route observed\n'; else printf 'FAIL\tNO_DEFAULT_ROUTE\troute\tno default route observed\n'; fi
}

cc_network_dns_summary_tsv() {
    if command -v resolvectl >/dev/null 2>&1; then printf 'resolvectl\tavailable\n';
    elif [ -r /etc/resolv.conf ]; then printf 'resolv.conf\tavailable\n';
    else printf 'none\tunknown\n'; fi
}
cc_network_resolve_host() { [ "$#" -eq 1 ] || return 2; command -v getent >/dev/null 2>&1 || return 20; getent hosts "$1" >/dev/null 2>&1; }

cc_network_diagnose_tsv() {
    local target_ip="$1" target_host="$2" target_url="$3" timeout="$4" gateway route
    cc_network_local_findings_tsv
    route="$(cc_network_default_route_tsv || true)"; gateway="$(awk -F '\t' '{print $2; exit}' <<<"$route")"
    if [ -n "$gateway" ] && command -v ping >/dev/null 2>&1; then
        if ping -c 1 -W "$timeout" "$gateway" >/dev/null 2>&1; then printf 'PASS\tGATEWAY_ICMP\tgateway\tgateway ICMP reply received\n'; else printf 'WARN\tGATEWAY_ICMP_UNCONFIRMED\tgateway\tgateway ICMP did not reply; this is not authoritative\n'; fi
    else printf 'SKIP\tGATEWAY_ICMP_NOT_TESTED\tgateway\tICMP gateway probe not available or no gateway known\n'; fi
    if _cc_net_route_to "$target_ip" >/dev/null 2>&1; then printf 'PASS\tEXTERNAL_ROUTE\texternal\troute to configured external target observed\n'; else printf 'FAIL\tEXTERNAL_CONNECTIVITY_FAILED\texternal\tno route to configured external target\n'; fi
    if cc_network_resolve_host "$target_host"; then printf 'PASS\tHOST_RESOLUTION\tdns\thostname/NSS resolution succeeded\n'; else rc=$?; [ "$rc" -eq 20 ] && printf 'SKIP\tDNS_INSPECTION_UNSUPPORTED\tdns\tgetent is unavailable; hostname/NSS resolution not tested\n' || printf 'FAIL\tHOST_RESOLUTION_FAILED\tdns\thostname/NSS resolution failed\n'; fi
    if _cc_http_probe_head "$target_url" "$timeout"; then printf 'PASS\tHTTPS_PROBE\thttp\tbounded HTTPS probe succeeded\n'; else printf 'FAIL\tHTTPS_PROBE_FAILED\thttp\tbounded HTTPS probe failed\n'; fi
}
