#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_DIR="$(mktemp -d)"

cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_failure() {
    local helper="$1" expected="$2"
    shift 2
    : >"$TEST_DIR/stdout"
    : >"$TEST_DIR/stderr"
    if "$@" >"$TEST_DIR/stdout" 2>"$TEST_DIR/stderr"; then
        fail "$helper unexpectedly succeeded"
    fi
    [ ! -s "$TEST_DIR/stdout" ] || fail "$helper diagnostic leaked to stdout"
    grep -Fq -- "$expected" "$TEST_DIR/stderr" ||
        fail "$helper diagnostic did not identify the failure"
}

export CAPTAIN_CRONOS_FUNCTIONS="$PROJECT_ROOT/defaults/v1/bash_functions"
export CAPTAIN_CRONOS_ALIASES="$PROJECT_ROOT/defaults/v1/bash_aliases"
# Ensure the sourced file's compatibility cleanup succeeds under errexit.
alias functions=: funcs=: showfunc=:
# The repository root is resolved at runtime so the test works from any directory.
# shellcheck disable=SC1090
if ! source "$PROJECT_ROOT/bash/bash_functions"; then
    fail "could not load authoritative shell functions"
fi
# shellcheck disable=SC1090
if ! source "$PROJECT_ROOT/bash/bash_aliases"; then
    fail "could not load authoritative shell aliases"
fi

alias cc >/dev/null 2>&1 && fail "deprecated cc alias remains active"
alias edit-in-kitty >/dev/null 2>&1 && fail "deprecated edit-in-kitty alias remains active"
! grep -Fq "alias cc='helpme'" "$PROJECT_ROOT/defaults/v1/bash_aliases" ||
    fail "deprecated cc alias remains in deployable defaults"
! grep -Fq 'edit-in-kitty' "$PROJECT_ROOT/defaults/v1/bash_aliases" ||
    fail "deprecated edit-in-kitty alias remains in deployable defaults"

mkdir -p "$TEST_DIR/bin"
printf '#!/usr/bin/env bash\nexit 0\n' >"$TEST_DIR/bin/cc"
chmod 700 "$TEST_DIR/bin/cc"
resolved_cc="$(PATH="$TEST_DIR/bin:$PATH" command -v cc)"
[ "$resolved_cc" = "$TEST_DIR/bin/cc" ] || fail "shell alias shadows the cc dispatcher"

for helper in kedit suedit sukitty ccvalidate; do
    _cc_function_names | grep -Fxq "$helper" || fail "$helper is absent from helpme metadata"
done

assert_failure kedit 'Usage: kedit <file> [file...]' kedit
assert_failure suedit 'Usage: suedit <file> [file...]' suedit
assert_failure sukitty 'Usage: sukitty' sukitty unexpected

# These wrappers are passed by name to assert_failure; the restricted PATH is
# intentional so host-installed programs cannot satisfy dependency checks.
NO_ARGS=()
# shellcheck disable=SC2123
missing_kitty_kedit() { (unset -f kitty nano; PATH=/nonexistent; kedit file); }
# shellcheck disable=SC2123,SC2329
missing_nano_kedit() { (kitty() { :; }; unset -f nano; PATH=/nonexistent; kedit file); }
# shellcheck disable=SC2123
missing_kitty_suedit() { (unset -f kitty sudo nano; PATH=/nonexistent; suedit file); }
# shellcheck disable=SC2123,SC2329
missing_sudo_suedit() { (kitty() { :; }; unset -f sudo nano; PATH=/nonexistent; suedit file); }
# shellcheck disable=SC2123,SC2329
missing_nano_suedit() { (kitty() { :; }; sudo() { :; }; unset -f nano; PATH=/nonexistent; suedit file); }
# shellcheck disable=SC2123
missing_kitty_sukitty() { (unset -f kitty sudo; PATH=/nonexistent; sukitty "${NO_ARGS[@]}"); }
# shellcheck disable=SC2123,SC2329
missing_sudo_sukitty() { (kitty() { :; }; unset -f sudo; PATH=/nonexistent; sukitty "${NO_ARGS[@]}"); }

assert_failure kedit 'kedit: required dependency not found: kitty' missing_kitty_kedit
assert_failure kedit 'kedit: required dependency not found: nano' missing_nano_kedit
assert_failure suedit 'suedit: required dependency not found: kitty' missing_kitty_suedit
assert_failure suedit 'suedit: required dependency not found: sudo' missing_sudo_suedit
assert_failure suedit 'suedit: required dependency not found: nano' missing_nano_suedit
assert_failure sukitty 'sukitty: required dependency not found: kitty' missing_kitty_sukitty
assert_failure sukitty 'sukitty: required dependency not found: sudo' missing_sudo_sukitty

KITTY_ARGS=()
KITTY_STATUS=0
kitty() { KITTY_ARGS=("$@"); return "$KITTY_STATUS"; }
nano() { :; }
sudo() { :; }

kedit 'one file'
[ "${#KITTY_ARGS[@]}" -eq 4 ] || fail "kedit changed its command shape"
[ "${KITTY_ARGS[0]}" = --detach ] && [ "${KITTY_ARGS[1]}" = nano ] &&
    [ "${KITTY_ARGS[2]}" = -- ] && [ "${KITTY_ARGS[3]}" = 'one file' ] ||
    fail "kedit did not safely forward one file"

kedit 'one file' '-second file'
[ "${#KITTY_ARGS[@]}" -eq 5 ] || fail "kedit dropped multiple files"
[ "${KITTY_ARGS[2]}" = -- ] && [ "${KITTY_ARGS[3]}" = 'one file' ] &&
    [ "${KITTY_ARGS[4]}" = '-second file' ] || fail "kedit argument forwarding is unsafe"

suedit 'one file' '-second file'
[ "${#KITTY_ARGS[@]}" -eq 7 ] || fail "suedit changed its command shape"
[ "${KITTY_ARGS[0]}" = --detach ] && [ "${KITTY_ARGS[1]}" = bash ] &&
    [ "${KITTY_ARGS[2]}" = -lc ] && [ "${KITTY_ARGS[3]}" = 'sudo nano -- "$@"' ] &&
    [ "${KITTY_ARGS[4]}" = bash ] && [ "${KITTY_ARGS[5]}" = 'one file' ] &&
    [ "${KITTY_ARGS[6]}" = '-second file' ] || fail "suedit argument forwarding is unsafe"

sukitty "${NO_ARGS[@]}"
[ "${#KITTY_ARGS[@]}" -eq 4 ] || fail "sukitty changed its command shape"
[ "${KITTY_ARGS[0]}" = --detach ] && [ "${KITTY_ARGS[1]}" = bash ] &&
    [ "${KITTY_ARGS[2]}" = -lc ] && [ "${KITTY_ARGS[3]}" = 'sudo -i' ] ||
    fail "sukitty command construction changed"

KITTY_STATUS=23
if kedit file >/dev/null 2>&1; then
    fail "kedit did not propagate Kitty launch failure"
else
    status=$?
fi
[ "$status" -eq 23 ] || fail "kedit changed Kitty launch failure status"

if suedit file >/dev/null 2>&1; then
    fail "suedit did not propagate Kitty launch failure"
else
    status=$?
fi
[ "$status" -eq 23 ] || fail "suedit changed Kitty launch failure status"

if sukitty "${NO_ARGS[@]}" >/dev/null 2>&1; then
    fail "sukitty did not propagate Kitty launch failure"
else
    status=$?
fi
[ "$status" -eq 23 ] || fail "sukitty changed Kitty launch failure status"

printf 'Shell helper tests: PASS\n'
