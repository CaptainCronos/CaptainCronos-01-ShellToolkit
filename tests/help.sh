#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/lib/cc-context.sh"
cc_context_init "$PROJECT_ROOT" "$PROJECT_ROOT"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/lib/cc-metadata.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

TEST_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

HELP_OUTPUT="$TEST_DIR/help.out"
REGISTRY_OUTPUT="$TEST_DIR/registry.tsv"
PARSED_OUTPUT="$TEST_DIR/help.tsv"

bash "$PROJECT_ROOT/tools/cc" help >"$HELP_OUTPUT" || fail 'cc help returned nonzero'
cc_registry_tsv >"$REGISTRY_OUTPUT"

awk '
    /^Commands:$/ { in_commands=1; next }
    /^Examples:$/ { in_commands=0 }
    in_commands && /^  [^.]+[.]+ / {
        row=substr($0, 3)
        match(row, /[.]+ /)
        command=substr(row, 1, RSTART - 1)
        description=substr(row, RSTART + RLENGTH)
        print command "\t" description
    }
' "$HELP_OUTPUT" >"$PARSED_OUTPUT"

expected_count="$(wc -l <"$REGISTRY_OUTPUT" | tr -d ' ')"
actual_count="$(wc -l <"$PARSED_OUTPUT" | tr -d ' ')"
[ "$actual_count" -eq "$expected_count" ] || fail 'help omitted or added public commands'
[ "$(cut -f1 "$PARSED_OUTPUT" | sort -u | wc -l | tr -d ' ')" -eq "$expected_count" ] ||
    fail 'help contains duplicate command entries'

while IFS=$'\t' read -r command script version category requires repository purpose; do
    matches="$(awk -F '\t' -v command="$command" '$1 == command { count++ } END { print count + 0 }' "$PARSED_OUTPUT")"
    [ "$matches" -eq 1 ] || fail "cc $command did not appear exactly once"
    actual_purpose="$(awk -F '\t' -v command="$command" '$1 == command { print substr($0, length($1) + 2) }' "$PARSED_OUTPUT")"
    [ "$actual_purpose" = "$purpose" ] || fail "cc $command purpose was associated incorrectly"
done <"$REGISTRY_OUTPUT"

for command in about drive-inventory monthly-health-timer system-update toolkit-update; do
    grep -Eq "^  ${command}[.]+ " "$HELP_OUTPUT" || fail "cc $command lacks a dotted leader"
done

leader_columns="$(awk '
    /^Commands:$/ { in_commands=1; next }
    /^Examples:$/ { in_commands=0 }
    in_commands && /^  [^.]+[.]+ / { match($0, /[.]+ /); print RSTART + RLENGTH - 2 }
' "$HELP_OUTPUT" | sort -u)"
[ "$(printf '%s\n' "$leader_columns" | wc -l | tr -d ' ')" -eq 1 ] ||
    fail 'help dotted leaders do not end at a consistent column'

for args in '' help --help -h; do
    # shellcheck disable=SC2086
    bash "$PROJECT_ROOT/tools/cc" $args >/dev/null || fail "cc ${args:-<no arguments>} help semantics changed"
done
if bash "$PROJECT_ROOT/tools/cc" definitely-not-a-command >/dev/null 2>&1; then
    fail 'unknown-command exit status changed'
fi

for environment in \
    'TERM=xterm-256color CC_COLOR_MODE=auto' \
    'TERM=xterm-256color CC_COLOR_MODE=never' \
    'NO_COLOR= TERM=xterm-256color CC_COLOR_MODE=always' \
    'TERM=dumb CC_COLOR_MODE=always'; do
    # These assignments are controlled test fixtures.
    # shellcheck disable=SC2086
    env $environment bash "$PROJECT_ROOT/tools/cc" help >"$TEST_DIR/mode.out"
    if LC_ALL=C grep -q $'\033' "$TEST_DIR/mode.out"; then
        fail "redirected help contained ANSI escapes under $environment"
    fi
done

printf 'Help presentation tests: PASS\n'
