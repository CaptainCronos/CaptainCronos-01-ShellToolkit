#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : apply-shell-functions-v2.sh
# Version     : reads VERSION
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Apply lstree/helpme v2 updates, verify, and install them locally.
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT"

source "$PROJECT_ROOT/lib/cc-common.sh"

case "${1:-}" in
    --help|-h)
        echo "Usage: tools/apply-shell-functions-v2.sh"
        echo
        echo "Applies lstree/helpme v2 updates to bash/bash_functions, verifies syntax,"
        echo "promotes defaults, and installs the updated shell functions locally."
        exit 0
        ;;
    --version)
        cc_version
        exit 0
        ;;
esac

cc_banner

cc_require_file tools/patch-lstree-helpme.sh
cc_require_file bash/bash_functions

cc_log "Applying lstree/helpme v2 patch..."
bash tools/patch-lstree-helpme.sh

cc_log "Verifying patched shell functions..."
bash -n bash/bash_functions

cc_log "Promoting patched shell files to defaults/v1..."
install/promote-defaults.sh

cc_log "Installing patched shell files locally..."
install/install.sh

cc_log "Local shell files updated. Reload with: source ~/.bashrc"
cc_log "Recommended next step: git diff -- bash/bash_functions defaults/v1"
