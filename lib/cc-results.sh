#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-results.sh
# Version     : reads VERSION
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Shared PASS/WARN/FAIL/SKIP result aggregation.
# ==============================================================================

CC_RESULT_WARN_RC=10
CC_RESULT_SKIP_RC=20

cc_result_reset() {
    CC_RESULT_PASS=0
    CC_RESULT_WARN=0
    CC_RESULT_FAIL=0
    CC_RESULT_SKIP=0
}

cc_result_from_rc() {
    case "$1" in
        0) echo PASS ;;
        "$CC_RESULT_WARN_RC") echo WARN ;;
        "$CC_RESULT_SKIP_RC") echo SKIP ;;
        *) echo FAIL ;;
    esac
}

cc_result_record() {
    local label="$1" state="$2"
    case "$state" in
        PASS) CC_RESULT_PASS=$((CC_RESULT_PASS + 1)) ;;
        WARN) CC_RESULT_WARN=$((CC_RESULT_WARN + 1)) ;;
        FAIL) CC_RESULT_FAIL=$((CC_RESULT_FAIL + 1)) ;;
        SKIP) CC_RESULT_SKIP=$((CC_RESULT_SKIP + 1)) ;;
        *) return 2 ;;
    esac
    cc_status_line "$label" "$state"
}

cc_result_overall() {
    if [ "$CC_RESULT_FAIL" -gt 0 ]; then
        echo FAIL
    elif [ "$CC_RESULT_WARN" -gt 0 ]; then
        echo WARN
    elif [ "$CC_RESULT_PASS" -gt 0 ]; then
        echo PASS
    else
        echo SKIP
    fi
}

cc_result_exit_status() {
    [ "$CC_RESULT_FAIL" -eq 0 ]
}
