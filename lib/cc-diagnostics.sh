#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-diagnostics.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash sed wc
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Provide shared debug diagnostics and count-based progress status.
# ==============================================================================

: "${CC_DEBUG:=0}"

cc_debug_enable() {
    CC_DEBUG=1
}

cc_debug_disable() {
    CC_DEBUG=0
}

cc_debug_enabled() {
    [ "${CC_DEBUG:-0}" = "1" ]
}

cc_debug_redact() {
    sed -E \
        -e 's/((password|passwd|token|secret|api[_-]?key|authorization|credential)[[:space:]_-]*[=:][[:space:]]*)[^[:space:]]+/\1[REDACTED]/Ig' \
        -e 's/(Bearer[[:space:]]+)[A-Za-z0-9._~+\/-]+/\1[REDACTED]/Ig'
}

cc_debug() {
    cc_debug_enabled || return 0
    printf '[CC DEBUG] %s\n' "$*" >&2
}

cc_debug_kv() {
    local key="$1" value="${2:-}"
    cc_debug_enabled || return 0
    case "${key,,}" in
        *password*|*passwd*|*token*|*secret*|*api-key*|*api_key*|*authorization*|*credential*|*private-key*|*private_key*)
            if [ -n "$value" ]; then
                value="[REDACTED: present]"
            else
                value="[not configured]"
            fi
            ;;
    esac
    printf '[CC DEBUG] %s: %s\n' "$key" "$value" >&2
}

cc_debug_block() {
    local label="$1" content="${2:-}" line
    cc_debug_enabled || return 0
    if [ -z "$content" ]; then
        printf '[CC DEBUG] %s: <empty>\n' "$label" >&2
        return 0
    fi
    while IFS= read -r line || [ -n "$line" ]; do
        printf '[CC DEBUG] %s: %s\n' "$label" "$line" >&2
    done < <(printf '%s\n' "$content" | cc_debug_redact)
}

cc_debug_result() {
    local expected="$1" actual="$2" stdout_file="$3" stderr_file="$4"
    local stdout_size=0 stderr_size=0
    cc_debug_enabled || return 0
    [ -f "$stdout_file" ] && stdout_size="$(wc -c < "$stdout_file" | tr -d ' ')"
    [ -f "$stderr_file" ] && stderr_size="$(wc -c < "$stderr_file" | tr -d ' ')"
    cc_debug_kv "expected exit status" "$expected"
    cc_debug_kv "actual exit status" "$actual"
    cc_debug_kv "captured stdout bytes" "$stdout_size"
    cc_debug_kv "captured stderr bytes" "$stderr_size"
    if [ "$actual" -ne "$expected" ]; then
        cc_debug_kv "captured stdout path" "$stdout_file"
        cc_debug_kv "captured stderr path" "$stderr_file"
        cc_debug_block "captured stdout" "$(cat "$stdout_file" 2>/dev/null || true)"
        cc_debug_block "captured stderr" "$(cat "$stderr_file" 2>/dev/null || true)"
        cc_debug "failure propagation: underlying status -> test result -> selftest summary"
    fi
}

CC_PROGRESS_TOTAL=0
CC_PROGRESS_CURRENT=0
CC_PROGRESS_COMPLETED=0
CC_PROGRESS_LIVE=0
CC_PROGRESS_SEQUENTIAL=0
CC_PROGRESS_ACTIVE=0
CC_PROGRESS_LABEL=""
CC_PROGRESS_TAG="STATUS"

cc_progress_terminal_available() {
    [ -t 2 ] && [ "${TERM:-}" != dumb ]
}

cc_progress_init() {
    local title="$1" total="$2" machine="${3:-0}" tag="${4:-STATUS}"
    [[ "$total" =~ ^[0-9]+$ ]] || return 2
    [[ "$tag" =~ ^[A-Za-z][A-Za-z0-9_-]*$ ]] || return 2
    CC_PROGRESS_TOTAL="$total"
    CC_PROGRESS_CURRENT=0
    CC_PROGRESS_COMPLETED=0
    CC_PROGRESS_LIVE=0
    CC_PROGRESS_SEQUENTIAL=0
    CC_PROGRESS_ACTIVE=0
    CC_PROGRESS_LABEL=""
    CC_PROGRESS_TAG="${tag^^}"
    cc_debug_kv "progress workflow" "$title"
    if cc_debug_enabled; then
        CC_PROGRESS_SEQUENTIAL=1
    elif [ "$machine" -eq 0 ] && cc_progress_terminal_available; then
        CC_PROGRESS_LIVE=1
    fi
}

cc_progress_start() {
    local label="$1"
    CC_PROGRESS_CURRENT=$((CC_PROGRESS_CURRENT + 1))
    CC_PROGRESS_ACTIVE=1
    CC_PROGRESS_LABEL="$label"
    if [ "$CC_PROGRESS_LIVE" -eq 1 ]; then
        printf '\r\033[2K[CC %s] [%2d/%d] %s ... RUNNING' \
            "$CC_PROGRESS_TAG" "$CC_PROGRESS_CURRENT" "$CC_PROGRESS_TOTAL" "$label" >&2
    elif [ "$CC_PROGRESS_SEQUENTIAL" -eq 1 ]; then
        printf '[CC %s] [%d/%d] %s ... RUNNING\n' \
            "$CC_PROGRESS_TAG" "$CC_PROGRESS_CURRENT" "$CC_PROGRESS_TOTAL" "$label" >&2
    fi
}

_cc_progress_status_line() {
    local label="$1" status="$2"
    if declare -F cc_status_line_fd >/dev/null 2>&1; then
        cc_status_line_fd 2 "$label" "$status" "${CC_PROGRESS_WIDTH:-62}"
    else
        printf '%s ... %s\n' "$label" "$status" >&2
    fi
}

cc_progress_finish() {
    local status="$1"
    CC_PROGRESS_COMPLETED=$((CC_PROGRESS_COMPLETED + 1))
    if [ "$CC_PROGRESS_LIVE" -eq 1 ]; then
        printf '\r\033[2K' >&2
        _cc_progress_status_line \
            "[CC $CC_PROGRESS_TAG] [$(printf '%2d' "$CC_PROGRESS_CURRENT")/$CC_PROGRESS_TOTAL] $CC_PROGRESS_LABEL" \
            "$status"
    elif [ "$CC_PROGRESS_SEQUENTIAL" -eq 1 ]; then
        _cc_progress_status_line \
            "[CC $CC_PROGRESS_TAG] [$CC_PROGRESS_CURRENT/$CC_PROGRESS_TOTAL] $CC_PROGRESS_LABEL" \
            "$status"
    fi
    CC_PROGRESS_ACTIVE=0
}

cc_progress_live() {
    [ "$CC_PROGRESS_LIVE" -eq 1 ]
}

cc_progress_sequential() {
    [ "$CC_PROGRESS_SEQUENTIAL" -eq 1 ]
}

cc_progress_cleanup() {
    if [ "$CC_PROGRESS_LIVE" -eq 1 ] && [ "$CC_PROGRESS_ACTIVE" -eq 1 ]; then
        printf '\n' >&2
    fi
    CC_PROGRESS_ACTIVE=0
}
