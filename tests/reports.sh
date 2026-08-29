#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_contains() { grep -Fq -- "$2" "$1" || fail "$3"; }
assert_status_2() {
    local output="$1"; shift
    set +e
    "$@" >"$output.out" 2>"$output.err"
    local status=$?
    set -e
    [ "$status" -eq 2 ] || fail "expected status 2, got $status: $*"
}

FIXTURE_HOME="$TEST_DIR/home"
CC_FIXTURE_HOME="$FIXTURE_HOME/.captaincronos"
HOST_ID=report-host
HOST_HOME="$CC_FIXTURE_HOME/hosts/$HOST_ID"
REPORT_ROOT="$HOST_HOME/reports"
NOW_EPOCH=1787976000
mkdir -p "$FIXTURE_HOME"

run_reports() {
    env HOME="$FIXTURE_HOME" CC_HOME="$CC_FIXTURE_HOME" CC_HOST_ID="$HOST_ID" \
        CC_REPORT_NOW_EPOCH="$NOW_EPOCH" CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" \
        TERM=dumb NO_COLOR=1 bash "$PROJECT_ROOT/tools/cc" reports "$@"
}

fingerprint() {
    find -P "$FIXTURE_HOME" -mindepth 1 -printf '%P|%y|%s|%T@|%m|%l\n' 2>/dev/null | LC_ALL=C sort
}

make_monthly() {
    local number="$1" date_value="$2" file
    file="$REPORT_ROOT/monthly-health/monthly-health-202001$(printf '%02d' "$number")-000000.log"
    printf 'monthly-%s' "$number" >"$file"
    chmod 600 "$file"
    touch -d "$date_value" "$file"
    printf '%s\n' "$file"
}

make_drive_report() {
    local number="$1" date_value="$2" directory
    directory="$REPORT_ROOT/drives/sda-202001$(printf '%02d' "$number")-000000"
    mkdir -p "$directory"
    chmod 700 "$directory"
    printf 'Captain Cronos Drive Report\nGenerated ISO: 2020-01-%02dT00:00:00Z\n' "$number" >"$directory/metadata.txt"
    printf 'summary-%s' "$number" >"$directory/summary.txt"
    printf 'smart-%s' "$number" >"$directory/smartctl-a.txt"
    chmod 600 "$directory"/*
    touch -d "$date_value" "$directory/metadata.txt"
    printf '%s\n' "$directory"
}

# Empty/default/list/prune/switch discovery are deterministic and zero-write.
fingerprint >"$TEST_DIR/empty-before"
run_reports >"$TEST_DIR/empty-status"
run_reports list --format tsv >"$TEST_DIR/empty-list"
run_reports prune >"$TEST_DIR/empty-prune"
run_reports prune switches >"$TEST_DIR/empty-switches"
fingerprint >"$TEST_DIR/empty-after"
cmp -s "$TEST_DIR/empty-before" "$TEST_DIR/empty-after" || fail 'empty reports inspection wrote persistent state'
assert_contains "$TEST_DIR/empty-prune" 'Candidates: 0' 'empty prune did not show an exact empty plan'
assert_contains "$TEST_DIR/empty-prune" 'PREVIEW (zero-write)' 'prune did not identify zero-write preview mode'
assert_contains "$TEST_DIR/empty-switches" '--apply' 'registry-driven prune apply switch was absent'

# Populate known, protected, and unknown persistent resources. Small test-only
# family overrides exercise policy without weakening documented defaults.
mkdir -p "$REPORT_ROOT/monthly-health" "$REPORT_ROOT/drives/qualification/sda-20200101-000000" \
    "$HOST_HOME/assets/drives" "$HOST_HOME/logs" "$CC_FIXTURE_HOME/mystery" "$REPORT_ROOT/operator-notes"
chmod 700 "$REPORT_ROOT/monthly-health" "$REPORT_ROOT/drives" "$REPORT_ROOT/drives/qualification" \
    "$REPORT_ROOT/drives/qualification/sda-20200101-000000" "$HOST_HOME/logs"
printf '%s\n' \
    'MONTHLY_HEALTH_RETENTION_MIN_COUNT="2"' \
    'MONTHLY_HEALTH_RETENTION_MAX_AGE_DAYS="30"' \
    'DRIVE_REPORT_RETENTION_MIN_COUNT="2"' \
    'DRIVE_REPORT_RETENTION_MAX_AGE_DAYS="30"' >"$CC_FIXTURE_HOME/config"
printf 'HOST_ID="%s"\n' "$HOST_ID" >"$HOST_HOME/config"
printf 'asset' >"$HOST_HOME/assets/drives/serial.yaml"
printf 'unknown-home' >"$CC_FIXTURE_HOME/mystery/data"
printf 'operator note' >"$REPORT_ROOT/operator-notes/note.txt"
printf 'Drive Qualification Report\n' >"$REPORT_ROOT/drives/qualification/sda-20200101-000000/README.txt"
chmod 600 "$REPORT_ROOT/drives/qualification/sda-20200101-000000/README.txt"
touch -d '2020-01-01 UTC' "$REPORT_ROOT/drives/qualification/sda-20200101-000000/README.txt"
printf 'update-log' >"$HOST_HOME/logs/system-update.log"
printf 'kernel-log' >"$HOST_HOME/logs/kernel-cleanup.log"
chmod 600 "$HOST_HOME/logs/"*.log

monthly_one="$(make_monthly 1 '2020-01-01 UTC')"
monthly_two="$(make_monthly 2 '2020-01-02 UTC')"
monthly_three="$(make_monthly 3 '2020-01-03 UTC')"
monthly_latest="$(make_monthly 4 '2020-01-04 UTC')"
ln -s "$monthly_latest" "$REPORT_ROOT/monthly-health/latest.log"
drive_one="$(make_drive_report 1 '2020-01-01 UTC')"
drive_two="$(make_drive_report 2 '2020-01-02 UTC')"
drive_three="$(make_drive_report 3 '2020-01-03 UTC')"
drive_latest="$(make_drive_report 4 '2020-01-04 UTC')"
drive_newest="$(make_drive_report 5 '2020-01-05 UTC')"
printf 'asset_id: serial\nlast_report: %s\n' "$drive_one" >"$HOST_HOME/assets/drives/serial.yaml"

# Inventory, accounting, family classification, and preview are one-pass and
# leave configuration/assets/qualification/unknown content untouched.
fingerprint >"$TEST_DIR/populated-before"
run_reports list --format tsv >"$TEST_DIR/list.tsv"
set +e; run_reports status >"$TEST_DIR/status"; status_rc=$?; set -e
[ "$status_rc" -ne 0 ] || fail 'unknown report material did not affect lifecycle health'
run_reports prune >"$TEST_DIR/preview"
fingerprint >"$TEST_DIR/populated-after"
cmp -s "$TEST_DIR/populated-before" "$TEST_DIR/populated-after" || fail 'list/status/preview wrote persistent state'
assert_contains "$TEST_DIR/list.tsv" $'monthly-health\t' 'monthly-health family was not classified'
assert_contains "$TEST_DIR/list.tsv" $'drive-report\t' 'drive-report family was not classified'
assert_contains "$TEST_DIR/list.tsv" $'drive-qualification\t' 'qualification evidence was not classified'
assert_contains "$TEST_DIR/list.tsv" $'system-update\t' 'system-update current log was not classified'
assert_contains "$TEST_DIR/list.tsv" $'kernel-cleanup\t' 'kernel-cleanup current log was not classified'
assert_contains "$TEST_DIR/list.tsv" 'KEEP latest' 'valid latest target was not retained'
assert_contains "$TEST_DIR/list.tsv" 'KEEP protected' 'protected evidence/current logs were not retained'
assert_contains "$TEST_DIR/status" 'Unknown persistent items' 'unknown report material was not reported'
[ "$(grep -c 'PRUNE age' "$TEST_DIR/preview")" -eq 4 ] || fail 'bounded preview did not contain exactly four candidates'
assert_contains "$TEST_DIR/preview" "$monthly_one" 'old monthly candidate was absent'
assert_contains "$TEST_DIR/preview" "$monthly_two" 'second old monthly candidate was absent'
assert_contains "$TEST_DIR/preview" "$drive_two" 'old unreferenced drive candidate was absent'
assert_contains "$TEST_DIR/preview" "$drive_three" 'second old unreferenced drive candidate was absent'
grep -Fq -- "$monthly_three" "$TEST_DIR/preview" && fail 'minimum-retained monthly report entered plan'
grep -Fq -- "$monthly_latest" "$TEST_DIR/preview" && fail 'latest monthly report entered plan'
grep -Fq -- "$drive_one" "$TEST_DIR/preview" && fail 'asset-referenced drive report entered plan'
grep -Fq -- 'qualification' "$TEST_DIR/preview" && fail 'qualification evidence entered plan'
grep -Fq -- 'operator-notes' "$TEST_DIR/preview" && fail 'unknown directory entered plan'
grep -Fq -- 'serial.yaml' "$TEST_DIR/preview" && fail 'asset entered plan'

# Apply consumes the displayed policy-derived plan, preserves protected state,
# and is idempotent. It deletes known drive files individually and only then
# removes the proven-empty report directory.
run_reports prune --apply >"$TEST_DIR/apply"
assert_contains "$TEST_DIR/apply" 'planned: 4' 'apply plan count was incorrect'
assert_contains "$TEST_DIR/apply" 'deleted: 4' 'apply deletion count was incorrect'
for removed in "$monthly_one" "$monthly_two" "$drive_two" "$drive_three"; do [ ! -e "$removed" ] || fail "candidate survived apply: $removed"; done
for retained in "$monthly_three" "$monthly_latest" "$drive_one" "$drive_latest" "$drive_newest" \
    "$REPORT_ROOT/drives/qualification/sda-20200101-000000/README.txt" "$HOST_HOME/assets/drives/serial.yaml" \
    "$CC_FIXTURE_HOME/config" "$HOST_HOME/config" "$REPORT_ROOT/operator-notes/note.txt"; do
    [ -e "$retained" ] || fail "protected state was removed: $retained"
done
run_reports prune >"$TEST_DIR/second-preview"
assert_contains "$TEST_DIR/second-preview" 'Candidates: 0' 'second preview was not idempotent'
run_reports prune --apply >"$TEST_DIR/zero-apply"
assert_contains "$TEST_DIR/zero-apply" 'planned: 0' 'zero-candidate apply was not a no-op success'

# Broken and escaping latest pointers are defects but are never followed.
rm "$REPORT_ROOT/monthly-health/latest.log"
ln -s missing.log "$REPORT_ROOT/monthly-health/latest.log"
set +e; run_reports status >"$TEST_DIR/broken-status"; broken_rc=$?; set -e
[ "$broken_rc" -ne 0 ] || fail 'broken latest pointer did not affect health'
assert_contains "$TEST_DIR/broken-status" 'Latest pointers' 'broken latest pointer was not reported'
rm "$REPORT_ROOT/monthly-health/latest.log"
ln -s "$TEST_DIR/outside.log" "$REPORT_ROOT/monthly-health/latest.log"
printf 'outside' >"$TEST_DIR/outside.log"
run_reports prune >"$TEST_DIR/escape-preview"
[ -f "$TEST_DIR/outside.log" ] || fail 'escaping latest pointer was followed'

# Insecure and unreadable known reports are visible lifecycle warnings; report
# cleanup never chmods them or arbitrary unknown files.
chmod 644 "$monthly_three"
set +e; run_reports status >"$TEST_DIR/permissions"; permission_rc=$?; set -e
[ "$permission_rc" -ne 0 ] || fail 'insecure known-report permissions were ignored'
assert_contains "$TEST_DIR/permissions" 'Permissions' 'permission health was absent'
[ "$(stat -c %a "$monthly_three")" = 644 ] || fail 'status changed report permissions'

# Current-host isolation: another host remains unobserved and unmodified.
OTHER_REPORT="$CC_FIXTURE_HOME/hosts/other-host/reports/monthly-health/monthly-health-20100101-000000.log"
mkdir -p "${OTHER_REPORT%/*}"; printf other >"$OTHER_REPORT"
run_reports prune --apply >"$TEST_DIR/current-host-apply"
[ -f "$OTHER_REPORT" ] || fail 'current-host prune removed another host report'

# Candidate identity changes and deletion failures are truthful. Source the
# shared library to preserve one immutable in-memory plan across the change.
DIRECT_HOME="$TEST_DIR/direct-home"
DIRECT_ROOT="$DIRECT_HOME/.captaincronos/hosts/direct/reports/monthly-health"
mkdir -p "$DIRECT_ROOT"
chmod 700 "$DIRECT_ROOT"
for number in 1 2; do
    file="$DIRECT_ROOT/monthly-health-2010010${number}-000000.log"
    printf direct >"$file"; chmod 600 "$file"; touch -d "2010-01-0${number} UTC" "$file"
done
HOME="$DIRECT_HOME" CC_HOME="$DIRECT_HOME/.captaincronos" CC_HOST_ID=direct CC_REPORT_NOW_EPOCH="$NOW_EPOCH"
export HOME CC_HOME CC_HOST_ID CC_REPORT_NOW_EPOCH
source "$PROJECT_ROOT/lib/cc-environment.sh"
source "$PROJECT_ROOT/lib/cc-config.sh"
source "$PROJECT_ROOT/lib/cc-retention.sh"
source "$PROJECT_ROOT/lib/cc-reports.sh"
printf '%s\n' 'MONTHLY_HEALTH_RETENTION_MIN_COUNT="1"' 'MONTHLY_HEALTH_RETENTION_MAX_AGE_DAYS="1"' >"$CC_HOME/config"
cc_reports_inventory; cc_reports_plan
[ "${#CC_REPORT_PLAN_INDEXES[@]}" -eq 1 ] || fail 'direct bounded plan did not contain one candidate'
changed_index="${CC_REPORT_PLAN_INDEXES[0]}"; changed_path="${CC_REPORT_ITEM_PATH[changed_index]}"
printf changed >>"$changed_path"
if cc_reports_apply_plan; then fail 'identity-changed plan reported success'; fi
[ "$CC_REPORT_APPLY_SKIPPED" -eq 1 ] || fail 'identity change was not safety-skipped'
[ -f "$changed_path" ] || fail 'identity-changed report was deleted'

cc_reports_inventory; cc_reports_plan
_cc_reports_remove_file() { return 1; }
if cc_reports_apply_plan; then fail 'mocked partial deletion failure reported success'; fi
[ "$CC_REPORT_APPLY_FAILED" -eq 1 ] || fail 'partial deletion failure count was untruthful'
[ -f "${CC_REPORT_ITEM_PATH[${CC_REPORT_PLAN_INDEXES[0]}]}" ] || fail 'failed deletion did not remain retained'
unset -f _cc_reports_remove_file

# Direct tampering cannot turn a plan into traversal, report-root, CC_HOME, or
# symlink deletion. Repeated sourcing remains safe.
source "$PROJECT_ROOT/lib/cc-reports.sh"
cc_reports_inventory; cc_reports_plan
CC_REPORT_PLAN_INDEXES=(0)
CC_REPORT_ITEM_FAMILY[0]=monthly-health
CC_REPORT_ITEM_PATH[0]="$CC_HOME"
CC_REPORT_ITEM_SIGNATURE[0]="$(_cc_reports_file_signature "$CC_HOME" 2>/dev/null || :)"
if cc_reports_apply_plan; then fail 'CC_HOME plan tampering reported success'; fi
[ -d "$CC_HOME" ] || fail 'CC_HOME was deleted'
CC_REPORT_ITEM_PATH[0]="$DIRECT_ROOT/../monthly-health"
if cc_reports_apply_plan; then fail 'path traversal plan tampering reported success'; fi
[ -d "$DIRECT_ROOT" ] || fail 'report root was deleted through traversal'

# Contextual usage errors are status 2, and discovery remains zero-write.
assert_status_2 "$TEST_DIR/bogus" run_reports list --bogus
assert_contains "$TEST_DIR/bogus.err" 'Command: cc reports list' 'unknown switch help used the wrong context'
assert_status_2 "$TEST_DIR/apply-context" run_reports status --apply
assert_contains "$TEST_DIR/apply-context.err" 'Command: cc reports status' 'misplaced apply used the wrong context'

printf 'Report lifecycle tests: PASS\n'
