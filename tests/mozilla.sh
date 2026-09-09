#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_contains() { grep -Fq -- "$2" "$1" || fail "$3"; }

mkdir -p "$TEST_DIR/bin" "$TEST_DIR/opt/firefox" "$TEST_DIR/apps" "$TEST_DIR/user-apps" "$TEST_DIR/archive/thunderbird"
printf '#!/usr/bin/env bash\nexit 0\n' >"$TEST_DIR/opt/firefox/firefox"
chmod 755 "$TEST_DIR/opt/firefox/firefox"
printf '[Desktop Entry]\nName=Firefox old\nExec=firefox\n' >"$TEST_DIR/user-apps/firefox-old.desktop"
cat >"$TEST_DIR/bin/snap" <<'EOF_SNAP'
#!/usr/bin/env bash
if [ "$1" = list ] && [ "$2" = firefox ]; then exit 0; fi
if [ "$1" = remove ]; then printf '%s\n' "$2" >>"${CC_MOZILLA_SNAP_TRACE:?}"; exit 0; fi
exit 1
EOF_SNAP
chmod 755 "$TEST_DIR/bin/snap"
printf '#!/usr/bin/env bash\nexit 0\n' >"$TEST_DIR/archive/thunderbird/thunderbird"
chmod 755 "$TEST_DIR/archive/thunderbird/thunderbird"
cat >"$TEST_DIR/bin/curl" <<'EOF_CURL'
#!/usr/bin/env bash
while [ "$#" -gt 0 ]; do
    if [ "$1" = --output ]; then cp /dev/null "$2"; exit 0; fi
    shift
done
exit 1
EOF_CURL
cat >"$TEST_DIR/bin/tar" <<'EOF_TAR'
#!/usr/bin/env bash
while [ "$#" -gt 0 ]; do
    if [ "$1" = -C ]; then cp -a "${CC_MOZILLA_TEST_ARCHIVE:?}/thunderbird" "$2/"; exit 0; fi
    shift
done
exit 1
EOF_TAR
chmod 755 "$TEST_DIR/bin/curl" "$TEST_DIR/bin/tar"

run_mozilla() {
    PATH="$TEST_DIR/bin:$PATH" CC_MOZILLA_PREFIX="$TEST_DIR/opt" CC_MOZILLA_BIN_DIR="$TEST_DIR/local-bin" \
    CC_MOZILLA_APPLICATIONS_DIR="$TEST_DIR/apps" CC_MOZILLA_USER_APPLICATIONS_DIR="$TEST_DIR/user-apps" \
    CC_MOZILLA_SUDO=env CC_MOZILLA_SNAP_TRACE="$TEST_DIR/snap.trace" \
    CC_MOZILLA_TEST_ARCHIVE="$TEST_DIR/archive" \
    CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" bash "$PROJECT_ROOT/tools/cc" mozilla "$@"
}

run_mozilla repair firefox >"$TEST_DIR/preview"
[ ! -e "$TEST_DIR/local-bin/firefox" ] || fail 'dry run created a command symlink'
[ -f "$TEST_DIR/user-apps/firefox-old.desktop" ] || fail 'dry run removed a duplicate launcher'
assert_contains "$TEST_DIR/preview" 'remove Snap package: firefox' 'preview omitted Snap conflict'
assert_contains "$TEST_DIR/preview" 'remove duplicate launcher:' 'preview omitted stale launcher detection'

run_mozilla repair firefox --apply >"$TEST_DIR/apply"
[ "$(readlink "$TEST_DIR/local-bin/firefox")" = "$TEST_DIR/opt/firefox/firefox" ] || fail 'repair did not create canonical command symlink'
[ -f "$TEST_DIR/apps/firefox.desktop" ] || fail 'repair did not create canonical launcher'
[ ! -e "$TEST_DIR/user-apps/firefox-old.desktop" ] || fail 'repair did not remove duplicate launcher'
[ "$(cat "$TEST_DIR/snap.trace")" = firefox ] || fail 'repair did not remove Firefox Snap conflict'
assert_contains "$TEST_DIR/apps/firefox.desktop" "Exec=$TEST_DIR/opt/firefox/firefox %u" 'launcher does not use archive binary'

run_mozilla status firefox >"$TEST_DIR/status"
assert_contains "$TEST_DIR/status" 'Archive:  installed' 'status did not detect archive'
assert_contains "$TEST_DIR/status" 'Command:  canonical' 'status did not detect command link'
assert_contains "$TEST_DIR/status" 'Launcher count: 1' 'status did not report one canonical launcher'

run_mozilla install thunderbird --apply >"$TEST_DIR/install"
[ -x "$TEST_DIR/opt/thunderbird/thunderbird" ] || fail 'install did not deploy the Thunderbird archive'
[ "$(readlink "$TEST_DIR/local-bin/thunderbird")" = "$TEST_DIR/opt/thunderbird/thunderbird" ] || fail 'install did not create Thunderbird command link'
[ -f "$TEST_DIR/apps/thunderbird.desktop" ] || fail 'install did not create Thunderbird launcher'

printf 'Mozilla deployment tests: PASS\n'
