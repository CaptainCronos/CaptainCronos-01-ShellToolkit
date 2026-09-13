#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

output="$(env HOME="$TEST_DIR/home" CC_HOME="$TEST_DIR/home/.captaincronos" CC_HOST_ID=fixture-host \
    XDG_CURRENT_DESKTOP=Cinnamon XDG_SESSION_TYPE=wayland \
    bash "$PROJECT_ROOT/tools/commands/host" facts)"
printf '%s\n' "$output" | grep -q '^toolkit_host_id .*fixture-host' || fail 'host facts omitted configured host id'
printf '%s\n' "$output" | grep -q '^desktop_environment .*Cinnamon' || fail 'desktop evidence was not normalized'
printf '%s\n' "$output" | grep -q '^session_type .*wayland' || fail 'session evidence was not normalized'
[ ! -e "$TEST_DIR/home/.captaincronos" ] || fail 'host facts created persistent state'

output="$(env -u DESKTOP_SESSION HOME="$TEST_DIR/no-session" CC_HOME="$TEST_DIR/no-session/.captaincronos" CC_HOST_ID=no-session \
    XDG_CURRENT_DESKTOP= XDG_SESSION_TYPE= DISPLAY= bash "$PROJECT_ROOT/tools/commands/host" facts)"
printf '%s\n' "$output" | grep -q '^desktop_environment .*unknown' || fail 'missing desktop evidence was fabricated'
printf '%s\n' "$output" | grep -q '^session_type .*unknown' || fail 'missing session evidence was fabricated'
printf 'Host composition tests: PASS\n'
