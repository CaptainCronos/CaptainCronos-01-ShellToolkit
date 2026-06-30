#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-environment.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash hostname mkdir
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Define portable Captain Cronos host identity and environment paths.
# ==============================================================================

cc_env_safe_id() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

cc_env_default_host_id() {
    local raw
    raw="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo unknown-host)"
    cc_env_safe_id "$raw"
}

cc_env_home() {
    echo "${CC_HOME:-$HOME/.captaincronos}"
}

cc_env_host_id() {
    if [ -n "${CC_HOST_ID:-}" ]; then
        cc_env_safe_id "$CC_HOST_ID"
        return 0
    fi

    local root config id
    root="$(cc_env_home)"
    config="$root/config"
    if [ -f "$config" ]; then
        id="$(awk -F= '$1=="HOST_ID" {gsub(/^"|"$/, "", $2); print $2; exit}' "$config" 2>/dev/null || true)"
        if [ -n "$id" ]; then
            cc_env_safe_id "$id"
            return 0
        fi
    fi

    cc_env_default_host_id
}

cc_env_host_home() {
    echo "$(cc_env_home)/hosts/$(cc_env_host_id)"
}

cc_env_config() {
    echo "$(cc_env_host_home)/config"
}

cc_env_report_dir() {
    echo "$(cc_env_host_home)/reports"
}

cc_env_asset_dir() {
    echo "$(cc_env_host_home)/assets"
}

cc_env_cache_dir() {
    echo "$(cc_env_host_home)/cache"
}

cc_env_log_dir() {
    echo "$(cc_env_host_home)/logs"
}

cc_env_plugin_dir() {
    echo "$(cc_env_host_home)/plugins"
}

cc_env_role() {
    local config role
    config="$(cc_env_config)"
    role="$(awk -F= '$1=="HOST_ROLE" {gsub(/^"|"$/, "", $2); print $2; exit}' "$config" 2>/dev/null || true)"
    echo "${role:-workstation}"
}

cc_env_profile() {
    local config profile
    config="$(cc_env_config)"
    profile="$(awk -F= '$1=="HOST_PROFILE" {gsub(/^"|"$/, "", $2); print $2; exit}' "$config" 2>/dev/null || true)"
    echo "${profile:-default}"
}

cc_env_init_dirs() {
    local home host_home
    home="$(cc_env_home)"
    host_home="$(cc_env_host_home)"
    mkdir -p \
        "$home/hosts" \
        "$host_home" \
        "$(cc_env_report_dir)" \
        "$(cc_env_asset_dir)/drives" \
        "$(cc_env_asset_dir)/systems" \
        "$(cc_env_asset_dir)/repositories" \
        "$(cc_env_asset_dir)/licenses" \
        "$(cc_env_asset_dir)/purchases" \
        "$(cc_env_cache_dir)" \
        "$(cc_env_log_dir)" \
        "$(cc_env_plugin_dir)"
}

cc_env_write_default_config() {
    local config host_id
    config="$(cc_env_config)"
    host_id="$(cc_env_host_id)"
    [ -f "$config" ] && return 0
    cat > "$config" <<EOF_CONFIG
# Captain Cronos host configuration
HOST_ID="$host_id"
HOST_ROLE="workstation"
HOST_PROFILE="default"
REPO_ROOT="$HOME/GitHub"
REPORT_DIR="$(cc_env_report_dir)"
ASSET_DIR="$(cc_env_asset_dir)"
PLUGIN_DIR="$(cc_env_plugin_dir)"
CACHE_DIR="$(cc_env_cache_dir)"
LOG_DIR="$(cc_env_log_dir)"
EDITOR="nano"
AUTO_DOCS="no"
AUTO_PUSH="no"
EOF_CONFIG
}

cc_env_export() {
    export CC_HOME="$(cc_env_home)"
    export CC_HOST_ID="$(cc_env_host_id)"
    export CC_HOST_HOME="$(cc_env_host_home)"
    export CC_CONFIG="$(cc_env_config)"
    export CC_REPORT_DIR="$(cc_env_report_dir)"
    export CC_ASSET_DIR="$(cc_env_asset_dir)"
    export CC_CACHE_DIR="$(cc_env_cache_dir)"
    export CC_LOG_DIR="$(cc_env_log_dir)"
    export CC_PLUGIN_DIR="$(cc_env_plugin_dir)"
    export CC_ROLE="$(cc_env_role)"
    export CC_PROFILE="$(cc_env_profile)"
}

cc_env_summary() {
    cc_env_export
    printf '%-16s %s\n' "CC_HOME:" "$CC_HOME"
    printf '%-16s %s\n' "Host ID:" "$CC_HOST_ID"
    printf '%-16s %s\n' "Host Home:" "$CC_HOST_HOME"
    printf '%-16s %s\n' "Role:" "$CC_ROLE"
    printf '%-16s %s\n' "Profile:" "$CC_PROFILE"
    printf '%-16s %s\n' "Config:" "$CC_CONFIG"
    printf '%-16s %s\n' "Reports:" "$CC_REPORT_DIR"
    printf '%-16s %s\n' "Assets:" "$CC_ASSET_DIR"
    printf '%-16s %s\n' "Plugins:" "$CC_PLUGIN_DIR"
}
