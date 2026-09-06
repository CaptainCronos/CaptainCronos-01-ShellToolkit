#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
run_cc() { CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" bash "$PROJECT_ROOT/tools/cc" "$@"; }
assert_guard() {
    local label="$1" expected="$2"
    shift 2
    local status=0
    "$@" >"$TEST_DIR/output" 2>"$TEST_DIR/error" || status=$?
    [ "$status" -eq 1 ] || fail "$label returned $status, expected 1"
    grep -Fq -- "$expected" "$TEST_DIR/error" || fail "$label omitted expected diagnostic"
}

mkdir -p "$TEST_DIR/bin" "$TEST_DIR/runtime"
chmod 700 "$TEST_DIR/runtime"
cat >"$TEST_DIR/bin/cinnamon" <<'EOF_CINNAMON'
#!/usr/bin/env bash
printf '%s\n' "$*" >"${CC_DESKTOP_RELOAD_TRACE:?}"
printf 'mock Cinnamon replacement\n'
EOF_CINNAMON
chmod 755 "$TEST_DIR/bin/cinnamon"

assert_guard 'non-Cinnamon guard' 'supports Cinnamon only' \
    env PATH="$TEST_DIR/bin:$PATH" XDG_CURRENT_DESKTOP=GNOME XDG_SESSION_TYPE=x11 DISPLAY=:0 \
    XDG_RUNTIME_DIR="$TEST_DIR/runtime" bash "$PROJECT_ROOT/tools/cc" desktop-reload
assert_guard 'non-X11 guard' 'requires an X11 session' \
    env PATH="$TEST_DIR/bin:$PATH" XDG_CURRENT_DESKTOP=X-Cinnamon XDG_SESSION_TYPE=wayland DISPLAY=:0 \
    XDG_RUNTIME_DIR="$TEST_DIR/runtime" bash "$PROJECT_ROOT/tools/cc" desktop-reload
assert_guard 'display guard' 'requires an active X11 display' \
    env -u DISPLAY PATH="$TEST_DIR/bin:$PATH" XDG_CURRENT_DESKTOP=X-Cinnamon XDG_SESSION_TYPE=x11 \
    XDG_RUNTIME_DIR="$TEST_DIR/runtime" bash "$PROJECT_ROOT/tools/cc" desktop-reload
assert_guard 'runtime-directory guard' 'requires a private XDG_RUNTIME_DIR' \
    env PATH="$TEST_DIR/bin:$PATH" XDG_CURRENT_DESKTOP=X-Cinnamon XDG_SESSION_TYPE=x11 DISPLAY=:0 \
    XDG_RUNTIME_DIR="$TEST_DIR/missing-runtime" bash "$PROJECT_ROOT/tools/cc" desktop-reload

CC_DESKTOP_RELOAD_TRACE="$TEST_DIR/trace" \
    PATH="$TEST_DIR/bin:$PATH" XDG_CURRENT_DESKTOP=X-Cinnamon XDG_SESSION_TYPE=x11 DISPLAY=:0 \
    XDG_RUNTIME_DIR="$TEST_DIR/runtime" run_cc desktop-reload >"$TEST_DIR/output" ||
    fail 'guarded Cinnamon reload did not launch'

for _ in {1..50}; do
    [ -f "$TEST_DIR/trace" ] && break
    sleep 0.02
done
[ "$(cat "$TEST_DIR/trace")" = '--replace' ] || fail 'Cinnamon did not receive --replace'
log_file="$(sed -n 's/.*Log: //p' "$TEST_DIR/output")"
[ -n "$log_file" ] || fail 'reload did not report its log path'
[[ "$log_file" == "$TEST_DIR/runtime/"* ]] || fail 'reload log escaped XDG_RUNTIME_DIR'
[ -f "$log_file" ] || fail 'reload log was not retained'
[ "$(stat -c %a "$log_file")" = 600 ] || fail 'reload log was not private'
grep -Fq 'mock Cinnamon replacement' "$log_file" || fail 'reload log did not capture Cinnamon output'

printf 'Desktop reload tests: PASS\n'
