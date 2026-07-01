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

cc_color_enabled() {
    [ -t 1 ] && [ -z "${NO_COLOR:-}" ]
}

cc_color() {
    local code="$1"
    if cc_color_enabled; then
        printf '\033[%sm' "$code"
    fi
}

cc_color_reset() { cc_color 0; }
cc_color_pass() { cc_color '1;32'; }
cc_color_warn() { cc_color '1;33'; }
cc_color_fail() { cc_color '1;31'; }
cc_color_info() { cc_color '1;36'; }
cc_color_note() { cc_color '1;37'; }

cc_status_word() {
    local status="$1"
    case "$status" in
        PASS|OK|SUCCESS)
            cc_color_pass; printf '%s' "$status"; cc_color_reset
            ;;
        WARN|WARNING)
            cc_color_warn; printf '%s' "$status"; cc_color_reset
            ;;
        FAIL|FAILED|ERROR)
            cc_color_fail; printf '%s' "$status"; cc_color_reset
            ;;
        INFO)
            cc_color_info; printf '%s' "$status"; cc_color_reset
            ;;
        *)
            cc_color_note; printf '%s' "$status"; cc_color_reset
            ;;
    esac
}

cc_status_line() {
    local label="$1" status="$2"
    printf '%-38s ' "$label"
    cc_status_word "$status"
    printf '\n'
}

cc_pass() { cc_status_word PASS; }
cc_fail() { cc_status_word FAIL; }
cc_warning() { cc_status_word WARN; }
cc_info_word() { cc_status_word INFO; }

cc_banner() {
    cc_load_version
    if cc_color_enabled; then
        cc_color_info; echo "Captain Cronos Shell Toolkit"; cc_color_reset
    else
        echo "Captain Cronos Shell Toolkit"
    fi
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
    if cc_color_enabled; then
        cc_color_warn; printf '[CC WARN]'; cc_color_reset; printf ' %s\n' "$*" >&2
    else
        echo "[CC WARN] $*" >&2
    fi
}

cc_error() {
    if cc_color_enabled; then
        cc_color_fail; printf '[CC ERROR]'; cc_color_reset; printf ' %s\n' "$*" >&2
    else
        echo "[CC ERROR] $*" >&2
    fi
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
