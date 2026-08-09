#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-config.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

TEST_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

export CAPTAIN_CRONOS_CONFIG_DIR="$TEST_DIR/config"
marker="$TEST_DIR/executed"

cc_config_init
[ "$(cc_config_get REPO_ROOT)" = "$HOME/GitHub" ] || fail 'safe HOME expansion changed'

payload="\$(touch $marker)"
cc_config_set INJECTION_TEST "$payload"
[ "$(cc_config_get INJECTION_TEST)" = "$payload" ] || fail 'literal command substitution was not preserved'
[ ! -e "$marker" ] || fail 'configuration value executed as shell code'

quoted='spaces "quotes" \\ backslash $PATH ${USER}'
cc_config_set QUOTING_TEST "$quoted"
[ "$(cc_config_get QUOTING_TEST)" = "$quoted" ] || fail 'configuration value did not round-trip safely'
cc_config_set HOMELESS_TEST '$HOMELESS/path'
[ "$(cc_config_get HOMELESS_TEST)" = '$HOMELESS/path' ] || fail 'HOME expansion changed a longer variable name'
if cc_config_set MULTILINE_TEST $'first\nsecond'; then
    fail 'multiline value that would corrupt the line format was accepted'
fi

if cc_config_set 'INVALID.KEY' value; then
    fail 'invalid configuration key was accepted'
fi
if cc_config_get 'INVALID.*' fallback >/dev/null; then
    fail 'invalid configuration lookup key was accepted'
fi

printf 'Configuration safety tests: PASS\n'
