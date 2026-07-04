#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-dev-updates.sh
# Version     : reads VERSION
# Category    : Maintenance
# Requires    : bash
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Shared developer package manager update reporting helpers.
# ==============================================================================

cc_dev_update_managers() {
    printf '%s\n' npm pipx pip cargo go gem
}

cc_dev_update_selector_valid() {
    case "${1:-all}" in
        all|npm|pipx|pip|cargo|go|gem)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

cc_dev_update_selected_managers() {
    local selector="${1:-all}"

    if [ "$selector" = "all" ]; then
        cc_dev_update_managers
        return 0
    fi

    cc_dev_update_selector_valid "$selector" || return 1
    printf '%s\n' "$selector"
}

cc_dev_update_truthy() {
    case "${1:-}" in
        1|yes|Yes|YES|true|True|TRUE|on|On|ON|enabled|Enabled|ENABLED)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

cc_dev_update_installed() {
    case "$1" in
        npm|pipx|cargo|go|gem)
            command -v "$1" >/dev/null 2>&1
            ;;
        pip)
            command -v pip >/dev/null 2>&1 ||
                command -v pip3 >/dev/null 2>&1 ||
                { command -v python3 >/dev/null 2>&1 && python3 -m pip --version >/dev/null 2>&1; }
            ;;
        *)
            return 1
            ;;
    esac
}

cc_dev_update_dry_run_command() {
    case "$1" in
        npm) printf '%s\n' 'npm outdated -g --depth=0' ;;
        pipx) printf '%s\n' 'pipx list' ;;
        pip) printf '%s\n' 'python3 -m pip list --outdated' ;;
        cargo) printf '%s\n' 'cargo install --list' ;;
        go) printf '%s\n' 'go env GOPATH GOBIN' ;;
        gem) printf '%s\n' 'gem outdated' ;;
        *) return 1 ;;
    esac
}

cc_dev_update_apply_supported() {
    case "$1" in
        npm|pipx)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

cc_dev_update_apply_command() {
    case "$1" in
        npm) printf '%s\n' 'npm update -g' ;;
        pipx) printf '%s\n' 'pipx upgrade-all' ;;
        *) return 1 ;;
    esac
}

cc_dev_update_run_apply() {
    case "$1" in
        npm)
            npm update -g
            ;;
        pipx)
            pipx upgrade-all
            ;;
        *)
            return 1
            ;;
    esac
}

cc_dev_update_report() {
    local selector="${1:-all}" apply_enabled="${2:-0}"
    local manager installed update_enabled dry_run apply_command

    if ! cc_dev_update_selector_valid "$selector"; then
        printf 'Unknown developer package manager: %s\n' "$selector" >&2
        return 1
    fi

    echo "Developer Package Managers"
    echo "--------------------------"
    printf '%-8s %-13s %-15s %-34s %s\n' \
        "Manager" "Installed" "Update enabled" "Dry-run command" "Apply command"

    while IFS= read -r manager; do
        [ -n "$manager" ] || continue

        if cc_dev_update_installed "$manager"; then
            installed="installed"
        else
            installed="not installed"
        fi

        update_enabled="disabled"
        if [ "$apply_enabled" -eq 1 ] &&
            [ "$installed" = "installed" ] &&
            cc_dev_update_apply_supported "$manager"; then
            update_enabled="enabled"
        fi

        dry_run="$(cc_dev_update_dry_run_command "$manager")"
        apply_command="$(cc_dev_update_apply_command "$manager" 2>/dev/null || true)"
        [ -n "$apply_command" ] || apply_command="manual review"

        printf '%-8s %-13s %-15s %-34s %s\n' \
            "$manager" "$installed" "$update_enabled" "$dry_run" "$apply_command"
    done < <(cc_dev_update_selected_managers "$selector")
}

cc_dev_update_apply() {
    local selector="${1:-all}"
    local manager failures=0 apply_command

    if ! cc_dev_update_selector_valid "$selector"; then
        printf 'Unknown developer package manager: %s\n' "$selector" >&2
        return 1
    fi

    while IFS= read -r manager; do
        [ -n "$manager" ] || continue

        if ! cc_dev_update_installed "$manager"; then
            printf '%s: not installed; skipping.\n' "$manager"
            continue
        fi

        if ! cc_dev_update_apply_supported "$manager"; then
            printf '%s: update apply is disabled; review manually with: %s\n' \
                "$manager" "$(cc_dev_update_dry_run_command "$manager")"
            continue
        fi

        apply_command="$(cc_dev_update_apply_command "$manager")"
        printf '%s: applying developer update: %s\n' "$manager" "$apply_command"
        if cc_dev_update_run_apply "$manager"; then
            printf '%s: update complete.\n' "$manager"
        else
            printf '%s: update failed.\n' "$manager" >&2
            failures=$((failures + 1))
        fi
    done < <(cc_dev_update_selected_managers "$selector")

    [ "$failures" -eq 0 ]
}
