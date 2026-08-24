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

if [ -z "${CC_CONTEXT_LOADED:-}" ]; then
    _cc_common_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_common_lib_dir/cc-context.sh"
    cc_context_init "${TOOLKIT_ROOT:-${PROJECT_ROOT:-}}" "${CURRENT_REPO:-${PWD:-$(pwd)}}"
    unset _cc_common_lib_dir
fi

if ! declare -F cc_debug >/dev/null 2>&1; then
    _cc_common_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_common_lib_dir/cc-diagnostics.sh"
    unset _cc_common_lib_dir
fi

if [ -z "${CC_TEMP_LOADED:-}" ]; then
    _cc_common_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_common_lib_dir/cc-temp.sh"
    unset _cc_common_lib_dir
fi

cc_load_version() {
    local root
    root="$(cc_toolkit_root 2>/dev/null || pwd)"
    if [ -f "$root/VERSION" ]; then
        # shellcheck disable=SC1091
        source "$root/VERSION"
    fi
}

cc_color_enabled() {
    local fd="${1:-1}" mode="${CC_COLOR_MODE:-auto}"
    [ -z "${NO_COLOR+x}" ] || return 1
    [ "${TERM:-}" != dumb ] || return 1
    case "$mode" in
        always) return 0 ;;
        never) return 1 ;;
        auto) [ -t "$fd" ] ;;
        *) return 1 ;;
    esac
}

cc_color() {
    local code="$1" fd="${2:-1}"
    if cc_color_enabled "$fd"; then
        printf '\033[%sm' "$code" >&"$fd"
    fi
}

cc_color_reset() { cc_color 0 "${1:-1}"; }
cc_color_pass() { cc_color '1;32' "${1:-1}"; }
cc_color_warn() { cc_color '1;33' "${1:-1}"; }
cc_color_fail() { cc_color '1;31' "${1:-1}"; }
cc_color_info() { cc_color '1;36' "${1:-1}"; }

cc_status_word_fd() {
    local fd="$1" status="$2"
    case "$status" in
        PASS|OK|SUCCESS)
            cc_color_pass "$fd"; printf '%s' "$status" >&"$fd"; cc_color_reset "$fd"
            ;;
        WARN|WARNING)
            cc_color_warn "$fd"; printf '%s' "$status" >&"$fd"; cc_color_reset "$fd"
            ;;
        FAIL|FAILED|ERROR|INCOMPATIBLE)
            cc_color_fail "$fd"; printf '%s' "$status" >&"$fd"; cc_color_reset "$fd"
            ;;
        SKIP)
            cc_color_info "$fd"; printf '%s' "$status" >&"$fd"; cc_color_reset "$fd"
            ;;
        *)
            printf '%s' "$status" >&"$fd"
            ;;
    esac
}

cc_status_word() {
    cc_status_word_fd 1 "$1"
}

cc_status_cell() {
    local status="$1" width="${2:-0}" padding
    cc_status_word "$status"
    padding=$((width - ${#status}))
    [ "$padding" -gt 0 ] && printf '%*s' "$padding" ''
}

cc_status_line_fd() {
    local fd="$1" label="$2" status="$3" width="${4:-${CC_STATUS_WIDTH:-38}}" label_len dots
    label_len=${#label}
    if [ "$label_len" -ge "$width" ]; then
        printf '%s ' "$label" >&"$fd"
    else
        dots=$((width - label_len))
        printf '%s' "$label" >&"$fd"
        printf '%*s' "$dots" '' | tr ' ' '.' >&"$fd"
        printf ' ' >&"$fd"
    fi
    cc_status_word_fd "$fd" "$status"
    printf '\n' >&"$fd"
}

cc_status_line() {
    cc_status_line_fd 1 "$1" "$2" "${3:-${CC_STATUS_WIDTH:-38}}"
}

cc_summary_status() {
    local label="${1:-Overall Status:}" status="$2" width="${3:-16}"
    printf '%-*s' "$width" "$label"
    cc_status_word "$status"
    printf '\n'
}

cc_pass() { cc_status_word PASS; }
cc_fail() { cc_status_word FAIL; }
cc_warning() { cc_status_word WARN; }
cc_info_word() { cc_status_word INFO; }

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
    if cc_color_enabled 2; then
        cc_color_warn 2; printf '[CC WARN]' >&2; cc_color_reset 2; printf ' %s\n' "$*" >&2
    else
        echo "[CC WARN] $*" >&2
    fi
}

cc_error() {
    if cc_color_enabled 2; then
        cc_color_fail 2; printf '[CC ERROR]' >&2; cc_color_reset 2; printf ' %s\n' "$*" >&2
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
