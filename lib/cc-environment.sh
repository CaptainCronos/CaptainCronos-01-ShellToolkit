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

if ! declare -F cc_config_host_id >/dev/null 2>&1; then
    _cc_environment_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_environment_lib_dir/cc-config.sh"
    unset _cc_environment_lib_dir
fi

cc_env_safe_id() { cc_config_safe_id "$1"; }

cc_env_default_host_id() {
    local raw
    raw="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo unknown-host)"
    cc_env_safe_id "$raw"
}

cc_env_home() {
    cc_config_dir
}

cc_env_host_id() {
    cc_config_host_id
}

cc_env_host_home() {
    cc_config_host_home
}

cc_env_config() {
    cc_config_host_file
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

cc_env_backup_dir() {
    echo "$(cc_env_home)/backups"
}

cc_env_bundle_dir() {
    echo "$(cc_env_home)/repo-bundles"
}

cc_env_plugin_dir() {
    echo "$(cc_env_host_home)/plugins"
}

cc_env_role() {
    cc_config_get HOST_ROLE workstation
}

cc_env_profile() {
    cc_config_get HOST_PROFILE default
}

cc_env_init_dirs() {
    local home host_home dir
    home="$(cc_env_home)"
    host_home="$(cc_env_host_home)"
    for dir in \
        "$home" "$home/hosts" "$host_home" \
        "$(cc_env_report_dir)" \
        "$(cc_env_asset_dir)" \
        "$(cc_env_asset_dir)/drives" \
        "$(cc_env_asset_dir)/systems" \
        "$(cc_env_asset_dir)/repositories" \
        "$(cc_env_asset_dir)/licenses" \
        "$(cc_env_asset_dir)/purchases" \
        "$(cc_env_cache_dir)" \
        "$(cc_env_log_dir)" \
        "$(cc_env_plugin_dir)"
    do
        _cc_config_ensure_private_dir "$dir" || return 1
    done
}

cc_env_write_default_config() {
    local config host_id
    config="$(cc_env_config)"
    host_id="$(cc_env_host_id)"
    if [ -e "$config" ] || [ -L "$config" ]; then
        return 0
    fi
    local content
    content="$(cat <<EOF_CONFIG
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
    )"$'\n'
    _cc_config_write_text "$config" "$content"
}

cc_env_export() {
    CC_HOME="$(cc_env_home)"
    CC_HOST_ID="$(cc_env_host_id)"
    CC_HOST_HOME="$(cc_env_host_home)"
    CC_CONFIG="$(cc_env_config)"
    CC_REPORT_DIR="$(cc_env_report_dir)"
    CC_ASSET_DIR="$(cc_env_asset_dir)"
    CC_CACHE_DIR="$(cc_env_cache_dir)"
    CC_LOG_DIR="$(cc_env_log_dir)"
    CC_BACKUP_DIR="$(cc_env_backup_dir)"
    CC_BUNDLE_DIR="$(cc_env_bundle_dir)"
    CC_PLUGIN_DIR="$(cc_env_plugin_dir)"
    CC_ROLE="$(cc_env_role)"
    CC_PROFILE="$(cc_env_profile)"
    export CC_HOME CC_HOST_ID CC_HOST_HOME CC_CONFIG CC_REPORT_DIR CC_ASSET_DIR
    export CC_CACHE_DIR CC_LOG_DIR CC_BACKUP_DIR CC_BUNDLE_DIR CC_PLUGIN_DIR CC_ROLE CC_PROFILE
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
    printf '%-16s %s\n' "Logs:" "$CC_LOG_DIR"
    printf '%-16s %s\n' "Backups:" "$CC_BACKUP_DIR"
    printf '%-16s %s\n' "Bundles:" "$CC_BUNDLE_DIR"
    printf '%-16s %s\n' "Plugins:" "$CC_PLUGIN_DIR"
}
