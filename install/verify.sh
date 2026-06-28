#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : verify.sh
# Version     : reads VERSION
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Verify repository structure and shell syntax.
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT"

source "$PROJECT_ROOT/lib/cc-common.sh"

case "${1:-}" in
    --help|-h)
        echo "Usage: install/verify.sh"
        exit 0
        ;;
    --version)
        cc_version
        exit 0
        ;;
esac

cc_banner

for d in bash install lib baseline/ubuntu-26.04 defaults/v1 docs; do
    cc_require_dir "$d"
done

for f in VERSION manifest.yml lib/cc-common.sh bash/bashrc bash/bash_aliases bash/bash_functions install/install.sh; do
    cc_require_file "$f"
done

bash -n lib/cc-common.sh
bash -n bash/bashrc
bash -n bash/bash_aliases
bash -n bash/bash_functions
bash -n install/install.sh

cc_log "Verification passed."
