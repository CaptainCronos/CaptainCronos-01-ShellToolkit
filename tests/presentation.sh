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

detail_row="$(CC_STATUS_WIDTH=4 cc_status_detail_line 'Meaningful long label' WARN 'detail')"
[ "$detail_row" = 'Meaningful long label WARN detail' ] || fail 'status detail row degraded unsafely'

plain_row="$(cc_dotted_line 'Command' 'Plain description.' 12)"
[ "$plain_row" = 'Command..... Plain description.' ] || fail 'plain dotted row presentation changed unexpectedly'

long_plain_row="$(cc_dotted_line 'Meaningful long command name' 'Plain description.' 4)"
[ "$long_plain_row" = 'Meaningful long command name Plain description.' ] ||
    fail 'long plain label degraded unsafely'

summary="$(cc_summary_status 'Overall Status:' FAIL)"
[ "$summary" = 'Overall Status: FAIL' ] || fail 'summary status structure changed unexpectedly'

section="$(cc_section 'CHIRP Deployment Status')"
[ "$section" = $'CHIRP Deployment Status\n=======================' ] ||
    fail 'primary section presentation changed unexpectedly'

subsection="$(cc_subsection 'Dependency Check')"
[ "$subsection" = $'Dependency Check\n----------------' ] ||
    fail 'subsection presentation changed unexpectedly'

section_file="$(mktemp)"
divider_file="$(mktemp)"
trap 'rm -f "$section_file" "$divider_file"' EXIT
cc_divider >"$divider_file"
[ "$(<"$divider_file")" = '------------------------------------' ] ||
    fail 'default divider presentation changed unexpectedly'
[ "$(wc -c <"$divider_file")" -eq 37 ] ||
    fail 'default divider width or terminating newline changed'

[ "$(cc_divider 8)" = '--------' ] || fail 'explicit divider width changed unexpectedly'
[ "$(cc_divider 1)" = '-' ] || fail 'single-character divider changed unexpectedly'
large_divider="$(cc_divider 512)"
[ "${#large_divider}" -eq 512 ] || fail 'large divider width changed unexpectedly'
[ "${large_divider//-/}" = '' ] || fail 'large divider character changed unexpectedly'

fd_stdout="$(cc_divider_fd 3 3>"$divider_file")"
[ -z "$fd_stdout" ] || fail 'divider FD output leaked to stdout'
[ "$(wc -c <"$divider_file")" -eq 37 ] || fail 'divider FD default width changed unexpectedly'
fd_stdout="$(cc_divider_fd 3 7 3>"$divider_file")"
[ -z "$fd_stdout" ] || fail 'explicit divider FD output leaked to stdout'
[ "$(od -An -tx1 "$divider_file" | tr -d '[:space:]')" = '2d2d2d2d2d2d2d0a' ] ||
    fail 'divider FD output or terminating newline changed unexpectedly'

for invalid_width in 0 -1 twelve ''; do
    if cc_divider "$invalid_width" >"$divider_file" 2>&1; then
        invalid_status=0
    else
        invalid_status=$?
    fi
    [ "$invalid_status" -eq 2 ] || fail "invalid divider width returned the wrong status: ${invalid_width:-empty}"
    [ ! -s "$divider_file" ] || fail "invalid divider width produced output: ${invalid_width:-empty}"
    if cc_divider_fd 3 "$invalid_width" 3>"$divider_file"; then
        invalid_status=0
    else
        invalid_status=$?
    fi
    [ "$invalid_status" -eq 2 ] || fail "invalid divider FD width returned the wrong status: ${invalid_width:-empty}"
    [ ! -s "$divider_file" ] || fail "invalid divider FD width produced output: ${invalid_width:-empty}"
done

divider_color_always="$(unset NO_COLOR; TERM=xterm-256color CC_COLOR_MODE=always cc_divider 9)"
divider_color_never="$(TERM=dumb CC_COLOR_MODE=never cc_divider 9)"
[ "$divider_color_always" = "$divider_color_never" ] || fail 'divider output depended on color mode'
case "$divider_color_always" in
    *$'\033'*) fail 'divider output contained ANSI color' ;;
esac

fd_stdout="$(cc_section_fd 3 'FD title: ready!' 3>"$section_file")"
[ -z "$fd_stdout" ] || fail 'primary section FD output leaked to stdout'
[ "$(<"$section_file")" = $'FD title: ready!\n================' ] ||
    fail 'primary section FD output changed unexpectedly'
fd_stdout="$(cc_subsection_fd 3 'Alternate descriptor' 3>"$section_file")"
[ -z "$fd_stdout" ] || fail 'subsection FD output leaked to stdout'
[ "$(<"$section_file")" = $'Alternate descriptor\n--------------------' ] ||
    fail 'subsection FD output changed unexpectedly'
cc_section_fd 3 '' 3>"$section_file"
[ "$(od -An -tx1 "$section_file" | tr -d '[:space:]')" = '0a0a' ] ||
    fail 'empty primary section did not retain structural newlines'
cc_subsection_fd 3 '' 3>"$section_file"
[ "$(od -An -tx1 "$section_file" | tr -d '[:space:]')" = '0a0a' ] ||
    fail 'empty subsection did not retain structural newlines'

long_title='A deliberately long section heading, with spaces: punctuation!'
long_section="$(cc_section "$long_title")"
long_underline="${long_section#*$'\n'}"
[ "${#long_underline}" -eq "${#long_title}" ] || fail 'primary section underline length changed'
[ "${long_underline//=/}" = '' ] || fail 'primary section underline character changed'

punctuation_title='Title: commas, periods. (Normal!)'
punctuation_subsection="$(cc_subsection "$punctuation_title")"
punctuation_underline="${punctuation_subsection#*$'\n'}"
[ "${#punctuation_underline}" -eq "${#punctuation_title}" ] ||
    fail 'subsection punctuation underline length changed'
[ "${punctuation_underline//-/}" = '' ] || fail 'subsection underline character changed'

section_color_always="$(unset NO_COLOR; TERM=xterm-256color CC_COLOR_MODE=always cc_section 'Plain Title')"
section_color_never="$(TERM=dumb CC_COLOR_MODE=never cc_section 'Plain Title')"
[ "$section_color_always" = "$section_color_never" ] || fail 'section output depended on color mode'
case "$section_color_always" in
    *$'\033'*) fail 'section output contained ANSI color' ;;
esac

cc_result_reset
unset NO_COLOR
CC_COLOR_MODE=always TERM=xterm-256color cc_result_record 'Semantic result' WARN >/dev/null
[ "$(cc_result_overall)" = WARN ] || fail 'semantic aggregation depended on rendering'
[ "$CC_RESULT_WARN" -eq 1 ] || fail 'semantic result count changed during rendering'

printf 'Presentation framework tests: PASS\n'
