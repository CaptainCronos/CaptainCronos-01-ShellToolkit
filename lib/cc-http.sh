#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-http.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash command
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Provide semantic file-download and HTTP request operations.
# ==============================================================================

if [ -z "${CC_HTTP_LOADED:-}" ]; then
    _cc_http_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_http_lib_dir/cc-programs.sh"
    unset _cc_http_lib_dir
    CC_HTTP_LOADED=1
fi

_cc_download_program() {
    cc_program_get download
}

_cc_http_program() {
    cc_program_get http-api
}

_cc_download_available() {
    local program
    program="$(_cc_download_program)" || return 1
    command -v "$program" >/dev/null 2>&1
}

_cc_http_available() {
    local program
    program="$(_cc_http_program)" || return 1
    command -v "$program" >/dev/null 2>&1
}

_cc_http_redact_url() {
    local url="$1" scheme remainder
    case "$url" in
        *://*)
            scheme="${url%%://*}://"
            remainder="${url#*://}"
            case "$remainder" in
                *@*) remainder="${remainder#*@}" ;;
            esac
            url="$scheme$remainder"
            ;;
    esac
    case "$url" in
        *\?*) url="${url%%\?*}?[REDACTED]" ;;
    esac
    printf '%s\n' "$url"
}

_cc_http_report() {
    if [ -n "${CC_HTTP_REPORTER:-}" ]; then
        "${CC_HTTP_REPORTER}" "$1"
    else
        printf '%s\n' "$1"
    fi
}

_cc_download() {
    [ "$#" -eq 1 ] || return 2
    local program url
    program="$(_cc_download_program)" || return 1
    url="$1"
    if [ "${CC_HTTP_DRY_RUN:-0}" -eq 1 ]; then
        _cc_http_report "DRY RUN: download $(_cc_http_redact_url "$url")"
        return 0
    fi
    "$program" "$url"
}

_cc_download_to() {
    [ "$#" -ge 2 ] && [ "$#" -le 3 ] || return 2
    local program url="$1" destination="$2" retries="${3:-0}" tries
    [[ "$retries" =~ ^[0-9]+$ ]] || return 2
    program="$(_cc_download_program)" || return 1
    if [ "${CC_HTTP_DRY_RUN:-0}" -eq 1 ]; then
        _cc_http_report "DRY RUN: download $(_cc_http_redact_url "$url") -> $destination"
        return 0
    fi
    tries=$((retries + 1))
    "$program" \
        --tries="$tries" \
        --retry-on-http-error=408,429,500,502,503,504 \
        --output-document="$destination" \
        "$url"
}

_cc_http_get() {
    [ "$#" -eq 1 ] || return 2
    local program url="$1"
    program="$(_cc_http_program)" || return 1
    if [ "${CC_HTTP_DRY_RUN:-0}" -eq 1 ]; then
        _cc_http_report "DRY RUN: HTTP GET $(_cc_http_redact_url "$url")"
        return 0
    fi
    "$program" --fail-with-body --silent --show-error --location "$url"
}

_cc_http_head() {
    [ "$#" -eq 1 ] || return 2
    local program url="$1"
    program="$(_cc_http_program)" || return 1
    if [ "${CC_HTTP_DRY_RUN:-0}" -eq 1 ]; then
        _cc_http_report "DRY RUN: HTTP HEAD $(_cc_http_redact_url "$url")"
        return 0
    fi
    "$program" --fail --silent --show-error --location --head "$url"
}
