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

for d in bash config install lib baseline/ubuntu-26.04 defaults/v1 docs templates templates/prompts; do
    cc_require_dir "$d"
done

for f in VERSION manifest.yml config/programs.conf lib/cc-context.sh lib/cc-common.sh lib/cc-path.sh lib/cc-programs.sh lib/cc-packages.sh lib/cc-kernel.sh lib/cc-network.sh lib/cc-services.sh lib/cc-http.sh lib/cc-data.sh lib/cc-yaml.sh lib/cc-prompt-engine.sh bash/bashrc bash/bash_aliases bash/bash_functions defaults/v1/bashrc defaults/v1/bash_aliases defaults/v1/bash_functions defaults/v1/manifest.txt install/install.sh; do
    cc_require_file "$f"
done

bash -n lib/cc-context.sh
bash -n lib/cc-common.sh
bash -n lib/cc-path.sh
bash -n lib/cc-programs.sh
bash -n lib/cc-packages.sh
bash -n lib/cc-kernel.sh
bash -n lib/cc-network.sh
bash -n lib/cc-services.sh
bash -n lib/cc-http.sh
bash -n lib/cc-data.sh
bash -n lib/cc-yaml.sh
bash -n lib/cc-prompt-engine.sh
bash -n bash/bashrc
bash -n bash/bash_aliases
bash -n bash/bash_functions
bash -n install/install.sh
bash -n tools/commands/prompt
bash -n tools/commands/programs

cmp -s bash/bashrc defaults/v1/bashrc || { cc_error "Promoted bashrc differs from authoritative source."; exit 1; }
cmp -s bash/bash_aliases defaults/v1/bash_aliases || { cc_error "Promoted bash_aliases differs from authoritative source."; exit 1; }
cmp -s bash/bash_functions defaults/v1/bash_functions || { cc_error "Promoted bash_functions differs from authoritative source."; exit 1; }

source "$TOOLKIT_ROOT/lib/cc-path.sh"
cmp -s <(cc_path_managed_block) <(
    awk -v begin="$CC_PATH_BLOCK_BEGIN" -v end="$CC_PATH_BLOCK_END" '
        $0 == begin { copying=1; blocks++ }
        copying { print }
        $0 == end { copying=0; ends++ }
        END { if (blocks != 1 || ends != 1) exit 1 }
    ' bash/bashrc
) || { cc_error "Authoritative bashrc PATH block differs from shared policy."; exit 1; }

cc_load_version
defaults_version="$(sed -n 's/^Version: //p' defaults/v1/manifest.txt)"
defaults_promoted="$(sed -n 's/^Promoted: //p' defaults/v1/manifest.txt)"
[ "$defaults_version" = "${TOOLKIT_VERSION:-}" ] || {
    cc_error "Defaults manifest version does not match VERSION."
    exit 1
}
if [ -z "$defaults_promoted" ] || ! date -d "$defaults_promoted" >/dev/null 2>&1; then
    cc_error "Defaults manifest promotion timestamp is missing or invalid."
    exit 1
fi

manifest_entries="$(awk 'found && /^  / { print substr($0, 3) } /^Files:$/ { found=1 }' defaults/v1/manifest.txt)"
[ "$manifest_entries" = "$(printf 'bashrc\nbash_aliases\nbash_functions')" ] || {
    cc_error "Defaults manifest file list is incomplete, duplicated, or out of order."
    exit 1
}
while IFS= read -r defaults_file; do
    [ -n "$defaults_file" ] || continue
    cc_require_file "defaults/v1/$defaults_file"
done <<< "$manifest_entries"

source "$TOOLKIT_ROOT/lib/cc-prompt-engine.sh"
cc_prompt_validate_templates

source "$TOOLKIT_ROOT/lib/cc-programs.sh"
cc_program_load

source "$TOOLKIT_ROOT/lib/cc-packages.sh"
_cc_pkg_manager_exists

source "$TOOLKIT_ROOT/lib/cc-network.sh"
_cc_net_network_available
_cc_net_sockets_available

source "$TOOLKIT_ROOT/lib/cc-services.sh"
_cc_service_manager_available
if [ "$(cc_platform_init_system)" = "systemd" ]; then
    _cc_log_available
fi

source "$TOOLKIT_ROOT/lib/cc-http.sh"
_cc_download_available
_cc_http_available

source "$TOOLKIT_ROOT/lib/cc-data.sh"
_cc_yaml_available

cc_log "Verification passed."
