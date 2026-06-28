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

case "${1:-}" in
    --help|-h)
        echo "Usage: install/update.sh"
        echo
        echo "Pulls the latest repository changes and runs install/install.sh."
        exit 0
        ;;
    --version)
        cc_version
        exit 0
        ;;
esac

cc_banner

cc_log "Updating repository from origin/main..."
git pull --rebase origin main

cc_log "Verifying toolkit before install..."
install/verify.sh

cc_log "Running installer..."
install/install.sh

cc_log "Update complete. Reload with: source ~/.bashrc"
