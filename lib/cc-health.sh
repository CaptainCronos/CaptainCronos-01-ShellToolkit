#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-health.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash awk ps date
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Compose bounded, read-only system and service health evidence.
# ==============================================================================

if [ -z "${CC_HEALTH_LOADED:-}" ]; then
    _cc_health_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    source "$_cc_health_lib_dir/cc-host.sh"
    source "$_cc_health_lib_dir/cc-kernel.sh"
    source "$_cc_health_lib_dir/cc-network.sh"
    source "$_cc_health_lib_dir/cc-storage.sh"
    source "$_cc_health_lib_dir/cc-services.sh"
    unset _cc_health_lib_dir
    CC_HEALTH_LOADED=1
fi

cc_health_policy_file() {
    local lib_dir root
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    root="${TOOLKIT_ROOT:-${PROJECT_ROOT:-${lib_dir}/..}}"
    printf '%s/config/health-policy.conf\n' "$root"
}

cc_health_policy_validate() {
    local file="${1:-$(cc_health_policy_file)}" line=0 selector_type selector scope unit expectation severity extra
    [ -f "$file" ] || return 1
    while IFS= read -r line_text || [ -n "$line_text" ]; do
        line=$((line + 1))
        case "$line_text" in ''|'#'*) continue;; esac
        IFS='|' read -r selector_type selector scope unit expectation severity extra <<<"$line_text"
        [ -z "$extra" ] && [ -n "$selector" ] && [ -n "$unit" ] || return 2
        case "$selector_type" in role|profile) ;; *) return 2;; esac
        case "$scope" in system|user) ;; *) return 2;; esac
        case "$expectation" in present|active|enabled|absent) ;; *) return 2;; esac
        case "$severity" in WARN|FAIL) ;; *) return 2;; esac
    done < "$file"
}

# TSV: selector_type, selector, scope, unit, expectation, severity
cc_health_policy_records_tsv() {
    local file="${1:-$(cc_health_policy_file)}" selector_type selector scope unit expectation severity role profile
    cc_health_policy_validate "$file" || return $?
    role="$(cc_env_role)"; profile="$(cc_env_profile)"
    while IFS='|' read -r selector_type selector scope unit expectation severity; do
        if { [ "$selector_type" = role ] && [ "$selector" = "$role" ]; } || { [ "$selector_type" = profile ] && [ "$selector" = "$profile" ]; }; then
            printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$selector_type" "$selector" "$scope" "$unit" "$expectation" "$severity"
        fi
    done < <(awk 'NF && $0 !~ /^#/' "$file")
}

_cc_health_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
_cc_health_proc_path() { printf '%s\n' "${CC_HEALTH_PROC_ROOT:-/proc}/$1"; }

# TSV: name, value, unit, state, source, observed_at
cc_health_resources_tsv() {
    local now load meminfo uptime total available swap_total swap_free swap_used processes zombies reboot state thermal_root zone temp trip_type trip_temp trip
    now="$(_cc_health_now)"
    load="$(awk 'NR==1 {print; exit}' "$(_cc_health_proc_path loadavg)" 2>/dev/null || true)"
    if [ -n "$load" ]; then set -- $load; printf 'load_1m\t%s\tload\tobserved\t/proc/loadavg\t%s\n' "${1:-unknown}" "$now"; printf 'load_5m\t%s\tload\tobserved\t/proc/loadavg\t%s\n' "${2:-unknown}" "$now"; printf 'load_15m\t%s\tload\tobserved\t/proc/loadavg\t%s\n' "${3:-unknown}" "$now"; else printf 'load_1m\tunknown\tload\tunknown\t/proc/loadavg\t%s\n' "$now"; fi
    uptime="$(awk '{print $1; exit}' "$(_cc_health_proc_path uptime)" 2>/dev/null || true)"; printf 'uptime\t%s\tseconds\t%s\t/proc/uptime\t%s\n' "${uptime:-unknown}" "$([ -n "$uptime" ] && printf observed || printf unknown)" "$now"
    meminfo="$(_cc_health_proc_path meminfo)"
    total="$(awk '/^MemTotal:/{print $2; exit}' "$meminfo" 2>/dev/null || true)"; available="$(awk '/^MemAvailable:/{print $2; exit}' "$meminfo" 2>/dev/null || true)"; swap_total="$(awk '/^SwapTotal:/{print $2; exit}' "$meminfo" 2>/dev/null || true)"; swap_free="$(awk '/^SwapFree:/{print $2; exit}' "$meminfo" 2>/dev/null || true)"
    [ -n "$swap_total" ] && [ -n "$swap_free" ] && swap_used=$((swap_total - swap_free)) || swap_used=unknown
    for name_value in "memory_total:$total" "memory_available:$available" "swap_total:$swap_total" "swap_used:$swap_used"; do printf '%s\t%s\tkib\t%s\t/proc/meminfo\t%s\n' "${name_value%%:*}" "${name_value#*:}" "$([ "${name_value#*:}" != unknown ] && printf observed || printf unknown)" "$now"; done
    processes="$(ps -e -o pid= 2>/dev/null | awk 'END {print NR+0}')"; zombies="$(ps -e -o stat= 2>/dev/null | awk '$1 ~ /^Z/ {n++} END {print n+0}')"
    printf 'process_count\t%s\tcount\t%s\tps\t%s\n' "${processes:-unknown}" "$([ -n "$processes" ] && printf observed || printf unknown)" "$now"; printf 'zombie_count\t%s\tcount\t%s\tps\t%s\n' "${zombies:-unknown}" "$([ -n "$zombies" ] && printf observed || printf unknown)" "$now"
    reboot="$(_cc_kernel_reboot_state 2>/dev/null || printf unknown)"; printf 'reboot_state\t%s\tstate\tobserved\tkernel\t%s\n' "$reboot" "$now"
    thermal_root="${CC_HEALTH_THERMAL_ROOT:-/sys/class/thermal}"; state=unknown
    for zone in "$thermal_root"/thermal_zone*; do
        [ -r "$zone/temp" ] || continue
        temp="$(awk 'NR==1 {print; exit}' "$zone/temp" 2>/dev/null || true)"; [ -n "$temp" ] || continue
        state=observed
        for trip in "$zone"/trip_point_*_type; do
            [ -r "$trip" ] || continue
            trip_type="$(awk 'NR==1 {print; exit}' "$trip" 2>/dev/null || true)"
            case "$trip_type" in critical|hot) ;; *) continue;; esac
            trip_temp="$(awk 'NR==1 {print; exit}' "${trip%_type}_temp" 2>/dev/null || true)"
            [[ "$temp" =~ ^[0-9]+$ && "$trip_temp" =~ ^[0-9]+$ ]] && [ "$temp" -ge "$trip_temp" ] && state=critical
        done
        printf 'thermal\t%s\tmillicelsius\t%s\t%s\t%s\n' "$temp" "$state" "$zone" "$now"
    done
    [ "$state" != unknown ] || printf 'thermal\tunknown\tmillicelsius\tunknown\tsysfs\t%s\n' "$now"
}

cc_health_findings_tsv() {
    local now state code message source observed active load enabled restarts expectation severity classification
    now="$(_cc_health_now)"
    while IFS=$'\t' read -r resource_name value _ resource_state source observed; do
        case "$resource_name:$value:$resource_state" in zombie_count:[1-9]*:*) printf 'WARN\tZOMBIE_PROCESSES\tresource\thost\t%s zombie process(es) observed\t%s\t%s\n' "$value" "$source" "$observed";; reboot_state:required:*) printf 'WARN\tREBOOT_REQUIRED\tsystem\thost\treboot is required\tkernel\t%s\n' "$observed";; thermal:*:critical) printf 'WARN\tTHERMAL_PRESSURE\tresource\thost\tthermal zone reached an authoritative critical or hot trip point\t%s\t%s\n' "$source" "$observed";; esac
    done < <(cc_health_resources_tsv)
    while IFS=$'\t' read -r scope unit description load active sub enabled _ _ restarts collection where what; do
        [ "$collection" = available ] || { printf 'SKIP\tCOLLECTION_RESTRICTED\tcollection\t%s\tservice inspection is %s\tservice-manager\t%s\n' "$unit" "$collection" "$now"; continue; }
        classification="$(_cc_service_failed_unit_classification "$scope" "$unit" "$description" "$load" "$active" "$sub" "$where" "$what")"
        [ "$active" != failed ] || [ "$classification" = ignored-stale-snap ] || printf 'FAIL\tSERVICE_FAILED\tservice\t%s\tservice is in failed state\tservice-manager\t%s\n' "$unit" "$now"
        [ "$enabled" != masked ] || printf 'WARN\tSERVICE_MASKED_UNEXPECTED\tservice\t%s\tservice unit is masked\tservice-manager\t%s\n' "$unit" "$now"
        [[ "$restarts" =~ ^[1-9][0-9]*$ ]] && printf 'WARN\tSERVICE_RESTART_LOOP\tservice\t%s\tservice restart count is %s\tservice-manager\t%s\n' "$unit" "$restarts" "$now"
    done < <(_cc_service_failed_records_tsv system 2>/dev/null || true)
    while IFS=$'\t' read -r _ _ scope unit expectation severity; do
        if [[ "$unit" == *.timer ]]; then IFS=$'\t' read -r _ _ _ _ _ active enabled collection < <(_cc_timer_record_tsv "$scope" "$unit"); else IFS=$'\t' read -r _ _ _ load active _ enabled _ _ _ collection < <(_cc_service_record_tsv "$scope" "$unit"); fi
        case "$expectation" in present) [ "${load:-loaded}" != not-found ] || printf '%s\tSERVICE_EXPECTED_PRESENT\tservice\t%s\tpolicy expects unit to be present\thealth-policy\t%s\n' "$severity" "$unit" "$now";; active) [ "$active" = active ] || printf '%s\tSERVICE_EXPECTED_ACTIVE\tservice\t%s\tpolicy expects unit active; observed %s\thealth-policy\t%s\n' "$severity" "$unit" "${active:-unknown}" "$now";; enabled) case "$enabled" in enabled|enabled-runtime|linked|linked-runtime|alias) ;; *) printf '%s\t%s\t%s\t%s\tpolicy expects unit enabled; observed %s\thealth-policy\t%s\n' "$severity" "$([ "$unit" = "${unit%.timer}" ] && printf SERVICE_EXPECTED_ENABLED || printf TIMER_EXPECTED_ENABLED)" "$([ "$unit" = "${unit%.timer}" ] && printf service || printf timer)" "$unit" "${enabled:-unknown}" "$now";; esac;; absent) [ "${load:-not-found}" = not-found ] || printf '%s\tSERVICE_EXPECTED_ABSENT\tservice\t%s\tpolicy expects unit absent\thealth-policy\t%s\n' "$severity" "$unit" "$now";; esac
    done < <(cc_health_policy_records_tsv 2>/dev/null || true)
    _cc_kernel_snapshot_capture "${KEEP_COUNT:-2}" >/dev/null 2>&1 || true
    while IFS=$'\t' read -r state code message; do [ -n "$state" ] && printf '%s\t%s\tkernel\thost\t%s\tkernel\t%s\n' "$state" "$code" "$message" "$now"; done < <(_cc_kernel_snapshot_findings 2>/dev/null || true)
    while IFS=$'\t' read -r state code _ message; do [ -n "$state" ] && printf '%s\t%s\tnetwork\thost\t%s\tnetwork\t%s\n' "$state" "$code" "$message" "$now"; done < <(cc_network_local_findings_tsv 2>/dev/null || true)
    cc_storage_local_findings_tsv 2>/dev/null || true
}

cc_health_snapshot_reset() { CC_HEALTH_SNAPSHOT_READY=0; CC_HEALTH_RESOURCES=''; CC_HEALTH_FINDINGS=''; }
cc_health_snapshot() { [ "${CC_HEALTH_SNAPSHOT_READY:-0}" -eq 1 ] && return 0; CC_HEALTH_RESOURCES="$(cc_health_resources_tsv)"; CC_HEALTH_FINDINGS="$(cc_health_findings_tsv)"; export CC_HEALTH_RESOURCES CC_HEALTH_FINDINGS; CC_HEALTH_SNAPSHOT_READY=1; }

cc_health_diagnose_tsv() {
    local since="${1:-24 hours ago}" limit="${2:-200}" unit
    [[ "$limit" =~ ^[1-9][0-9]*$ ]] || return 2
    while IFS=$'\t' read -r scope unit description load active sub _ _ _ _ collection where what; do [ "$collection" = available ] && [ "$active" = failed ] && [ "$(_cc_service_failed_unit_classification "$scope" "$unit" "$description" "$load" "$active" "$sub" "$where" "$what")" != ignored-stale-snap ] && _cc_log_unit system "$unit" "$since" "$limit" 2>/dev/null || true; done < <(_cc_service_failed_records_tsv system 2>/dev/null || true)
}
