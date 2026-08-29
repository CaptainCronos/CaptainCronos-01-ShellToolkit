#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : update.sh
# Version     : reads VERSION
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Pull latest repository changes and reinstall toolkit defaults.
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT"

source "$PROJECT_ROOT/lib/cc-common.sh"

MODE="dry-run"
MODE_SET=""

usage() {
    cat <<'EOF_HELP'
Usage:
  install/update.sh [--dry-run|--apply]

Pulls the latest repository changes and runs install/install.sh.

Options:
  --dry-run   Inspect local Git state and show install actions without writes.
  --apply     Pull origin/main and apply the full shell-file installation.

Default:
  Dry-run. Remote comparison is deferred until --apply because fetching changes
  repository metadata.
EOF_HELP
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --help|-h)
            usage
            exit 0
            ;;
        --version)
            cc_version
            exit 0
            ;;
        --dry-run)
            if [ -n "$MODE_SET" ] && [ "$MODE_SET" != dry-run ]; then
                cc_error "Choose exactly one of --dry-run or --apply."
                exit 2
            fi
            MODE="dry-run"
            MODE_SET="dry-run"
            shift
            ;;
        --apply)
            if [ -n "$MODE_SET" ] && [ "$MODE_SET" != apply ]; then
                cc_error "Choose exactly one of --dry-run or --apply."
                exit 2
            fi
            MODE="apply"
            MODE_SET="apply"
            shift
            ;;
        *)
            cc_error "Unknown option: $1"
            usage >&2
            exit 2
            ;;
    esac
done

cc_banner

if [ "$MODE" = apply ]; then
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        cc_error "Toolkit update requires a Git working tree: $PROJECT_ROOT"
        exit 1
    fi
    branch="$(git branch --show-current)"
    if [ "$branch" != main ]; then
        cc_error "Toolkit update apply requires branch main; current branch: ${branch:-detached}"
        exit 1
    fi
    if [ -n "$(git status --porcelain)" ]; then
        cc_error "Toolkit update apply requires a clean working tree."
        exit 1
    fi
    if ! git remote get-url origin >/dev/null 2>&1; then
        cc_error "Toolkit update apply requires an origin remote."
        exit 1
    fi
    cc_log "Updating clean main from origin/main (fast-forward only)..."
    git pull --ff-only origin main
else
    cc_log "DRY RUN: inspecting local toolkit repository without contacting origin."
    printf '%-18s %s\n' "Branch:" "$(git branch --show-current 2>/dev/null || printf unknown)"
    printf '%-18s %s\n' "Local HEAD:" "$(git rev-parse --short HEAD 2>/dev/null || printf unknown)"
    printf '%-18s %s\n' "Origin:" "$(git remote get-url origin 2>/dev/null || printf unavailable)"
    printf '%-18s %s\n' "Remote state:" "cached local refs; not refreshed"
    cc_log "DRY RUN: would fetch and pull origin/main during --apply."
fi

cc_log "Verifying toolkit before install..."
bash install/verify.sh

cc_log "Running installer..."
if [ "$MODE" = dry-run ]; then
    bash install/install.sh --dry-run
else
    bash install/install.sh --apply
fi

if [ "$MODE" = apply ]; then
    cc_log "Update complete. Reload with: source ~/.bashrc"
else
    cc_log "DRY RUN: toolkit update preview complete; no Git refs or installed files changed."
fi
