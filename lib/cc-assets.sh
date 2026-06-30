#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-assets.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash find mkdir date
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Shared host-scoped asset inventory helper functions.
# ==============================================================================

cc_assets_root() {
    if [ -n "${CAPTAIN_CRONOS_ASSETS_DIR:-}" ]; then
        echo "$CAPTAIN_CRONOS_ASSETS_DIR"
    elif [ -n "${CC_ASSET_DIR:-}" ]; then
        echo "$CC_ASSET_DIR"
    elif command -v cc_env_asset_dir >/dev/null 2>&1; then
        cc_env_asset_dir
    else
        echo "$HOME/.captaincronos/assets"
    fi
}

cc_assets_init() {
    local root
    root="$(cc_assets_root)"
    mkdir -p \
        "$root/drives" \
        "$root/systems" \
        "$root/repositories" \
        "$root/licenses" \
        "$root/purchases" \
        "$root/.history/drives" \
        "$root/.history/systems" \
        "$root/.history/repositories" \
        "$root/.history/licenses" \
        "$root/.history/purchases"
}

cc_asset_dir() {
    local type="$1"
    echo "$(cc_assets_root)/$type"
}

cc_asset_history_dir() {
    local type="$1"
    echo "$(cc_assets_root)/.history/$type"
}

cc_asset_list() {
    local type="$1"
    cc_assets_init
    find "$(cc_asset_dir "$type")" -maxdepth 1 -type f 2>/dev/null | sort
}

cc_asset_safe_name() {
    printf '%s' "$1" | tr '/: ' '___' | sed 's/[^A-Za-z0-9._-]/_/g'
}

cc_asset_file() {
    local type="$1" name="$2" safe
    safe="$(cc_asset_safe_name "$name")"
    case "$safe" in
        *.yaml) echo "$(cc_asset_dir "$type")/$safe" ;;
        *) echo "$(cc_asset_dir "$type")/$safe.yaml" ;;
    esac
}

cc_asset_history_file() {
    local type="$1" name="$2" safe
    safe="$(cc_asset_safe_name "$name")"
    safe="${safe%.yaml}"
    echo "$(cc_asset_history_dir "$type")/$safe.log"
}

cc_asset_timestamp() {
    date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z'
}

cc_asset_append_history() {
    local type="$1" name="$2" action="$3" note="${4:-}" file ts
    cc_assets_init
    file="$(cc_asset_history_file "$type" "$name")"
    ts="$(cc_asset_timestamp)"
    printf '%s | %s | %s\n' "$ts" "$action" "$note" >> "$file"
}
