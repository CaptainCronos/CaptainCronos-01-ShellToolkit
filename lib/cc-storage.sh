#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-storage.sh
# Version     : reads VERSION
# Category    : Storage
# Requires    : bash lsblk awk find smartctl
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

cc_storage_print_device_table_header() {
    printf '%-12s %-22s %-20s %-8s %-8s %-10s %s\n' "Device" "Model" "Serial" "Size" "Tran" "SMART" "Mounts"
    printf '%-12s %-22s %-20s %-8s %-8s %-10s %s\n' "------" "-----" "------" "----" "----" "-----" "------"
}

cc_storage_lsblk_inventory() {
    lsblk -dn -o NAME,MODEL,SERIAL,SIZE,TRAN 2>/dev/null | awk '{print}'
}

cc_storage_mounts_for_device() {
    local name="$1"
    lsblk -nr -o NAME,MOUNTPOINT "/dev/$name" 2>/dev/null | awk '$2 != "" {print $2}' | paste -sd, - 2>/dev/null
}

cc_storage_smart_status_for_device() {
    local device="$1"
    if command -v smartctl >/dev/null 2>&1; then
        sudo smartctl -H "$device" 2>/dev/null | awk -F: '/SMART overall-health|SMART Health Status/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' || true
    fi
}
