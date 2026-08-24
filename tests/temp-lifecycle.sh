#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cc-temp-lifecycle-test.XXXXXX")"
CHILD="$TEST_DIR/child.sh"
FAKE_BIN="$TEST_DIR/fake-bin"

cleanup() { rm -rf -- "$TEST_DIR"; }
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

mkdir -p "$FAKE_BIN"

cat >"$CHILD" <<'EOF_CHILD'
#!/usr/bin/env bash
set -u

if [ "${CHAIN_TRAPS:-0}" -eq 1 ]; then
    trap 'printf "exit\n" >>"$CC_TEST_MARKER"' EXIT
    trap 'printf "int\n" >>"$CC_TEST_MARKER"' INT
    trap 'printf "term\n" >>"$CC_TEST_MARKER"' TERM
fi
if [ "$CC_TEST_MODE" = ignore-int ]; then
    trap '' INT
fi

source "$CC_TEST_ROOT/lib/cc-common.sh"
if [ "$CC_TEST_MODE" = creation-term ]; then
    export CC_TEST_SIGNAL_PID="$$"
fi
cc_temp_file resource
printf '%s\n' "$resource" >"$CC_TEST_PATH"

case "$CC_TEST_MODE" in
    exit) exit 0 ;;
    fail) exit 37 ;;
    int) kill -s INT "$$" ;;
    term) kill -s TERM "$$" ;;
    creation-term) exit 98 ;;
    kill) kill -s KILL "$$" ;;
    identity-change)
        rm -f -- "$resource"
        : >"$resource"
        exit 37
        ;;
    ignore-int)
        kill -s INT "$$"
        printf 'continued\n' >"$CC_TEST_MARKER"
        cc_temp_remove "$resource"
        exit 0
        ;;
    *) exit 2 ;;
esac
EOF_CHILD
chmod 700 "$CHILD"

cat >"$FAKE_BIN/mktemp" <<'EOF_MKTEMP'
#!/usr/bin/env bash
created="$("$CC_TEST_REAL_MKTEMP" "$@")" || exit
printf '%s\n' "$created" >"$CC_TEST_CREATED_PATH"
kill -s TERM "$CC_TEST_SIGNAL_PID"
printf '%s\n' "$created"
EOF_MKTEMP
chmod 700 "$FAKE_BIN/mktemp"

run_child() {
    local mode="$1" root="$2" path_file="$3" marker="$4" chain="${5:-0}"
    env \
        TMPDIR="$root" \
        CC_TEST_ROOT="$PROJECT_ROOT" \
        CC_TEST_MODE="$mode" \
        CC_TEST_PATH="$path_file" \
        CC_TEST_MARKER="$marker" \
        CHAIN_TRAPS="$chain" \
        bash "$CHILD"
}

assert_child_cleanup() {
    local mode="$1" expected_status="$2" chain="${3:-0}"
    local root="$TEST_DIR/$mode-root" path_file="$TEST_DIR/$mode.path" marker="$TEST_DIR/$mode.marker"
    local status resource
    mkdir -p "$root"
    set +e
    run_child "$mode" "$root" "$path_file" "$marker" "$chain" 2>/dev/null
    status=$?
    set -e
    [ "$status" -eq "$expected_status" ] || fail "$mode status was $status, expected $expected_status"
    resource="$(<"$path_file")"
    [ ! -e "$resource" ] && [ ! -L "$resource" ] || fail "$mode left its registered resource"
    if [ "$chain" -eq 1 ]; then
        grep -Fxq exit "$marker" || fail "$mode did not preserve the prior EXIT trap"
        grep -Fxq "$mode" "$marker" || fail "$mode did not preserve its prior signal trap"
    fi
}

source "$PROJECT_ROOT/lib/cc-common.sh"

# Normal deterministic removal of both resource types, including repeat no-op.
normal_root="$TEST_DIR/normal"
mkdir -p "$normal_root"
TMPDIR="$normal_root"
normal_file=""
normal_dir=""
cc_temp_file normal_file
cc_temp_dir normal_dir
[ -f "$normal_file" ] || fail "temporary file was not created"
[ -d "$normal_dir" ] || fail "temporary directory was not created"
cc_temp_remove "$normal_file"
cc_temp_remove "$normal_file"
cc_temp_remove "$normal_dir"
[ ! -e "$normal_file" ] || fail "normal file cleanup failed"
[ ! -e "$normal_dir" ] || fail "normal directory cleanup failed"

# EXIT, command failure, catchable signals, chaining, and status integrity.
assert_child_cleanup exit 0
assert_child_cleanup fail 37
assert_child_cleanup int 130 1
assert_child_cleanup term 143 1

# A signal delivered in the narrow interval after mktemp creates a path but
# before registration is deferred until creation and registration are complete.
creation_root="$TEST_DIR/creation-term-root"
creation_path_file="$TEST_DIR/creation-term-created.path"
creation_marker="$TEST_DIR/creation-term.marker"
mkdir -p "$creation_root"
set +e
env \
    PATH="$FAKE_BIN:$PATH" \
    TMPDIR="$creation_root" \
    CC_TEST_ROOT="$PROJECT_ROOT" \
    CC_TEST_MODE=creation-term \
    CC_TEST_PATH="$TEST_DIR/creation-term-unused.path" \
    CC_TEST_MARKER="$creation_marker" \
    CC_TEST_CREATED_PATH="$creation_path_file" \
    CC_TEST_REAL_MKTEMP="$(command -v mktemp)" \
    CHAIN_TRAPS=1 \
    bash "$CHILD" 2>/dev/null
creation_status=$?
set -e
[ "$creation_status" -eq 143 ] || fail "creation-window TERM status was $creation_status"
creation_resource="$(<"$creation_path_file")"
[ ! -e "$creation_resource" ] || fail "creation-window TERM left its resource"
grep -Fxq term "$creation_marker" || fail "creation-window TERM did not chain prior handler"
grep -Fxq exit "$creation_marker" || fail "creation-window TERM did not chain prior EXIT handler"

# A pre-existing ignored signal remains ignored; preserving it necessarily means
# that signal is not available as a lifecycle cleanup hook.
ignore_root="$TEST_DIR/ignore-int-root"
ignore_path_file="$TEST_DIR/ignore-int.path"
ignore_marker="$TEST_DIR/ignore-int.marker"
mkdir -p "$ignore_root"
run_child ignore-int "$ignore_root" "$ignore_path_file" "$ignore_marker"
[ "$(cat "$ignore_marker")" = continued ] || fail "ignored INT trap was overwritten"
[ ! -e "$(<"$ignore_path_file")" ] || fail "ignored-signal fixture did not clean normally"

# A cleanup error cannot replace the command's original failure status. The
# identity-changed path is foreign state and must be left for fixture cleanup.
identity_root="$TEST_DIR/identity-change-root"
identity_path_file="$TEST_DIR/identity-change.path"
mkdir -p "$identity_root"
set +e
run_child identity-change "$identity_root" "$identity_path_file" "$TEST_DIR/identity.marker" 0 2>/dev/null
identity_status=$?
set -e
[ "$identity_status" -eq 37 ] || fail "cleanup failure hid original status 37"
[ -e "$(<"$identity_path_file")" ] || fail "identity-changed foreign path was removed"

# SIGKILL is intentionally uncatchable. Its residue remains only inside this
# disposable test root and is removed by the parent fixture's exact cleanup.
kill_root="$TEST_DIR/kill-root"
kill_path_file="$TEST_DIR/kill.path"
mkdir -p "$kill_root"
set +e
run_child kill "$kill_root" "$kill_path_file" "$TEST_DIR/kill.marker" 0 2>/dev/null
kill_status=$?
set -e
[ "$kill_status" -eq 137 ] || fail "SIGKILL status was $kill_status, expected 137"
kill_resource="$(<"$kill_path_file")"
[ -e "$kill_resource" ] || fail "SIGKILL fixture incorrectly claimed cleanup"

# Nested callers share one per-process registry without discarding outer state.
nested_root="$TEST_DIR/nested"
mkdir -p "$nested_root"
TMPDIR="$nested_root"
outer_resource=""
cc_temp_file outer_resource
nested_allocate() {
    cc_temp_dir nested_resource
}
nested_resource=""
nested_allocate
[ -f "$outer_resource" ] && [ -d "$nested_resource" ] || fail "nested allocation failed"
cc_temp_remove "$nested_resource"
[ -f "$outer_resource" ] || fail "nested cleanup removed outer state"
cc_temp_remove "$outer_resource"

# Atomic publication unregisters only the old staging name and retains output.
atomic_root="$TEST_DIR/atomic"
mkdir -p "$atomic_root"
staging=""
cc_temp_file staging "$atomic_root/.result.XXXXXX"
printf 'published\n' >"$staging"
mv "$staging" "$atomic_root/result"
cc_temp_unregister "$staging"
cc_temp_cleanup_all
[ "$(cat "$atomic_root/result")" = published ] || fail "committed output was deleted"

# Unsafe cleanup paths are rejected before registry lookup.
cc_temp_remove "" >/dev/null 2>&1 && fail "empty cleanup path was accepted"
cc_temp_remove / >/dev/null 2>&1 && fail "root cleanup path was accepted"
cc_temp_remove ../escape >/dev/null 2>&1 && fail "relative escape was accepted"

# Replacing a registered file with a symlink never follows or removes its target.
symlink_root="$TEST_DIR/symlink"
mkdir -p "$symlink_root"
printf 'keep\n' >"$symlink_root/target"
symlink_path=""
cc_temp_file symlink_path "$symlink_root/resource.XXXXXX"
rm -f -- "$symlink_path"
ln -s "$symlink_root/target" "$symlink_path"
if cc_temp_remove "$symlink_path" 2>/dev/null; then
    fail "changed temporary identity was accepted"
fi
[ "$(cat "$symlink_root/target")" = keep ] || fail "symlink target was changed"
[ -L "$symlink_path" ] || fail "foreign replacement was removed"

# Default allocation honors a caller-owned disposable TMPDIR exactly.
custom_root="$TEST_DIR/custom-tmp"
mkdir -p "$custom_root"
TMPDIR="$custom_root"
custom_file=""
cc_temp_file custom_file
case "$custom_file" in
    "$custom_root"/*) ;;
    *) fail "custom TMPDIR was not honored" ;;
esac
cc_temp_remove "$custom_file"
[ -z "$(find "$custom_root" -mindepth 1 -print -quit)" ] || fail "custom TMPDIR retained a resource"

# The major direct consumers leave no resources in an isolated TMPDIR.
consumer_root="$TEST_DIR/consumers"
mkdir -p "$consumer_root"
TMPDIR="$consumer_root" bash "$PROJECT_ROOT/tools/cc" docs check >/dev/null \
    || fail "docs check consumer failed"
[ -z "$(find "$consumer_root" -mindepth 1 -print -quit)" ] || fail "docs check retained temporary state"
TMPDIR="$consumer_root" bash "$PROJECT_ROOT/tools/cc" verify >/dev/null \
    || fail "verify consumer failed"
[ -z "$(find "$consumer_root" -mindepth 1 -print -quit)" ] || fail "verify retained temporary state"

printf 'Temporary-resource lifecycle tests: PASS\n'
