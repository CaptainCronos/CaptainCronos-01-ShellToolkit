#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-common.sh"
source "$PROJECT_ROOT/lib/cc-results.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_ascii() {
    local description="$1" output="$2"
    if ! LC_ALL=C printf '%s' "$output" | LC_ALL=C od -An -tu1 | LC_ALL=C awk '
        { for (i = 1; i <= NF; i++) if ($i > 127) { bad = 1; exit } }
        END { exit bad }
    '; then
        fail "$description contained a non-ASCII byte"
    fi
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

# Ordinary runtime messages retain their established streams and prefixes.
logging_stdout="$(mktemp)"
logging_stderr="$(mktemp)"
logging_fd="$(mktemp)"
literal_message='%-quoted-\\path "double" '\''single'\'' * ? [glob] -leading'
cc_log "$literal_message" >"$logging_stdout" 2>"$logging_stderr"
[ "$(<"$logging_stdout")" = "[CC] $literal_message" ] || fail 'cc_log compatibility output changed'
[ ! -s "$logging_stderr" ] || fail 'cc_log wrote to stderr'
cc_info "$literal_message" >"$logging_stdout" 2>"$logging_stderr"
[ "$(<"$logging_stdout")" = "[CC INFO] $literal_message" ] || fail 'cc_info prefix or literal rendering changed'
[ ! -s "$logging_stderr" ] || fail 'cc_info wrote to stderr'
cc_warn "$literal_message" >"$logging_stdout" 2>"$logging_stderr"
[ ! -s "$logging_stdout" ] || fail 'cc_warn contaminated stdout'
[ "$(<"$logging_stderr")" = "[CC WARN] $literal_message" ] || fail 'cc_warn prefix or literal rendering changed'
cc_error "$literal_message" >"$logging_stdout" 2>"$logging_stderr"
[ ! -s "$logging_stdout" ] || fail 'cc_error contaminated stdout'
[ "$(<"$logging_stderr")" = "[CC ERROR] $literal_message" ] || fail 'cc_error prefix or literal rendering changed'
(
    NO_COLOR=1
    cc_debug_enable
    printf '%s\n' '{"result":"machine"}'
    cc_warn 'machine warning'
    cc_error 'machine error'
    cc_debug 'machine diagnostic'
) >"$logging_stdout" 2>"$logging_stderr"
[ "$(<"$logging_stdout")" = '{"result":"machine"}' ] || fail 'runtime diagnostics contaminated structured stdout'
[ "$(<"$logging_stderr")" = $'[CC WARN] machine warning\n[CC ERROR] machine error\n[CC DEBUG] machine diagnostic' ] ||
    fail 'runtime diagnostics did not remain stderr-only'
cc_debug_disable

info_colored="$(unset NO_COLOR; TERM=xterm-256color CC_COLOR_MODE=always cc_info 'color check')"
[ "$info_colored" = $'\033[1;36m[CC INFO]\033[0m color check' ] || fail 'cc_info did not use informational color'
warn_colored="$(unset NO_COLOR; TERM=xterm-256color CC_COLOR_MODE=always cc_warn 'color check' 2>&1)"
[ "$warn_colored" = $'\033[1;33m[CC WARN]\033[0m color check' ] || fail 'cc_warn did not use warning color'
no_color_info="$(NO_COLOR=1 TERM=xterm-256color CC_COLOR_MODE=always cc_info 'plain check')"
[ "$no_color_info" = '[CC INFO] plain check' ] || fail 'cc_info ignored NO_COLOR'
dumb_info="$(unset NO_COLOR; TERM=dumb CC_COLOR_MODE=always cc_info 'plain check')"
[ "$dumb_info" = '[CC INFO] plain check' ] || fail 'cc_info ignored TERM=dumb'
never_info="$(unset NO_COLOR; TERM=xterm-256color CC_COLOR_MODE=never cc_info 'plain check')"
[ "$never_info" = '[CC INFO] plain check' ] || fail 'cc_info ignored CC_COLOR_MODE=never'

cc_info_fd 3 'FD info' 3>"$logging_fd" >"$logging_stdout" 2>"$logging_stderr"
[ "$(<"$logging_fd")" = '[CC INFO] FD info' ] || fail 'cc_info_fd output changed unexpectedly'
[ ! -s "$logging_stdout" ] && [ ! -s "$logging_stderr" ] || fail 'cc_info_fd leaked to a default stream'
cc_warn_fd 3 'FD warn' 3>"$logging_fd" >"$logging_stdout" 2>"$logging_stderr"
[ "$(<"$logging_fd")" = '[CC WARN] FD warn' ] || fail 'cc_warn_fd output changed unexpectedly'
[ ! -s "$logging_stdout" ] && [ ! -s "$logging_stderr" ] || fail 'cc_warn_fd leaked to a default stream'
cc_error_fd 3 'FD error' 3>"$logging_fd" >"$logging_stdout" 2>"$logging_stderr"
[ "$(<"$logging_fd")" = '[CC ERROR] FD error' ] || fail 'cc_error_fd output changed unexpectedly'
[ ! -s "$logging_stdout" ] && [ ! -s "$logging_stderr" ] || fail 'cc_error_fd leaked to a default stream'
for invalid_logging_case in missing_arity missing_message invalid_fd unopened_fd; do
    : >"$logging_stdout"
    : >"$logging_stderr"
    if case "$invalid_logging_case" in
        missing_arity) cc_info_fd >"$logging_stdout" 2>"$logging_stderr" ;;
        missing_message) cc_info_fd 3 >"$logging_stdout" 2>"$logging_stderr" ;;
        invalid_fd) cc_warn_fd unopened message >"$logging_stdout" 2>"$logging_stderr" ;;
        unopened_fd) cc_error_fd 999 message >"$logging_stdout" 2>"$logging_stderr" ;;
    esac; then
        invalid_status=0
    else
        invalid_status=$?
    fi
    [ "$invalid_status" -eq 2 ] || fail "invalid logging call returned the wrong status: $invalid_logging_case"
    [ ! -s "$logging_stdout" ] && [ ! -s "$logging_stderr" ] || fail "invalid logging call produced output: $invalid_logging_case"
done

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

# Shared human-readable presentation remains byte-safe in every locale. ANSI
# escapes may be present when color is enabled, but they are ASCII bytes too.
assert_ascii 'status word' "$(cc_status_word PASS)"
assert_ascii 'status line' "$(cc_status_line 'ASCII status' PASS)"
assert_ascii 'section' "$(cc_section 'ASCII Section')"
assert_ascii 'subsection' "$(cc_subsection 'ASCII Subsection')"
assert_ascii 'divider' "$(cc_divider)"
assert_ascii 'table header' "$(cc_table_header '%s %s\n' 'Column' 'State')"

section_file="$(mktemp)"
divider_file="$(mktemp)"
table_file="$(mktemp)"
trap 'rm -f "$section_file" "$divider_file" "$table_file" "$logging_stdout" "$logging_stderr" "$logging_fd"' EXIT
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

basic_table="$(cc_table_header '%-10s %-8s %s\n' 'Command' 'Version' 'Purpose')"
[ "$basic_table" = $'Command    Version  Purpose\n-------    -------  -------' ] ||
    fail 'basic table header presentation changed unexpectedly'
table_bytes="$(cc_table_header '%-10s %-8s %s\n' 'Command' 'Version' 'Purpose'; printf x)"
case "$table_bytes" in
    *$'\n'x) ;;
    *) fail 'table header did not terminate each row with the supplied newline' ;;
esac

one_column="$(cc_table_header '[%s]\n' 'Only column')"
[ "$one_column" = $'[Only column]\n[-----------]' ] || fail 'one-column table header changed unexpectedly'
empty_header="$(cc_table_header '<%s>\n' '')"
[ "$empty_header" = $'<>\n<>' ] || fail 'empty table header changed unexpectedly'
spaced_punctuation="$(cc_table_header '%s|%s\n' 'Build Status' 'Size (MiB):')"
[ "$spaced_punctuation" = $'Build Status|Size (MiB):\n------------|-----------' ] ||
    fail 'table header spaces or punctuation changed unexpectedly'
long_header='A deliberately long table heading, with punctuation!'
long_table="$(cc_table_header '%s\n' "$long_header")"
long_separator="${long_table#*$'\n'}"
[ "${#long_separator}" -eq "${#long_header}" ] || fail 'long table header separator length changed'
[ "${long_separator//-/}" = '' ] || fail 'long table header separator character changed'

fd_stdout="$(cc_table_header_fd 3 '%-8s %s\n' 'FD Name' 'State' 3>"$table_file")"
[ -z "$fd_stdout" ] || fail 'table header FD output leaked to stdout'
[ "$(<"$table_file")" = $'FD Name  State\n-------  -----' ] || fail 'table header FD output changed unexpectedly'

table_color_always="$(unset NO_COLOR; TERM=xterm-256color CC_COLOR_MODE=always cc_table_header '%s\n' Plain)"
table_color_never="$(TERM=dumb CC_COLOR_MODE=never cc_table_header '%s\n' Plain)"
[ "$table_color_always" = "$table_color_never" ] || fail 'table output depended on color mode'
case "$table_color_always" in
    *$'\033'*) fail 'table output contained ANSI color' ;;
esac

for invalid_table_case in missing_format missing_headers missing_fd_headers invalid_fd unopened_fd; do
    if case "$invalid_table_case" in
        missing_format) cc_table_header >"$table_file" 2>&1 ;;
        missing_headers) cc_table_header_fd 1 >"$table_file" 2>&1 ;;
        missing_fd_headers) cc_table_header_fd 1 '%s\n' >"$table_file" 2>&1 ;;
        invalid_fd) cc_table_header_fd invalid '%s\n' Header >"$table_file" 2>&1 ;;
        unopened_fd) cc_table_header_fd 999 '%s\n' Header >"$table_file" 2>&1 ;;
    esac; then
        invalid_status=0
    else
        invalid_status=$?
    fi
    [ "$invalid_status" -eq 2 ] || fail "invalid table helper call returned the wrong status: $invalid_table_case"
    [ ! -s "$table_file" ] || fail "invalid table helper call produced output: $invalid_table_case"
done

if cc_table_header '%' Header >"$table_file" 2>&1; then
    fail 'invalid table printf format succeeded unexpectedly'
fi

registry_table="$(NO_COLOR=1 TERM=dumb bash "$PROJECT_ROOT/tools/cc" registry)"
case "$registry_table" in
    *$'Command                  Version            Category           Purpose\n-------                  -------            --------           -------'*) ;;
    *) fail 'registry table header or separator changed unexpectedly' ;;
esac

cc_result_reset
unset NO_COLOR
CC_COLOR_MODE=always TERM=xterm-256color cc_result_record 'Semantic result' WARN >/dev/null
[ "$(cc_result_overall)" = WARN ] || fail 'semantic aggregation depended on rendering'
[ "$CC_RESULT_WARN" -eq 1 ] || fail 'semantic result count changed during rendering'

printf 'Presentation framework tests: PASS\n'
