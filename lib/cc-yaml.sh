#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-yaml.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash yaml
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Preserve the asset YAML API through semantic data operations.
# ==============================================================================

if [ -z "${CC_DATA_LOADED:-}" ]; then
    _cc_yaml_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_yaml_lib_dir/cc-data.sh"
    unset _cc_yaml_lib_dir
fi

cc_yaml_get() {
    _cc_yaml_get_string "$@"
}

cc_yaml_get_nested() {
    _cc_yaml_get_nested_string "$@"
}

cc_yaml_set() {
    _cc_yaml_set_string "$@"
}

cc_yaml_set_nested() {
    _cc_yaml_set_nested_string "$@"
}
