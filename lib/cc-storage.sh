#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-storage.sh
# Version     : reads VERSION
# Category    : Storage
# Requires    : bash lsblk awk find smartctl grep paste
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Shared storage device discovery, SMART, and workflow helpers.
# ==============================================================================

cc_storage_device_exists() {
    local device="$1"
    [ -n "$device" ] && [ -e "$device" ]
}

cc_storage_require_device() {
    local device="$1"
    if ! cc_storage_device_exists "$device"; then
        cc_error "Device not found: $device"
        return 1
    fi
}

cc_storage_require_smartctl() {
    if ! command -v smartctl >/dev/null 2>&1; then
        cc_error "smartctl not found. Install smartmontools."
        return 127
    fi
}

cc_storage_run_smartctl() {
    if sudo -n true 2>/dev/null; then
        sudo smartctl "$@"
    else
        smartctl "$@"
    fi
}

cc_storage_device_basename() {
    basename "$1" | tr '/' '_'
}

cc_storage_report_root() {
    if [ -n "${CC_REPORT_DIR:-}" ]; then
        echo "$CC_REPORT_DIR/drives"
    elif command -v cc_config_get >/dev/null 2>&1; then
        echo "$(cc_config_get REPORT_DIR "$HOME/.captaincronos/reports")/drives"
    else
        echo "$HOME/.captaincronos/reports/drives"
    fi
}

cc_storage_report_dir_for_device() {
    local device="$1" stamp safe_name
    stamp="$(date +%Y%m%d-%H%M%S)"
    safe_name="$(cc_storage_device_basename "$device")"
    echo "$(cc_storage_report_root)/${safe_name}-${stamp}"
}

cc_storage_mounts_for_device() {
    local device="$1"
    lsblk -nr -o MOUNTPOINT "$device" 2>/dev/null | grep -v '^$' | paste -sd ',' - 2>/dev/null
}

cc_storage_smart_text_for_device() {
    local device="$1"
    if command -v smartctl >/dev/null 2>&1; then
        sudo smartctl -a "$device" 2>/dev/null || smartctl -a "$device" 2>/dev/null || true
    fi
}

cc_storage_inventory_rows() {
    lsblk -dn -o NAME,MODEL,SERIAL,SIZE,TRAN,TYPE 2>/dev/null | while read -r name model serial size tran type; do
        [ "$type" = "disk" ] || continue
        local dev smart_text health hours temp mounts
        dev="/dev/$name"
        smart_text="$(cc_storage_smart_text_for_device "$dev")"
        health="$(cc_smart_field_first "$smart_text" 'SMART overall-health self-assessment test result|SMART Health Status')"
        hours="$(cc_smart_attr_raw "$smart_text" 'Power_On_Hours|Power_On_Hours_and_Msec')"
        [ -n "$hours" ] || hours="$(cc_smart_nvme_metric "$smart_text" 'Power On Hours')"
        temp="$(cc_smart_attr_raw "$smart_text" 'Temperature_Celsius|Airflow_Temperature_Cel')"
        [ -n "$temp" ] || temp="$(cc_smart_nvme_metric "$smart_text" 'Temperature')"
        mounts="$(cc_storage_mounts_for_device "$dev")"
        [ -n "$health" ] || health="unknown"
        [ -n "$hours" ] || hours="unknown"
        [ -n "$temp" ] || temp="unknown"
        [ -n "$mounts" ] || mounts="-"
        [ -n "$tran" ] || tran="-"
        [ -n "$model" ] || model="unknown"
        [ -n "$serial" ] || serial="unknown"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$dev" "$model" "$serial" "$size" "$tran" "$health" "$hours" "$mounts"
    done
}

cc_storage_inventory_table() {
    printf '%-12s %-22s %-20s %-8s %-8s %-10s %-10s %s\n' "Device" "Model" "Serial" "Size" "Tran" "SMART" "Hours" "Mounts"
    printf '%-12s %-22s %-20s %-8s %-8s %-10s %-10s %s\n' "------" "-----" "------" "----" "----" "-----" "-----" "------"
    cc_storage_inventory_rows | while IFS=$'\t' read -r dev model serial size tran health hours mounts; do
        printf '%-12s %-22s %-20s %-8s %-8s %-10s %-10s %s\n' "$dev" "$model" "$serial" "$size" "$tran" "$health" "$hours" "$mounts"
    done
}

cc_storage_inventory_csv() {
    echo "device,model,serial,size,transport,smart,hours,mounts"
    cc_storage_inventory_rows | while IFS=$'\t' read -r dev model serial size tran health hours mounts; do
        printf '"%s","%s","%s","%s","%s","%s","%s","%s"\n' "$dev" "$model" "$serial" "$size" "$tran" "$health" "$hours" "$mounts"
    done
}

cc_storage_inventory_markdown() {
    echo "| Device | Model | Serial | Size | Transport | SMART | Hours | Mounts |"
    echo "|---|---|---|---|---|---|---|---|"
    cc_storage_inventory_rows | while IFS=$'\t' read -r dev model serial size tran health hours mounts; do
        echo "| $dev | $model | $serial | $size | $tran | $health | $hours | $mounts |"
    done
}

cc_storage_inventory_output() {
    local format="${1:-table}"
    case "$format" in
        table) cc_storage_inventory_table ;;
        csv) cc_storage_inventory_csv ;;
        markdown) cc_storage_inventory_markdown ;;
        *) cc_error "Unknown inventory format: $format"; return 2 ;;
    esac
}

cc_storage_test_status() {
    local device="$1" out
    cc_storage_require_smartctl || return $?
    cc_storage_require_device "$device" || return $?
    out="$(cc_storage_run_smartctl -a "$device" 2>/dev/null || true)"
    printf '%-12s %s\n' "Device:" "$device"
    echo
    printf '%s\n' "$out" | awk '
        /Self-test execution status/ {print; getline; if ($0 ~ /%/) print; next}
        /Self-test routine in progress/ {print; next}
        /No self-tests have been logged/ {print; next}
        /SMART Self-test log/ {show=1; print; next}
        show && /^#/ {print; count++; if (count >= 5) exit}
    '
}

cc_storage_test_start() {
    local device="$1" kind="$2" out estimate
    cc_storage_require_smartctl || return $?
    cc_storage_require_device "$device" || return $?
    cc_log "Starting SMART $kind self-test on $device"
    out="$(cc_storage_run_smartctl -t "$kind" "$device" 2>&1 || true)"
    printf '%s\n' "$out"
    estimate="$(printf '%s\n' "$out" | grep -Ei 'Please wait|completion|after' || true)"
    echo
    if [ -n "$estimate" ]; then
        printf '%-12s %s\n' "Estimate:" "$estimate"
    fi
    printf '%-12s %s\n' "Check:" "cc drive-test status $device"
}
