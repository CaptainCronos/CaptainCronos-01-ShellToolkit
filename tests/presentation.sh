#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-common.sh"
source "$PROJECT_ROOT/lib/cc-results.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_rendered() {
    local state="$1" color="$2" actual
    actual="$(unset NO_COLOR; TERM=xterm-256color CC_COLOR_MODE=always cc_status_word "$state")"
    [ "$actual" = "$(printf '\033[%sm%s\033[0m' "$color" "$state")" ] ||
        fail "$state did not use its semantic color"
}

assert_rendered PASS '1;32'
assert_rendered WARN '1;33'
assert_rendered FAIL '1;31'
assert_rendered SKIP '1;36'

info="$(unset NO_COLOR; TERM=xterm-256color CC_COLOR_MODE=always cc_status_word INFO)"
[ "$info" = INFO ] || fail 'INFO used decorative color'

redirected="$(unset NO_COLOR; TERM=xterm-256color CC_COLOR_MODE=auto cc_status_word PASS)"
[ "$redirected" = PASS ] || fail 'redirected output contained color'

no_color="$(NO_COLOR='' TERM=xterm-256color CC_COLOR_MODE=always cc_status_word PASS)"
[ "$no_color" = PASS ] || fail 'NO_COLOR did not suppress color'

dumb="$(unset NO_COLOR; TERM=dumb CC_COLOR_MODE=always cc_status_word FAIL)"
[ "$dumb" = FAIL ] || fail 'TERM=dumb did not suppress color'

diagnostic="$(unset NO_COLOR; TERM=xterm-256color CC_COLOR_MODE=always cc_error 'representative failure' 2>&1)"
case "$diagnostic" in
    *$'\033[1;31m[CC ERROR]\033[0m representative failure') ;;
    *) fail 'error diagnostic did not use shared red presentation' ;;
esac

long_row="$(CC_STATUS_WIDTH=4 cc_status_line 'Meaningful long label' PASS)"
[ "$long_row" = 'Meaningful long label PASS' ] || fail 'long status label degraded unsafely'

summary="$(cc_summary_status 'Overall Status:' FAIL)"
[ "$summary" = 'Overall Status: FAIL' ] || fail 'summary status structure changed unexpectedly'

cc_result_reset
unset NO_COLOR
CC_COLOR_MODE=always TERM=xterm-256color cc_result_record 'Semantic result' WARN >/dev/null
[ "$(cc_result_overall)" = WARN ] || fail 'semantic aggregation depended on rendering'
[ "$CC_RESULT_WARN" -eq 1 ] || fail 'semantic result count changed during rendering'

printf 'Presentation framework tests: PASS\n'
