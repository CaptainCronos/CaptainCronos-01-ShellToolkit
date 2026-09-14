#!/usr/bin/env bash
#
# Captain Cronos Shell Toolkit
# Script      : cc-containers.sh
# Category    : Core
# Purpose     : Provide bounded, local, runtime-neutral container inspection.

if [ -z "${CC_CONTAINERS_LOADED:-}" ]; then
    _cc_containers_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_containers_lib_dir/cc-network.sh"
    # shellcheck disable=SC1091
    source "$_cc_containers_lib_dir/cc-storage.sh"
    unset _cc_containers_lib_dir
    CC_CONTAINERS_LOADED=1
fi

# Public bounds consumed by tools/commands/container.
# shellcheck disable=SC2034
CC_CONTAINER_LIST_DEFAULT=50
# shellcheck disable=SC2034
CC_CONTAINER_LIST_MAX=200
# shellcheck disable=SC2034
CC_CONTAINER_LOG_DEFAULT=100
CC_CONTAINER_LOG_MAX=1000

_cc_container_runtime_valid() { case "$1" in docker|podman) return 0;; *) return 1;; esac; }
_cc_container_positive_limit() { [[ "$1" =~ ^[1-9][0-9]*$ ]] && [ "$1" -le "$2" ]; }
_cc_container_clean_field() { printf '%s' "$1" | tr '\t\r\n' '   ' | cut -c1-512; }
_cc_container_short_id() { printf '%s\n' "${1:0:12}"; }
_cc_container_runtime_command() { _cc_container_runtime_valid "$1" && command -v "$1"; }

# provider, client_state, access_state, detail.  Client detection and local
# runtime accessibility are intentionally distinct and never use sudo.
cc_container_provider_records_tsv() {
    local runtime program detail
    for runtime in docker podman; do
        if ! program="$(_cc_container_runtime_command "$runtime" 2>/dev/null)"; then
            printf '%s\tmissing\tunavailable\tclient executable not found\n' "$runtime"
        elif detail="$("$program" info --format '{{.ServerVersion}}' 2>/dev/null)" && [ -n "$detail" ]; then
            printf '%s\tpresent\tusable\tlocal runtime responded\n' "$runtime"
        else
            printf '%s\tpresent\trestricted\tclient present but local runtime is inaccessible\n' "$runtime"
        fi
    done
}

# Prints one selected provider.  A missing selector is accepted only when
# exactly one provider is usable; ambiguity and unavailable providers fail.
cc_container_provider_select() {
    local requested="${1:-}" runtime client access usable="" selected="" count=0
    [ -z "$requested" ] || _cc_container_runtime_valid "$requested" || return 2
    while IFS=$'\t' read -r runtime client access _; do
        [ "$access" = usable ] || continue
        if [ -n "$requested" ]; then [ "$runtime" = "$requested" ] && selected="$runtime"
        else usable="$runtime"; count=$((count + 1)); fi
    done < <(cc_container_provider_records_tsv)
    [ -n "$requested" ] && [ -n "$selected" ] && { printf '%s\n' "$selected"; return 0; }
    [ -z "$requested" ] && [ "$count" -eq 1 ] && { printf '%s\n' "$usable"; return 0; }
    return 1
}

_cc_container_runtime_require_usable() {
    local runtime="$1" client access records
    records="$(cc_container_provider_records_tsv)"
    while IFS=$'\t' read -r _ client access _; do
        [ "$client" = present ] && [ "$access" = usable ] && return 0
        return 1
    done < <(awk -F '\t' -v r="$runtime" '$1==r {print; exit}' <<<"$records")
    return 1
}

# provider, id, name, image, state, health, created_or_status, published_ports
_cc_container_records_for_runtime_tsv() {
    local runtime="$1" program id name image state status ports
    program="$(_cc_container_runtime_command "$runtime")" || return 1
    "$program" ps -a --format '{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.State}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null |
        while IFS=$'\t' read -r id name image state status ports; do
            [ -n "$id" ] || continue
            printf '%s\t%s\t%s\t%s\t%s\tunknown\t%s\t%s\n' "$runtime" "$(_cc_container_short_id "$id")" \
                "$(_cc_container_clean_field "$name")" "$(_cc_container_clean_field "$image")" \
                "$(_cc_container_clean_field "$state")" "$(_cc_container_clean_field "$status")" "$(_cc_container_clean_field "$ports")"
        done
}

cc_container_records_tsv() {
    local runtime="${1:-}" selected
    if [ -n "$runtime" ]; then
        _cc_container_runtime_valid "$runtime" || return 2
        _cc_container_runtime_require_usable "$runtime" || return 1
        _cc_container_records_for_runtime_tsv "$runtime"
        return
    fi
    while IFS=$'\t' read -r selected _ access _; do
        [ "$access" = usable ] && _cc_container_records_for_runtime_tsv "$selected"
    done < <(cc_container_provider_records_tsv)
}

# A deliberately narrow inspect format; no JSON, environment, labels, or
# arbitrary runtime metadata reaches callers.
cc_container_record_tsv() {
    [ "$#" -eq 2 ] || return 2
    local runtime="$1" target="$2" program id name image state health created ports
    _cc_container_runtime_valid "$runtime" && _cc_container_runtime_require_usable "$runtime" || return 1
    program="$(_cc_container_runtime_command "$runtime")" || return 1
    IFS=$'\t' read -r id name image state health created ports < <(
        # shellcheck disable=SC2016
        "$program" inspect --format '{{.Id}}\t{{.Name}}\t{{.Config.Image}}\t{{.State.Status}}\t{{if .State.Health}}{{.State.Health.Status}}{{else}}unknown{{end}}\t{{.State.StartedAt}}\t{{range $p, $v := .NetworkSettings.Ports}}{{$p}} {{range $v}}{{.HostIp}}:{{.HostPort}} {{end}}{{end}}' "$target" 2>/dev/null
    )
    [ -n "$id" ] || return 1
    name="${name#/}"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$runtime" "$(_cc_container_short_id "$id")" \
        "$(_cc_container_clean_field "$name")" "$(_cc_container_clean_field "$image")" \
        "$(_cc_container_clean_field "$state")" "$(_cc_container_clean_field "$health")" \
        "$(_cc_container_clean_field "$created")" "$(_cc_container_clean_field "$ports")"
}

_cc_container_since_valid() { [ -n "$1" ] && [ "${#1}" -le 64 ] && [[ "$1" != *$'\n'* ]] && [[ "$1" != *$'\r'* ]]; }
cc_container_logs() {
    [ "$#" -eq 4 ] || return 2
    local runtime="$1" target="$2" since="$3" limit="$4" program
    _cc_container_runtime_valid "$runtime" && _cc_container_runtime_require_usable "$runtime" || return 1
    _cc_container_since_valid "$since" && _cc_container_positive_limit "$limit" "$CC_CONTAINER_LOG_MAX" || return 2
    program="$(_cc_container_runtime_command "$runtime")" || return 1
    "$program" logs --timestamps --since "$since" --tail "$limit" "$target"
}

cc_container_action() {
    [ "$#" -eq 3 ] || return 2
    local runtime="$1" action="$2" target="$3" program
    _cc_container_runtime_valid "$runtime" && _cc_container_runtime_require_usable "$runtime" || return 1
    case "$action" in start|stop|restart) ;; *) return 2;; esac
    program="$(_cc_container_runtime_command "$runtime")" || return 1
    "$program" "$action" "$target"
}

# provider, id, published_port, listener_state, listener_owner. Publication
# and observed local listening state remain separate facts.
cc_container_port_correlations_tsv() {
    [ "$#" -eq 2 ] || return 2
    local runtime="$1" target="$2" record id ports entry hostport port transport socket_port socket_state owner _
    record="$(cc_container_record_tsv "$runtime" "$target")" || return
    IFS=$'\t' read -r _ id _ _ _ _ _ ports <<<"$record"
    cc_network_snapshot
    for entry in $ports; do
        hostport="${entry##*:}"; port="${hostport%%[^0-9]*}"
        [[ "$port" =~ ^[0-9]+$ ]] || continue
        transport="${entry%%/*}"; transport="${transport##*->}"; transport="${transport##*:}"; transport="${transport:-tcp}"
        socket_state=not-observed; owner=unknown
        while IFS=$'\t' read -r _ _ socket_port _ owner _; do
            [ "$socket_port" = "$port" ] && { socket_state=observed; break; }
        done <<<"$CC_NET_SOCKETS"
        printf '%s\t%s\t%s\t%s\t%s\n' "$runtime" "$id" "$port" "$socket_state" "$owner"
    done
}

# provider, id, mount_type, container_destination, host_mount_target. Sources
# are used only for local matching and are deliberately not emitted.
cc_container_storage_correlations_tsv() {
    [ "$#" -eq 2 ] || return 2
    local runtime="$1" target="$2" program id type source destination mount_target best=""
    _cc_container_runtime_require_usable "$runtime" || return 1
    program="$(_cc_container_runtime_command "$runtime")" || return 1
    id="$(cc_container_record_tsv "$runtime" "$target" | cut -f2)" || return 1
    cc_storage_snapshot
    while IFS=$'\t' read -r type source destination; do
        [ -n "$destination" ] || continue
        best=""
        while IFS=$'\t' read -r mount_target _; do
            case "$source" in "$mount_target"|"$mount_target"/*) [ "${#mount_target}" -gt "${#best}" ] && best="$mount_target";; esac
        done <<<"$CC_STORAGE_MOUNTS"
        printf '%s\t%s\t%s\t%s\t%s\n' "$runtime" "$id" "$(_cc_container_clean_field "$type")" "$(_cc_container_clean_field "$destination")" "${best:-unknown}"
    done < <("$program" inspect --format '{{range .Mounts}}{{.Type}}\t{{.Source}}\t{{.Destination}}{{"\\n"}}{{end}}' "$target" 2>/dev/null)
}
