#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : promote-defaults.sh
# Version     : reads VERSION
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Promote active bash files into defaults/v1.
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT"

source "$PROJECT_ROOT/lib/cc-common.sh"

case "${1:-}" in
    --help|-h)
        echo "Usage: install/promote-defaults.sh"
        exit 0
        ;;
    --version)
        cc_version
        exit 0
        ;;
esac

cc_banner

cc_require_file bash/bashrc
cc_require_file bash/bash_aliases
cc_require_file bash/bash_functions

bash -n bash/bashrc
bash -n bash/bash_aliases
bash -n bash/bash_functions

mkdir -p defaults/v1

cp -f bash/bashrc defaults/v1/bashrc
cp -f bash/bash_aliases defaults/v1/bash_aliases
cp -f bash/bash_functions defaults/v1/bash_functions

cat > defaults/v1/manifest.txt <<EOFDEF
Captain Cronos Shell Toolkit Defaults
Version: ${TOOLKIT_VERSION:-unknown}
Promoted: $(date)

Files:
  bashrc
  bash_aliases
  bash_functions
EOFDEF

cat > defaults/v1/README.md <<'EOFREADME'
# Captain Cronos Defaults v1

Approved deployable default shell configuration for Captain Cronos Shell Toolkit v1.
EOFREADME

cc_log "Defaults promoted to defaults/v1"
