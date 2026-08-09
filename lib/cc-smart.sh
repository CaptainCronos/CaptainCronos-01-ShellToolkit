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

cc_smart_version() {
    if command -v cc_version >/dev/null 2>&1; then
        cc_version
    elif [ -f "${PROJECT_ROOT:-}/VERSION" ]; then
        cat "${PROJECT_ROOT:-}/VERSION"
    else
        echo "unknown"
    fi
}

cc_smart_loaded() {
    command -v cc_smart_collect >/dev/null 2>&1 && \
    command -v cc_smart_summary_from_text >/dev/null 2>&1 && \
    command -v cc_smart_extract_result >/dev/null 2>&1
}

cc_smart_dependencies() {
    echo "bash awk smartctl"
}

cc_smart_device_candidate() {
    local name="${1##*/}"
    case "$name" in
        zram*|ram*) return 1 ;;
        *) return 0 ;;
    esac
}

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
                    print $10
                    exit
                }
            }
        }
    '
}

cc_smart_attr_normalized() {
    local smart_text="$1" names="$2"
    printf '%s\n' "$smart_text" | awk -v names="$names" '
        BEGIN { split(names, n, "|") }
        /^[ ]*[0-9]+/ {
            for (i in n) {
                if ($2 == n[i] && $4 ~ /^[0-9]+$/) {
                    print $4 + 0
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

cc_smart_temperature() {
    awk '
        /^[ ]*[0-9]+[ ]+(Temperature_Celsius|Airflow_Temperature_Cel)[ ]/ {
            if ($10 ~ /^-?[0-9]+$/) { print $10 "C"; found=1; exit }
        }
        /^(Current Drive Temperature|Composite Temperature|Temperature):/ {
            for (i=2; i<=NF; i++) {
                value=$i
                gsub(/,/, "", value)
                if (value ~ /^-?[0-9]+$/) { print value "C"; found=1; exit }
            }
        }
        END {if (!found) print "--"}
    '
}

cc_smart_power_on_hours() {
    awk '
        /^[ ]*[0-9]+[ ]+(Power_On_Hours|Power_On_Hours_and_Msec)[ ]/ {
            value=$10
            sub(/[^0-9].*$/, "", value)
            if (value ~ /^[0-9]+$/) { print value; found=1; exit }
        }
        /^Power On Hours:|number of hours powered up/ {
            for (i=2; i<=NF; i++) {
                value=$i
                gsub(/,/, "", value)
                sub(/[^0-9].*$/, "", value)
                if (value ~ /^[0-9]+$/) { print value; found=1; exit }
            }
        }
        END {if (!found) print "--"}
    '
}

cc_smart_life_remaining() {
    awk '
        /^Percentage Used:/ {
            value=$3
            gsub(/%/, "", value)
            if (value ~ /^[0-9]+$/) {
                value += 0
                if (value >= 0 && value <= 100) {
                    print (100-value) "%"
                    found=1
                    exit
                }
            }
        }
        /^[ ]*[0-9]+[ ]+(Percent_Lifetime_Remain|Media_Wearout_Indicator|SSD_Life_Left)[ ]/ {
            value=$4
            if (value ~ /^[0-9]+$/) {
                value += 0
                if (value >= 0 && value <= 100) {
                    print value "%"
                    found=1
                    exit
                }
            }
        }
        END {if (!found) print "--"}
    '
}

cc_smart_summary_from_text() {
    local device="$1" smart_text="$2"
    local model serial size health temp hours realloc pending uncorrect errors selftest result

    model="$(cc_smart_field_first "$smart_text" 'Device Model|Model Number|Product')"
    serial="$(cc_smart_field_first "$smart_text" 'Serial Number')"
    size="$(cc_smart_field_first "$smart_text" 'User Capacity|Namespace.*Size/Capacity|Total NVM Capacity')"
    health="$(cc_smart_field_first "$smart_text" 'SMART overall-health self-assessment test result|SMART Health Status')"
    temp="$(printf '%s\n' "$smart_text" | cc_smart_temperature)"
    hours="$(printf '%s\n' "$smart_text" | cc_smart_power_on_hours)"
    realloc="$(cc_smart_attr_raw "$smart_text" 'Reallocated_Sector_Ct|Reallocated_Event_Count')"
    pending="$(cc_smart_attr_raw "$smart_text" 'Current_Pending_Sector')"
    uncorrect="$(cc_smart_attr_raw "$smart_text" 'Offline_Uncorrectable|Reported_Uncorrect')"
    errors="$(cc_smart_attr_raw "$smart_text" 'UDMA_CRC_Error_Count|Hardware_ECC_Recovered|Media_Wearout_Indicator')"

    [ -n "$model" ] || model="unknown"
    [ -n "$serial" ] || serial="unknown"
    [ -n "$size" ] || size="unknown"
    [ -n "$health" ] || health="unknown"
    [ "$temp" != "--" ] || temp="unknown"
    [ "$hours" != "--" ] || hours="unknown"
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
