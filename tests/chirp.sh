#!/usr/bin/env bash

set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
contains() { grep -Fq -- "$2" "$1" || fail "$3"; }

mkdir -p "$TEST_DIR/bin" "$TEST_DIR/opt/chirp" "$TEST_DIR/apps" "$TEST_DIR/user-apps" "$TEST_DIR/home/.local/pipx/venvs/chirp" "$TEST_DIR/home/.local/bin" "$TEST_DIR/home/.chirp"
printf '\177ELFCHIRP Chirp-next-20260904' >"$TEST_DIR/download.AppImage"
chmod 755 "$TEST_DIR/download.AppImage"
printf '<svg xmlns="http://www.w3.org/2000/svg"/>\n' >"$TEST_DIR/icon.svg"
printf '#!/usr/bin/env bash\nwhile [ "$#" -gt 0 ]; do\n  if [ "$1" = --output ]; then cp "${CC_CHIRP_TEST_DOWNLOAD:?}" "$2"; exit 0; fi\n  shift\ndone\nexit 1\n' >"$TEST_DIR/bin/curl"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >>"${CC_CHIRP_PIPX_TRACE:?}"\nrm -rf "${CC_CHIRP_TEST_PIPX_VENV:?}"\n' >"$TEST_DIR/bin/pipx"
chmod 755 "$TEST_DIR/bin/curl" "$TEST_DIR/bin/pipx"
printf legacy >"$TEST_DIR/home/.local/bin/chirp"
printf radio-image >"$TEST_DIR/home/saved-radio.img"
printf radio-csv >"$TEST_DIR/home/saved-radio.csv"
printf '[Desktop Entry]\nName=CHIRP old\nExec=chirp\n' >"$TEST_DIR/user-apps/chirp-old.desktop"

run_chirp() {
    env HOME="$TEST_DIR/home" PATH="$TEST_DIR/bin:$PATH" CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" \
      CC_CHIRP_DIR="$TEST_DIR/opt/chirp" CC_CHIRP_BIN_DIR="$TEST_DIR/local-bin" \
      CC_CHIRP_APPLICATIONS_DIR="$TEST_DIR/apps" CC_CHIRP_USER_APPLICATIONS_DIR="$TEST_DIR/user-apps" \
      CC_CHIRP_ICON="$TEST_DIR/icons/chirp.svg" CC_CHIRP_SUDO=env CC_CHIRP_MIN_SIZE=1 \
      CC_CHIRP_DOWNLOAD_URL="https://fixture.invalid/Chirp-next.AppImage" CC_CHIRP_TEST_DOWNLOAD="$TEST_DIR/download.AppImage" CC_CHIRP_RELEASE_VERSION=next-20260904 \
      CC_CHIRP_ICON_SOURCE="$TEST_DIR/icon.svg" CC_CHIRP_PIPX_TRACE="$TEST_DIR/pipx.trace" CC_CHIRP_TEST_PIPX_VENV="$TEST_DIR/home/.local/pipx/venvs/chirp" \
      bash "$PROJECT_ROOT/tools/cc" chirp "$@"
}

run_chirp install >"$TEST_DIR/preview"
[ ! -e "$TEST_DIR/opt/chirp/Chirp.AppImage" ] || fail 'install preview changed the deployment'
[ -d "$TEST_DIR/home/.local/pipx/venvs/chirp" ] || fail 'install preview removed pipx CHIRP'
contains "$TEST_DIR/preview" 'remove pipx CHIRP only after deployment validation' 'preview omitted migration guard'
run_chirp status >"$TEST_DIR/pre-status"
contains "$TEST_DIR/pre-status" 'pipx:      conflict' 'status did not detect legacy pipx CHIRP'

run_chirp install --apply >"$TEST_DIR/install"
[ -x "$TEST_DIR/opt/chirp/Chirp.AppImage" ] || fail 'install did not deploy AppImage'
[ "$(readlink "$TEST_DIR/local-bin/chirp")" = "$TEST_DIR/opt/chirp/Chirp.AppImage" ] || fail 'install did not create canonical link'
[ -f "$TEST_DIR/apps/chirp.desktop" ] || fail 'install did not create launcher'
[ -f "$TEST_DIR/icons/chirp.svg" ] || fail 'install did not install icon'
[ -d "$TEST_DIR/home/.chirp" ] || fail 'install removed user data'
[ -f "$TEST_DIR/home/saved-radio.img" ] || fail 'install removed externally saved radio image'
[ -f "$TEST_DIR/home/saved-radio.csv" ] || fail 'install removed externally saved radio CSV'
[ ! -d "$TEST_DIR/home/.local/pipx/venvs/chirp" ] || fail 'install did not migrate pipx CHIRP after validation'

ln -sfn /wrong "$TEST_DIR/local-bin/chirp"
printf '[Desktop Entry]\nName=CHIRP stale\nExec=chirp\n' >"$TEST_DIR/user-apps/chirp-stale.desktop"
run_chirp repair >"$TEST_DIR/repair-preview"
[ -f "$TEST_DIR/user-apps/chirp-stale.desktop" ] || fail 'repair preview removed duplicate launcher'
contains "$TEST_DIR/repair-preview" 'remove duplicate launcher:' 'repair preview missed duplicate launcher'
run_chirp repair --apply >"$TEST_DIR/repair"
[ "$(readlink "$TEST_DIR/local-bin/chirp")" = "$TEST_DIR/opt/chirp/Chirp.AppImage" ] || fail 'repair did not normalize link'
[ ! -e "$TEST_DIR/user-apps/chirp-stale.desktop" ] || fail 'repair did not remove duplicate launcher'
[ -d "$TEST_DIR/home/.chirp" ] || fail 'repair removed user data'

run_chirp update >"$TEST_DIR/update-preview"
contains "$TEST_DIR/update-preview" 'comparison: installed next-20260904 is current' 'update did not compare installed and official releases'

run_chirp status >"$TEST_DIR/status"
contains "$TEST_DIR/status" 'AppImage:  installed' 'status did not report AppImage'
contains "$TEST_DIR/status" 'Command:   canonical' 'status did not report command'
contains "$TEST_DIR/status" 'Launchers: 1' 'status did not report canonical launcher count'
contains "$TEST_DIR/status" 'Release:   next-20260904' 'status did not recognize official AppImage release capitalization'

# Discovery must not depend on the forbidden parent index. A fixture curl accepts
# HEAD only for the known release artifact and records every requested URL.
cat >"$TEST_DIR/bin/curl" <<'EOF_CURL'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${CC_CHIRP_CURL_TRACE:?}"
case "$*" in
  *--head*"/next-20260904/Chirp-next-20260904-x86_64.AppImage"*) exit 0 ;;
  *) exit 22 ;;
esac
EOF_CURL
chmod 755 "$TEST_DIR/bin/curl"
cat >"$TEST_DIR/bin/date" <<'EOF_DATE'
#!/usr/bin/env bash
case "$*" in
  *"0 days ago"*) printf '20260909\n' ;;
  *"1 days ago"*) printf '20260908\n' ;;
  *"2 days ago"*) printf '20260907\n' ;;
  *"3 days ago"*) printf '20260906\n' ;;
  *"4 days ago"*) printf '20260905\n' ;;
  *) printf '20260904\n' ;;
esac
EOF_DATE
chmod 755 "$TEST_DIR/bin/date"
: >"$TEST_DIR/curl.trace"
env HOME="$TEST_DIR/home" PATH="$TEST_DIR/bin:$PATH" CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" \
  CC_CHIRP_DIR="$TEST_DIR/opt/chirp" CC_CHIRP_BIN_DIR="$TEST_DIR/local-bin" \
  CC_CHIRP_APPLICATIONS_DIR="$TEST_DIR/apps" CC_CHIRP_USER_APPLICATIONS_DIR="$TEST_DIR/user-apps" \
  CC_CHIRP_ICON="$TEST_DIR/icons/chirp.svg" CC_CHIRP_SUDO=env CC_CHIRP_MIN_SIZE=1 \
  CC_CHIRP_DISCOVERY_DAYS=7 CC_CHIRP_CURL_TRACE="$TEST_DIR/curl.trace" \
  bash "$PROJECT_ROOT/tools/cc" chirp update >"$TEST_DIR/discovery"
contains "$TEST_DIR/discovery" 'official release: next-20260904' 'bounded discovery did not find current release'
contains "$TEST_DIR/discovery" 'Chirp-next-20260904-x86_64.AppImage' 'discovery constructed the wrong AppImage filename'
if grep -Fq 'https://archive.chirpmyradio.com/chirp_next/' "$TEST_DIR/curl.trace" && grep -Fxq -- '--fail --location --proto =https --tlsv1.2 --silent --show-error --head --output /dev/null https://archive.chirpmyradio.com/chirp_next/' "$TEST_DIR/curl.trace"; then
    fail 'discovery requested the forbidden parent archive index'
fi

# Exhausted discovery must fail without changing the installed artifact or user data.
printf '#!/usr/bin/env bash\nexit 22\n' >"$TEST_DIR/bin/curl"
chmod 755 "$TEST_DIR/bin/curl"
before="$(sha256sum "$TEST_DIR/opt/chirp/Chirp.AppImage")"
if env HOME="$TEST_DIR/home" PATH="$TEST_DIR/bin:$PATH" CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" \
  CC_CHIRP_DIR="$TEST_DIR/opt/chirp" CC_CHIRP_BIN_DIR="$TEST_DIR/local-bin" \
  CC_CHIRP_APPLICATIONS_DIR="$TEST_DIR/apps" CC_CHIRP_USER_APPLICATIONS_DIR="$TEST_DIR/user-apps" \
  CC_CHIRP_ICON="$TEST_DIR/icons/chirp.svg" CC_CHIRP_SUDO=env CC_CHIRP_MIN_SIZE=1 CC_CHIRP_DISCOVERY_DAYS=2 \
  bash "$PROJECT_ROOT/tools/cc" chirp update --apply >"$TEST_DIR/discovery-fail" 2>&1; then
    fail 'exhausted release discovery unexpectedly succeeded'
fi
[ "$before" = "$(sha256sum "$TEST_DIR/opt/chirp/Chirp.AppImage")" ] || fail 'failed discovery changed installed AppImage'
[ -d "$TEST_DIR/home/.chirp" ] || fail 'failed discovery removed user data'
[ -f "$TEST_DIR/home/saved-radio.img" ] || fail 'failed discovery removed radio image'
[ -f "$TEST_DIR/home/saved-radio.csv" ] || fail 'failed discovery removed radio CSV'

printf 'CHIRP deployment tests: PASS\n'
