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

ORIGINAL_PWD="${PWD:-$(pwd)}"
TOOLKIT_ROOT="${TOOLKIT_ROOT:-${PROJECT_ROOT:-}}"
if [ -z "$TOOLKIT_ROOT" ]; then
    TOOLKIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fi

cd "$TOOLKIT_ROOT"

source "$TOOLKIT_ROOT/lib/cc-context.sh"
source "$TOOLKIT_ROOT/lib/cc-common.sh"
cc_context_init "$TOOLKIT_ROOT" "${CURRENT_REPO:-$ORIGINAL_PWD}"

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

for d in bash install lib baseline/ubuntu-26.04 defaults/v1 docs templates templates/prompts; do
    cc_require_dir "$d"
done

for f in VERSION manifest.yml lib/cc-context.sh lib/cc-common.sh lib/cc-prompt-engine.sh bash/bashrc bash/bash_aliases bash/bash_functions install/install.sh; do
    cc_require_file "$f"
done

bash -n lib/cc-context.sh
bash -n lib/cc-common.sh
bash -n lib/cc-prompt-engine.sh
bash -n bash/bashrc
bash -n bash/bash_aliases
bash -n bash/bash_functions
bash -n install/install.sh
bash -n tools/commands/prompt

source "$TOOLKIT_ROOT/lib/cc-prompt-engine.sh"
cc_prompt_validate_templates

cc_log "Verification passed."
