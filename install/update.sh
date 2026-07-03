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

DRY_RUN=0

usage() {
    cat <<'EOF_HELP'
Usage:
  install/update.sh [--dry-run]

Pulls the latest repository changes and runs install/install.sh.

Options:
  --dry-run   Verify and show install actions without copying files.
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
            DRY_RUN=1
            shift
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

cc_banner

cc_log "Updating repository from origin/main..."
if [ "$DRY_RUN" -eq 1 ]; then
    git fetch origin main
else
    git pull --rebase origin main
fi

cc_log "Verifying toolkit before install..."
bash install/verify.sh

cc_log "Running installer..."
if [ "$DRY_RUN" -eq 1 ]; then
    bash install/install.sh --dry-run
else
    bash install/install.sh
fi

cc_log "Update complete. Reload with: source ~/.bashrc"
