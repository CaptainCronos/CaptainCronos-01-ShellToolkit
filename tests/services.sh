#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-services.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[ "$(cc_program_get service-manager)" = "systemctl" ] || fail "service-manager capability did not resolve"
[ "$(cc_program_get system-log)" = "journalctl" ] || fail "system-log capability did not resolve"
_cc_service_exists system systemd-journald.service || fail "real service existence detection failed"
_cc_service_is_active system systemd-journald.service || fail "real active-service detection failed"
_cc_log_since system "1 minute ago" 1 >/dev/null || fail "real system-log query failed"

TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
TRACE_FILE="$TEST_DIR/trace"
export TRACE_FILE

sed \
    -e 's/CC_SERVICE_MANAGER="systemctl"/CC_SERVICE_MANAGER="service-manager-mock"/' \
    -e 's/CC_SYSTEM_LOG="journalctl"/CC_SYSTEM_LOG="system-log-mock"/' \
    "$PROJECT_ROOT/config/programs.conf" > "$TEST_DIR/programs.conf"

cat > "$TEST_DIR/service-manager-mock" <<'EOF_MANAGER'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TRACE_FILE"
args=("$@")
if [ "${args[0]:-}" = "--user" ]; then
    args=("${args[@]:1}")
fi
case "${args[0]:-}" in
    show)
        unit="${args[${#args[@]}-1]}"
        [ "$unit" = "missing.service" ] && printf '%s\n' not-found || printf '%s\n' loaded
        ;;
    is-active)
        [ "${args[${#args[@]}-1]}" = "active.service" ]
        ;;
    is-enabled)
        [ "${args[${#args[@]}-1]}" = "enabled.service" ]
        ;;
    list-timers) printf '%s\n' 'mock.timer loaded active waiting' ;;
    list-unit-files) printf '%s\n' 'mock.service enabled' ;;
    get-default) printf '%s\n' multi-user.target ;;
esac
EOF_MANAGER

cat > "$TEST_DIR/system-log-mock" <<'EOF_LOG'
#!/usr/bin/env bash
printf 'log %s\n' "$*" >> "$TRACE_FILE"
printf '%s\n' 'mock journal record'
EOF_LOG

chmod 755 "$TEST_DIR/service-manager-mock" "$TEST_DIR/system-log-mock"
PATH="$TEST_DIR:$PATH"
export PATH
CC_PROGRAMS_CONFIG="$TEST_DIR/programs.conf"
CC_PROGRAMS_LOADED=0
export CC_PROGRAMS_CONFIG

_cc_service_exists system active.service || fail "mock service existence detection failed"
if _cc_service_exists system missing.service; then
    fail "missing service was reported as present"
fi
_cc_service_is_active system active.service || fail "active service was not detected"
if _cc_service_is_active system inactive.service; then
    fail "inactive service was reported active"
fi
_cc_service_is_enabled system enabled.service || fail "enabled service was not detected"
if _cc_service_is_enabled system disabled.service; then
    fail "disabled service was reported enabled"
fi
[ "$(_cc_service_status system inactive.service)" = "installed-not-active" ] || fail "inactive status was incorrect"

: > "$TRACE_FILE"
_cc_service_exists user active.service || fail "user-scope query failed"
grep -q '^--user show ' "$TRACE_FILE" || fail "user query lost user scope"
: > "$TRACE_FILE"
_cc_service_exists system active.service || fail "system-scope query failed"
grep -q '^show ' "$TRACE_FILE" || fail "system query unexpectedly used user scope"

: > "$TRACE_FILE"
system_dry_run="$(CC_SERVICE_DRY_RUN=1 _cc_service_start system example.service)"
[ ! -s "$TRACE_FILE" ] || fail "system dry-run executed the service manager"
printf '%s\n' "$system_dry_run" | grep -q 'sudo service-manager-mock start example.service' || fail "system dry-run omitted privilege handling"
user_dry_run="$(CC_SERVICE_DRY_RUN=1 _cc_service_enable_now user example.timer)"
[ ! -s "$TRACE_FILE" ] || fail "user dry-run executed the service manager"
printf '%s\n' "$user_dry_run" | grep -q 'service-manager-mock --user enable --now example.timer' || fail "user dry-run scope was incorrect"
if printf '%s\n' "$user_dry_run" | grep -q sudo; then
    fail "user dry-run requested unnecessary privilege"
fi
reload_dry_run="$(CC_SERVICE_DRY_RUN=1 _cc_service_daemon_reload user)"
[ ! -s "$TRACE_FILE" ] || fail "daemon-reload dry-run executed the service manager"
printf '%s\n' "$reload_dry_run" | grep -q 'service-manager-mock --user daemon-reload' || fail "user daemon-reload scope was incorrect"

: > "$TRACE_FILE"
[ "$(_cc_log_since system "1 hour ago" 10)" = "mock journal record" ] || fail "semantic system-log query failed"
grep -q '^log --since 1 hour ago --no-pager --output=short-iso -n 10$' "$TRACE_FILE" || fail "system-log arguments were incorrect"
: > "$TRACE_FILE"
_cc_log_unit user example.service today 5 >/dev/null || fail "user-unit log query failed"
grep -q '^log --user --unit example.service ' "$TRACE_FILE" || fail "user log query lost user scope"

cc_platform_init_system() { printf '%s\n' openrc; }
[ "$(_cc_service_manager)" = "rc-service" ] || fail "OpenRC abstraction was not preserved"
openrc_dry_run="$(CC_SERVICE_DRY_RUN=1 _cc_service_enable system example)"
printf '%s\n' "$openrc_dry_run" | grep -q 'sudo rc-update add example default' || fail "OpenRC enable abstraction was incorrect"
cc_platform_init_system() { printf '%s\n' freebsd-rc; }
[ "$(_cc_service_manager)" = "service" ] || fail "FreeBSD rc abstraction was not preserved"

printf 'Service management tests: PASS\n'
