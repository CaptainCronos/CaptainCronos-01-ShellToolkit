#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-assets.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash find mkdir
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Shared asset inventory helper functions.
# ==============================================================================

cc_assets_root() {
    echo "${CAPTAIN_CRONOS_ASSETS_DIR:-$HOME/.captaincronos/assets}"
}

cc_assets_init() {
    local root
    root="$(cc_assets_root)"
    mkdir -p "$root/drives" "$root/systems" "$root/repositories" "$root/licenses" "$root/purchases"
}

cc_asset_dir() {
    local type="$1"
    echo "$(cc_assets_root)/$type"
}

cc_asset_list() {
    local type="$1"
    cc_assets_init
    find "$(cc_asset_dir "$type")" -maxdepth 1 -type f 2>/dev/null | sort
}

cc_asset_safe_name() {
    printf '%s' "$1" | tr '/: ' '___' | sed 's/[^A-Za-z0-9._-]/_/g'
}
