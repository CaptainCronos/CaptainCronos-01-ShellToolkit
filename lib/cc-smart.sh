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
# Purpose     : Shared SMART summary parsing helpers.
# ==============================================================================

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
