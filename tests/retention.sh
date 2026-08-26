#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_contains() {
    local file="$1" expected="$2" message="$3"
    grep -Fq -- "$expected" "$file" || fail "$message"
}

FIXTURE_HOME="$TEST_DIR/home"
CC_FIXTURE_HOME="$FIXTURE_HOME/.captaincronos"
HOST_ID="fixture-host"
HOST_HOME="$CC_FIXTURE_HOME/hosts/$HOST_ID"
mkdir -p "$FIXTURE_HOME"

run_maintenance() {
    env HOME="$FIXTURE_HOME" CC_HOME="$CC_FIXTURE_HOME" CC_HOST_ID="$HOST_ID" \
        CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" TERM=dumb NO_COLOR= \
        bash "$PROJECT_ROOT/tools/cc" maintenance "$@"
}

fingerprint() {
    find -P "$FIXTURE_HOME" -mindepth 1 -printf '%P|%y|%s|%T@|%m\n' 2>/dev/null | LC_ALL=C sort
}

# Empty and missing roots are normal and inventory is deterministic and zero-write.
fingerprint >"$TEST_DIR/empty-before"
run_maintenance inventory --format tsv >"$TEST_DIR/empty-one"
run_maintenance inventory --format tsv >"$TEST_DIR/empty-two"
fingerprint >"$TEST_DIR/empty-after"
cmp -s "$TEST_DIR/empty-before" "$TEST_DIR/empty-after" || fail 'empty inventory wrote into HOME'
cmp -s "$TEST_DIR/empty-one" "$TEST_DIR/empty-two" || fail 'empty inventory was nondeterministic'
assert_contains "$TEST_DIR/empty-one" $'monthly-health\tmonthly-health\thistorical-record' 'report class was absent'
assert_contains "$TEST_DIR/empty-one" $'installer-backups\tinstaller\trecovery-artifact' 'backup class was absent'
assert_contains "$TEST_DIR/empty-one" $'repository-bundles\trepositories\tuser-export' 'bundle class was absent'
assert_contains "$TEST_DIR/empty-one" $'reserved-cache\tcache\tregenerable-cache' 'cache class was absent'

# Populate every active canonical producer class plus one unclassified path.
mkdir -p \
    "$HOST_HOME/reports/monthly-health" \
    "$HOST_HOME/reports/drives/qualification/drive-1" \
    "$HOST_HOME/assets/drives" \
    "$HOST_HOME/assets/.history/drives" \
    "$HOST_HOME/logs" \
    "$HOST_HOME/cache" \
    "$HOST_HOME/plugins/local" \
    "$FIXTURE_HOME/.config/systemd/user" \
    "$CC_FIXTURE_HOME/backups/20260801-120000" \
    "$CC_FIXTURE_HOME/repo-bundles" \
    "$CC_FIXTURE_HOME/mystery"
printf '1234' >"$HOST_HOME/reports/monthly-health/monthly-health-20260701-120000.log"
printf '123456' >"$HOST_HOME/reports/monthly-health/monthly-health-20260801-120000.log"
ln -s "monthly-health-20260801-120000.log" "$HOST_HOME/reports/monthly-health/latest.log"
printf 'smart' >"$HOST_HOME/reports/drives/qualification/drive-1/summary.txt"
printf 'asset' >"$HOST_HOME/assets/drives/serial.yaml"
printf 'history' >"$HOST_HOME/assets/.history/drives/serial.log"
printf 'update' >"$HOST_HOME/logs/system-update.log"
printf 'kernel' >"$HOST_HOME/logs/kernel-cleanup.log"
printf 'unit' >"$FIXTURE_HOME/.config/systemd/user/captaincronos-monthly-health.service"
printf 'timer' >"$FIXTURE_HOME/.config/systemd/user/captaincronos-monthly-health.timer"
printf 'cache' >"$HOST_HOME/cache/derived.dat"
printf 'plugin' >"$HOST_HOME/plugins/local/config"
printf 'backup' >"$CC_FIXTURE_HOME/backups/20260801-120000/.bashrc"
printf 'bundle' >"$CC_FIXTURE_HOME/repo-bundles/project-20260801.bundle"
printf 'unknown' >"$CC_FIXTURE_HOME/mystery/data"
printf 'legacy' >"$FIXTURE_HOME/upgrade.log"
printf 'recovery' >"$FIXTURE_HOME/.bash_functions.pre-helpme-refresh.20260801-120000.bak"
touch -d '2026-07-01 12:00:00' "$HOST_HOME/reports/monthly-health/monthly-health-20260701-120000.log"
touch -d '2026-08-01 12:00:00' "$HOST_HOME/reports/monthly-health/monthly-health-20260801-120000.log"

# An external symlink is observed but never traversed or counted.
mkdir -p "$TEST_DIR/external"
printf 'must-stay' >"$TEST_DIR/external/outside.txt"
ln -s "$TEST_DIR/external" "$HOST_HOME/reports/drives/external-link"
chmod 000 "$HOST_HOME/plugins/local/config"

fingerprint >"$TEST_DIR/populated-before"
run_maintenance inventory --format tsv >"$TEST_DIR/inventory.tsv"
run_maintenance inventory >"$TEST_DIR/inventory.txt"
run_maintenance status >"$TEST_DIR/status.txt"
run_maintenance retention >"$TEST_DIR/policy.txt"
run_maintenance cleanup >"$TEST_DIR/cleanup.txt"
run_maintenance cleanup --dry-run >"$TEST_DIR/cleanup-explicit.txt"
fingerprint >"$TEST_DIR/populated-after"
cmp -s "$TEST_DIR/populated-before" "$TEST_DIR/populated-after" || fail 'read-only maintenance changed HOME'

monthly_row="$(awk -F '\t' '$1=="monthly-health" {print; exit}' "$TEST_DIR/inventory.tsv")"
[ "$(cut -f5 <<<"$monthly_row")" -eq 2 ] || fail 'monthly report count was incorrect'
[ "$(cut -f6 <<<"$monthly_row")" -eq 10 ] || fail 'monthly report size was incorrect'
[ "$(cut -f7 <<<"$monthly_row")" = 2026-07-01 ] || fail 'oldest report date was incorrect'
[ "$(cut -f8 <<<"$monthly_row")" = 2026-08-01 ] || fail 'newest report date was incorrect'
[ "$(cut -f18 <<<"$monthly_row")" -eq 1 ] || fail 'monthly latest symlink was not reported'

assert_contains "$TEST_DIR/inventory.tsv" $'system-update-log\tsystem-update\thistorical-record' 'log inventory was absent'
assert_contains "$TEST_DIR/inventory.tsv" $'monthly-health-service\tmonthly-health-timer\tauthoritative-state' 'service-unit inventory was absent'
assert_contains "$TEST_DIR/inventory.tsv" $'asset-records\tassets\tauthoritative-state' 'authoritative asset classification was absent'
assert_contains "$TEST_DIR/inventory.tsv" $'asset-history\tassets\tuser-curated-state' 'asset history classification was absent'
assert_contains "$TEST_DIR/inventory.tsv" $'unclassified-home\tunclassified\tunknown-external' 'unknown ownership row was absent'
assert_contains "$TEST_DIR/inventory.tsv" $'cc repos backup\texport\tunknown\tyes\tuser-owned' 'bundle ownership metadata was absent'
plugin_row="$(awk -F '\t' '$1=="host-plugins" {print; exit}' "$TEST_DIR/inventory.tsv")"
[ "$(cut -f17 <<<"$plugin_row")" -ge 1 ] || fail 'unreadable persistent entry did not produce a warning'
assert_contains "$TEST_DIR/inventory.txt" 'user-managed' 'retention policy was not rendered'
assert_contains "$TEST_DIR/inventory.txt" 'Cleanup eligible:' 'cleanup eligibility label was absent'
assert_contains "$TEST_DIR/inventory.txt" '0 (disabled)' 'cleanup eligibility was incorrect'
assert_contains "$TEST_DIR/policy.txt" 'HOME membership alone proves nothing' 'ownership rule was absent'
assert_contains "$TEST_DIR/cleanup.txt" 'Candidates: 0' 'cleanup preview did not report exact empty plan'
assert_contains "$TEST_DIR/cleanup.txt" 'No path would be removed' 'cleanup preview was ambiguous'
cmp -s "$TEST_DIR/cleanup.txt" "$TEST_DIR/cleanup-explicit.txt" || fail 'implicit and explicit dry-run plans differed'
[ -f "$TEST_DIR/external/outside.txt" ] || fail 'inventory followed or modified an external symlink'

# Shared report publication creates private directories; active drive producers
# establish a private umask for subsequently redirected report files.
report_root="$TEST_DIR/private-reports"
bash -c '
set -euo pipefail
source "$1/lib/cc-report.sh"
umask 077
CC_REPORT_DIR="$2"
directory="$(cc_report_make_dir drives fixture)"
cc_report_write_metadata "$directory/metadata.txt" "Fixture"
[ "$(stat -c %a "$directory")" = 700 ]
[ "$(stat -c %a "$directory/metadata.txt")" = 600 ]
' bash "$PROJECT_ROOT" "$report_root" || fail 'private drive-report modes were not preserved'
grep -Fq 'umask 077' "$PROJECT_ROOT/tools/commands/drive-report" || fail 'drive-report lacks a private umask'
grep -Fq 'umask 077' "$PROJECT_ROOT/tools/commands/drive-qualify" || fail 'drive-qualify lacks a private umask'

# Replacing the configured ownership root with a symlink cannot redirect scans.
SYMLINK_HOME="$TEST_DIR/symlink-home"
mkdir -p "$SYMLINK_HOME"
ln -s "$TEST_DIR/external" "$SYMLINK_HOME/.captaincronos"
env HOME="$SYMLINK_HOME" CC_HOME="$SYMLINK_HOME/.captaincronos" CC_HOST_ID="$HOST_ID" \
    CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" bash "$PROJECT_ROOT/tools/cc" \
    maintenance inventory --format tsv >"$TEST_DIR/symlink-root.tsv"
symlink_unknown="$(awk -F '\t' '$1=="unclassified-home" {print; exit}' "$TEST_DIR/symlink-root.tsv")"
[ "$(cut -f5 <<<"$symlink_unknown")" -eq 0 ] || fail 'symlinked ownership root was scanned'
[ "$(cut -f17 <<<"$symlink_unknown")" -eq 1 ] || fail 'symlinked ownership root was not warned'

# Apply and unknown switches are rejected contextually before command execution.
if run_maintenance cleanup --apply >"$TEST_DIR/apply.out" 2>"$TEST_DIR/apply.err"; then
    fail 'inspection-only cleanup accepted --apply'
fi
assert_contains "$TEST_DIR/apply.err" 'Unknown switch: --apply' 'apply rejection was not contextual'
assert_contains "$TEST_DIR/apply.err" 'Command: cc maintenance cleanup' 'apply rejection used the wrong context'
if run_maintenance inventory --bogus >"$TEST_DIR/bogus.out" 2>"$TEST_DIR/bogus.err"; then
    fail 'maintenance accepted an unknown switch'
fi
assert_contains "$TEST_DIR/bogus.err" 'Command: cc maintenance inventory' 'unknown-switch help was not contextual'

# Presentation remains ANSI-free for redirected, NO_COLOR, and dumb-terminal output.
if grep -q $'\033' "$TEST_DIR/inventory.txt" "$TEST_DIR/status.txt" "$TEST_DIR/policy.txt"; then
    fail 'maintenance redirected output contained ANSI'
fi

chmod 600 "$HOST_HOME/plugins/local/config"
printf 'Persistent retention tests: PASS\n'
