#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-common.sh
# Version     : reads VERSION
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Shared library for Captain Cronos scripts.
# ==============================================================================

cc_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null || pwd
}

cc_load_version() {
    local root
    root="$(cc_repo_root)"
    if [ -f "$root/VERSION" ]; then
        # shellcheck disable=SC1091
        source "$root/VERSION"
    fi
}

cc_banner() {
    cc_load_version
    echo "Captain Cronos Shell Toolkit"
    echo "Version : ${TOOLKIT_VERSION:-unknown}"
    echo "Codename: ${TOOLKIT_CODENAME:-unknown}"
    echo
}

cc_version() {
    cc_load_version
    echo "Toolkit : ${TOOLKIT_VERSION:-unknown}"
    echo "Codename: ${TOOLKIT_CODENAME:-unknown}"
    echo "Standard: ${STANDARDS_VERSION:-unknown}"
    echo "Baseline: ${BASELINE_VERSION:-unknown}"
    echo "Release : ${RELEASE_DATE:-unknown}"
}

cc_log() {
    echo "[CC] $*"
}

cc_warn() {
    echo "[CC WARN] $*" >&2
}

cc_error() {
    echo "[CC ERROR] $*" >&2
}

cc_require_file() {
    if [ ! -f "$1" ]; then
        cc_error "Missing required file: $1"
        return 1
    fi
}

cc_require_dir() {
    if [ ! -d "$1" ]; then
        cc_error "Missing required directory: $1"
        return 1
    fi
}
