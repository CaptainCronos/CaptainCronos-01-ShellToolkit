#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-smart.sh
# Version     : reads VERSION
# Category    : Storage
# Requires    : bash awk smartctl
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Shared SMART collection, parsing, and summary helpers.
# ==============================================================================

cc_smart_collect() {
    local device="$1"
    sudo smartctl -a "$device" 2>/dev/null || smartctl -a "$device" 2>/dev/null || true
}

cc_smart_field_first() {
    local smart_text="$1" key="$2"
    printf '%s\n' "$smart_text" | awk -F: -v key="$key" '$0 ~ key {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit}'
}

cc_smart_attr_raw() {
    local smart_text="$1" names="$2"
    printf '%s\n' "$smart_text" | awk -v names="$names" '
        BEGIN { split(names, n, "|") }
        /^[ ]*[0-9]+/ {
            for (i in n) {
                if ($2 == n[i]) {
                    print $NF
                    exit
                }
            }
        }
    '
}

cc_smart_nvme_metric() {
    local smart_text="$1" label="$2"
    printf '%s\n' "$smart_text" | awk -F: -v label="$label" '$0 ~ label {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit}'
}

cc_smart_summary_from_text() {
    local device="$1" smart_text="$2"
    local model serial size health temp hours realloc pending uncorrect errors selftest result

    model="$(cc_smart_field_first "$smart_text" 'Device Model|Model Number|Product')"
    serial="$(cc_smart_field_first "$smart_text" 'Serial Number')"
    size="$(cc_smart_field_first "$smart_text" 'User Capacity|Namespace.*Size/Capacity|Total NVM Capacity')"
    health="$(cc_smart_field_first "$smart_text" 'SMART overall-health self-assessment test result|SMART Health Status')"
    temp="$(cc_smart_attr_raw "$smart_text" 'Temperature_Celsius|Airflow_Temperature_Cel')"
    [ -n "$temp" ] || temp="$(cc_smart_nvme_metric "$smart_text" 'Temperature')"
    hours="$(cc_smart_attr_raw "$smart_text" 'Power_On_Hours|Power_On_Hours_and_Msec')"
    [ -n "$hours" ] || hours="$(cc_smart_nvme_metric "$smart_text" 'Power On Hours')"
    realloc="$(cc_smart_attr_raw "$smart_text" 'Reallocated_Sector_Ct|Reallocated_Event_Count')"
    pending="$(cc_smart_attr_raw "$smart_text" 'Current_Pending_Sector')"
    uncorrect="$(cc_smart_attr_raw "$smart_text" 'Offline_Uncorrectable|Reported_Uncorrect')"
    errors="$(cc_smart_attr_raw "$smart_text" 'UDMA_CRC_Error_Count|Hardware_ECC_Recovered|Media_Wearout_Indicator')"

    [ -n "$model" ] || model="unknown"
    [ -n "$serial" ] || serial="unknown"
    [ -n "$size" ] || size="unknown"
    [ -n "$health" ] || health="unknown"
    [ -n "$temp" ] || temp="unknown"
    [ -n "$hours" ] || hours="unknown"
    [ -n "$realloc" ] || realloc="0"
    [ -n "$pending" ] || pending="0"
    [ -n "$uncorrect" ] || uncorrect="0"
    [ -n "$errors" ] || errors="0"

    selftest="$(printf '%s\n' "$smart_text" | awk '/Self-test execution status|Self-test routine in progress|SMART Self-test log/ {print; exit}')"
    [ -n "$selftest" ] || selftest="not reported"

    result="GOOD"
    case "$health" in
        *FAILED*|*BAD*|*FAIL*) result="FAIL" ;;
        unknown) result="UNKNOWN" ;;
    esac
    if [ "$realloc" != "0" ] || [ "$pending" != "0" ] || [ "$uncorrect" != "0" ]; then
        result="REVIEW"
    fi

    printf '%-12s %s\n' "Device:" "$device"
    printf '%-12s %s\n' "Model:" "$model"
    printf '%-12s %s\n' "Serial:" "$serial"
    printf '%-12s %s\n' "Size:" "$size"
    printf '%-12s %s\n' "Hours:" "$hours"
    printf '%-12s %s\n' "Temp:" "$temp"
    echo
    printf '%-12s %s\n' "SMART:" "$health"
    printf '%-12s %s\n' "Reallocated:" "$realloc"
    printf '%-12s %s\n' "Pending:" "$pending"
    printf '%-12s %s\n' "Uncorrect:" "$uncorrect"
    printf '%-12s %s\n' "Errors:" "$errors"
    echo
    printf '%-12s %s\n' "Self-test:" "$selftest"
    printf '%-12s %s\n' "Result:" "$result"
}

cc_smart_summary_for_device() {
    local device="$1" smart_text
    smart_text="$(cc_smart_collect "$device")"
    cc_smart_summary_from_text "$device" "$smart_text"
}

cc_smart_summary_value() {
    local file="$1" key="$2"
    awk -F: -v key="$key" '$1 ~ key {sub(/^[ \t]+/, "", $2); print $2; exit}' "$file"
}

cc_smart_extract_model() { cc_smart_summary_value "$1" '^Model'; }
cc_smart_extract_serial() { cc_smart_summary_value "$1" '^Serial'; }
cc_smart_extract_size() { cc_smart_summary_value "$1" '^Size'; }
cc_smart_extract_hours() { cc_smart_summary_value "$1" '^Hours'; }
cc_smart_extract_temp() { cc_smart_summary_value "$1" '^Temp'; }
cc_smart_extract_status() { cc_smart_summary_value "$1" '^SMART'; }
cc_smart_extract_result() { cc_smart_summary_value "$1" '^Result'; }

cc_smart_report_is_good() {
    local summary_file="$1"
    [ "$(cc_smart_extract_result "$summary_file")" = "GOOD" ]
}
