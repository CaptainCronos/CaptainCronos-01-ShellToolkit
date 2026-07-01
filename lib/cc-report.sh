#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-report.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash date mkdir hostname uname
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Shared report directory, timestamp, and metadata helpers.
# ==============================================================================

cc_report_timestamp() {
    date +%Y%m%d-%H%M%S
}

cc_report_iso_timestamp() {
    date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z'
}

cc_report_root() {
    if [ -n "${CC_REPORT_DIR:-}" ]; then
        echo "$CC_REPORT_DIR"
    elif command -v cc_config_get >/dev/null 2>&1; then
        cc_config_get REPORT_DIR "$HOME/.captaincronos/reports"
    else
        echo "$HOME/.captaincronos/reports"
    fi
}

cc_report_make_dir() {
    local category="$1" name="$2" stamp dir
    stamp="$(cc_report_timestamp)"
    dir="$(cc_report_root)/$category/${name}-${stamp}"
    mkdir -p "$dir"
    echo "$dir"
}

cc_report_write_metadata() {
    local file="$1" title="$2" subject="${3:-}" host kernel host_id
    host="$(hostname 2>/dev/null || echo unknown)"
    kernel="$(uname -r 2>/dev/null || echo unknown)"
    host_id="${CC_HOST_ID:-unknown}"
    {
        echo "$title"
        echo "Generated: $(date)"
        echo "Generated ISO: $(cc_report_iso_timestamp)"
        [ -n "$subject" ] && echo "Subject: $subject"
        echo "Host ID: $host_id"
        echo "Host: $host"
        echo "Kernel: $kernel"
    } > "$file"
}

cc_report_append_kv() {
    local file="$1" key="$2" value="$3"
    printf '%s: %s\n' "$key" "$value" >> "$file"
}
