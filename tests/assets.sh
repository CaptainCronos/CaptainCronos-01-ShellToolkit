#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

TEST_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

export CAPTAIN_CRONOS_ASSETS_DIR="$TEST_DIR/assets"
mkdir -p "$TEST_DIR/escape"

if bash "$PROJECT_ROOT/tools/cc" asset create '../escape' record >/dev/null 2>&1; then
    fail 'path-like asset type was accepted'
fi
[ ! -e "$TEST_DIR/escape/record.yaml" ] || fail 'asset escaped the configured asset root'

bash "$PROJECT_ROOT/tools/cc" asset create drives 'vendor/device 1' 'notes=quoted "value"' >/dev/null
asset_file="$TEST_DIR/assets/drives/vendor_device_1.yaml"
[ -f "$asset_file" ] || fail 'valid asset name was not safely normalized'
shown="$(bash "$PROJECT_ROOT/tools/cc" asset show drives 'vendor/device 1')"
printf '%s\n' "$shown" | grep -Fq 'quoted "value"' || fail 'asset data did not round-trip'

printf 'Asset safety tests: PASS\n'
