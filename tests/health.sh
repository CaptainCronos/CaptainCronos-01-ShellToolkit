#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-health.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/proc" "$TEST_DIR/bin" "$TEST_DIR/thermal/thermal_zone0" "$TEST_DIR/snapd-snaps"
printf '0.25 0.50 0.75 1/100 1\n' > "$TEST_DIR/proc/loadavg"
printf '123.0 0.0\n' > "$TEST_DIR/proc/uptime"
printf 'MemTotal:       1000 kB\nMemAvailable:    400 kB\nSwapTotal:       200 kB\nSwapFree:         50 kB\n' > "$TEST_DIR/proc/meminfo"
printf '90000\n' > "$TEST_DIR/thermal/thermal_zone0/temp"
printf 'critical\n' > "$TEST_DIR/thermal/thermal_zone0/trip_point_0_type"
printf '80000\n' > "$TEST_DIR/thermal/thermal_zone0/trip_point_0_temp"
cat > "$TEST_DIR/bin/ps" <<'EOF_PS'
#!/usr/bin/env bash
case "$*" in *'pid='*) printf '1\n2\n3\n';; *'stat='*) printf 'S\nZ\n';; esac
EOF_PS
cat > "$TEST_DIR/bin/service-manager" <<'EOF_MANAGER'
#!/usr/bin/env bash
args=("$@"); [ "${args[0]:-}" = --user ] && args=("${args[@]:1}")
case "${args[0]:-}" in
 show)
  unit="${args[${#args[@]}-1]}"
  property=''; for arg in "${args[@]}"; do case "$arg" in --property=*) property="${arg#--property=}";; esac; done
  # This deliberately reproduces real systemctl --value behavior: failed
  # mount units omit empty MainPID and NRestarts values rather than outputting
  # placeholder lines.
  case "$unit:$property" in
   active.service:Description) echo Active;; active.service:LoadState) echo loaded;; active.service:ActiveState) echo active;; active.service:SubState) echo running;; active.service:MainPID) echo 12;; active.service:NRestarts) echo 0;;
   inactive.service:Description) echo Inactive;; inactive.service:LoadState) echo loaded;; inactive.service:ActiveState) echo inactive;; inactive.service:SubState) echo dead;; inactive.service:MainPID|inactive.service:NRestarts) echo 0;;
   failed.service:Description) echo Failed;; failed.service:LoadState) echo loaded;; failed.service:ActiveState) echo failed;; failed.service:SubState) echo failed;; failed.service:MainPID) echo 5;; failed.service:NRestarts) echo 3;;
   data.mount:Description) echo Data;; data.mount:LoadState) echo loaded;; data.mount:ActiveState) echo failed;; data.mount:SubState) echo failed;;
   snap-core22-1908.mount:Description) echo 'Mount unit for core22, revision 1908';; snap-core22-1908.mount:LoadState) echo loaded;; snap-core22-1908.mount:ActiveState|snap-core22-1908.mount:SubState) echo failed;; snap-core22-1908.mount:Where) echo /snap/core22/1908;; snap-core22-1908.mount:What) echo "$CC_SERVICE_SNAPD_SNAPS_DIR/core22_1908.snap";;
   snap-core22-1909.mount:Description) echo 'Mount unit for core22, revision 1909';; snap-core22-1909.mount:LoadState) echo loaded;; snap-core22-1909.mount:ActiveState|snap-core22-1909.mount:SubState) echo failed;; snap-core22-1909.mount:Where) echo /snap/core22/1909;; snap-core22-1909.mount:What) echo "$CC_SERVICE_SNAPD_SNAPS_DIR/core22_1909.snap";;
   'snap-canonical\x2dlivepatch-282.mount:Description') echo 'Mount unit for canonical-livepatch, revision 282';; 'snap-canonical\x2dlivepatch-282.mount:LoadState') echo loaded;; 'snap-canonical\x2dlivepatch-282.mount:ActiveState'|'snap-canonical\x2dlivepatch-282.mount:SubState') echo failed;; 'snap-canonical\x2dlivepatch-282.mount:Where') echo /snap/canonical-livepatch/282;; 'snap-canonical\x2dlivepatch-282.mount:What') echo "$CC_SERVICE_SNAPD_SNAPS_DIR/canonical-livepatch_282.snap";;
   masked.service:Description) echo Masked;; masked.service:LoadState) echo loaded;; masked.service:ActiveState) echo inactive;; masked.service:SubState) echo dead;; masked.service:MainPID|masked.service:NRestarts) echo 0;;
   static.service:Description) echo Static;; static.service:LoadState) echo loaded;; static.service:ActiveState) echo inactive;; static.service:SubState) echo dead;; static.service:MainPID|static.service:NRestarts) echo 0;;
   generated.service:Description) echo Generated;; generated.service:LoadState) echo loaded;; generated.service:ActiveState) echo inactive;; generated.service:SubState) echo dead;; generated.service:MainPID|generated.service:NRestarts) echo 0;;
   oneshot.service:Description) echo Oneshot;; oneshot.service:LoadState) echo loaded;; oneshot.service:ActiveState) echo inactive;; oneshot.service:SubState) echo dead;; oneshot.service:MainPID|oneshot.service:NRestarts) echo 0;;
   missing.service:Description) echo Missing;; missing.service:LoadState) echo not-found;; missing.service:ActiveState) echo inactive;; missing.service:SubState) echo dead;; missing.service:MainPID|missing.service:NRestarts) echo 0;;
   restricted.service:*) exit 1;;
   fixture.timer:*) printf '%s\n' 'tomorrow' 'yesterday' fixture.service active;;
  esac;;
 is-enabled) case "${args[${#args[@]}-1]}" in active.service|failed.service|fixture.timer) echo enabled; exit 0;; masked.service) echo masked; exit 1;; static.service) echo static; exit 1;; generated.service) echo generated; exit 1;; *) echo disabled; exit 1;; esac;;
 list-units) printf '%s\n' 'failed.service loaded failed failed fixture' 'data.mount loaded failed failed fixture' 'snap-core22-1908.mount loaded failed failed fixture' 'snap-core22-1909.mount loaded failed failed fixture' 'snap-canonical\x2dlivepatch-282.mount loaded failed failed fixture';;
esac
EOF_MANAGER
cat > "$TEST_DIR/bin/system-log" <<'EOF_LOG'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TRACE_FILE"
printf '%s\n' '2026-01-01 failed fixture service'
EOF_LOG
chmod 755 "$TEST_DIR/bin/ps" "$TEST_DIR/bin/service-manager" "$TEST_DIR/bin/system-log"
printf 'role|fixture-role|system|active.service|active|FAIL\nrole|fixture-role|system|inactive.service|active|WARN\nrole|fixture-role|system|missing.service|present|FAIL\nrole|fixture-role|system|fixture.timer|enabled|WARN\nrole|fixture-role|system|disabled.timer|enabled|WARN\nrole|fixture-role|system|snap-core22-1908.mount|active|FAIL\n' > "$TEST_DIR/policy"

PATH="$TEST_DIR/bin:$PATH"; export PATH
TRACE_FILE="$TEST_DIR/trace"; export TRACE_FILE
CC_HEALTH_PROC_ROOT="$TEST_DIR/proc"; CC_HEALTH_THERMAL_ROOT="$TEST_DIR/thermal"; CC_SERVICE_MANAGER=service-manager; CC_SYSTEM_LOG=system-log; CC_SERVICE_SNAPD_SNAPS_DIR="$TEST_DIR/snapd-snaps"; CC_PROGRAMS_LOADED=1
export CC_HEALTH_PROC_ROOT CC_HEALTH_THERMAL_ROOT CC_SERVICE_MANAGER CC_SYSTEM_LOG CC_SERVICE_SNAPD_SNAPS_DIR CC_PROGRAMS_LOADED
cc_platform_init_system() { printf '%s\n' systemd; }
cc_env_role() { printf '%s\n' fixture-role; }
cc_env_profile() { printf '%s\n' fixture-profile; }
cc_health_policy_file() { printf '%s\n' "$TEST_DIR/policy"; }
_cc_kernel_reboot_state() { printf '%s\n' required; }
_cc_kernel_snapshot_capture() { :; }
_cc_kernel_snapshot_findings() { printf 'PASS\tCONSISTENT\tfixture kernel healthy\n'; }
cc_network_local_findings_tsv() { printf 'PASS\tUSABLE_INTERFACE\tinterface\tfixture interface\n'; }
cc_storage_local_findings_tsv() { printf 'PASS\tSTORAGE_OK\tstorage\thost\tfixture storage healthy\tfixture\t2026-01-01T00:00:00Z\n'; }

resources="$(cc_health_resources_tsv)"
printf '%s\n' "$resources" | grep -q $'load_1m\t0.25' || fail 'load fixture missing'
printf '%s\n' "$resources" | grep -q $'swap_used\t150' || fail 'swap fixture missing'
printf '%s\n' "$resources" | grep -q $'zombie_count\t1' || fail 'zombie fixture missing'
printf '%s\n' "$resources" | grep -q $'thermal\t90000' || fail 'thermal fixture missing'
record="$(_cc_service_record_tsv system failed.service)"
printf '%s\n' "$record" | grep -q $'failed.service\tFailed\tloaded\tfailed\tfailed\tenabled\tservice\t5\t3\tavailable' || fail 'failed service record missing fields'
[ "$(_cc_service_record_tsv system missing.service | cut -f4)" = not-found ] || fail 'missing unit was not normalized'
[ "$(_cc_service_record_tsv system static.service | cut -f7)" = static ] || fail 'static state was not normalized'
[ "$(_cc_service_record_tsv system masked.service | cut -f7)" = masked ] || fail 'masked state was not normalized'
[ "$(_cc_service_record_tsv system generated.service | cut -f7)" = generated ] || fail 'generated state was not normalized'
[ "$(_cc_service_record_tsv system oneshot.service | cut -f5)" = inactive ] || fail 'oneshot inactive state was not normalized'
[ "$(_cc_service_record_tsv user restricted.service | cut -f11)" = restricted ] || fail 'unavailable user collection was not normalized'
[ "$(_cc_timer_record_tsv system fixture.timer | cut -f7)" = enabled ] || fail 'timer enabled state was not normalized'
printf 'active revision image\n' > "$TEST_DIR/snapd-snaps/core22_1909.snap"
[ "$(_cc_service_failed_unit_classification system snap-core22-1908.mount 'Mount unit for core22, revision 1908' loaded failed failed /snap/core22/1908 "$TEST_DIR/snapd-snaps/core22_1908.snap")" = ignored-stale-snap ] || fail 'obsolete Snap mount was not classified ignored'
[ "$(_cc_service_failed_unit_classification system snap-core22-1909.mount 'Mount unit for core22, revision 1909' loaded failed failed /snap/core22/1909 "$TEST_DIR/snapd-snaps/core22_1909.snap")" = unknown ] || fail 'live Snap revision mount was not kept unknown'
[ "$(_cc_service_failed_unit_classification system 'snap-canonical\x2dlivepatch-282.mount' 'Mount unit for canonical-livepatch, revision 282' loaded failed failed /snap/canonical-livepatch/282 "$TEST_DIR/snapd-snaps/canonical-livepatch_282.snap")" = ignored-stale-snap ] || fail 'escaped obsolete Snap mount was not classified ignored'
[ "$(_cc_service_failed_unit_classification system snap-core22-1908.mount 'Mount unit for core22, revision 1908' loaded failed failed /unexpected/core22/1908 "$TEST_DIR/snapd-snaps/core22_1908.snap")" = unknown ] || fail 'malformed Snap mount was not kept actionable'
[ "$(_cc_service_failed_unit_classification system data.mount Data loaded failed failed '' '')" = actionable ] || fail 'ordinary failed mount was not actionable'
findings="$(cc_health_findings_tsv)"
for code in ZOMBIE_PROCESSES REBOOT_REQUIRED THERMAL_PRESSURE SERVICE_FAILED SERVICE_RESTART_LOOP SERVICE_EXPECTED_ACTIVE SERVICE_EXPECTED_PRESENT TIMER_EXPECTED_ENABLED; do printf '%s\n' "$findings" | grep -q "$code" || fail "missing finding: $code"; done
if printf '%s\n' "$findings" | grep -q 'fixture.timer.*TIMER_EXPECTED_ENABLED'; then fail 'enabled timer was incorrectly unhealthy'; fi
if printf '%s\n' "$findings" | grep -q 'inactive.service.*SERVICE_FAILED'; then fail 'inactive service became failed'; fi
printf '%s\n' "$findings" | grep -q $'SERVICE_FAILED\tservice\tfailed.service' || fail 'normal failed service was suppressed'
printf '%s\n' "$findings" | grep -q $'SERVICE_FAILED\tservice\tdata.mount' || fail 'normal failed mount was suppressed'
printf '%s\n' "$findings" | grep -q $'SERVICE_FAILED\tservice\tsnap-core22-1909.mount' || fail 'ambiguous Snap mount was suppressed'
if printf '%s\n' "$findings" | grep -q $'SERVICE_FAILED\tservice\tsnap-core22-1908.mount'; then fail 'stale Snap mount remained an actionable failure'; fi
if printf '%s\n' "$findings" | grep -q $'SERVICE_FAILED\tservice\tsnap-canonical\\x2dlivepatch-282.mount'; then fail 'escaped stale Snap mount remained an actionable failure'; fi
printf '%s\n' "$findings" | grep -q $'SERVICE_EXPECTED_ACTIVE\tservice\tsnap-core22-1908.mount' || fail 'explicit Snap mount policy was bypassed'
[ "$(printf '%s\n' "$findings" | awk -F '\t' '$2 == "SERVICE_FAILED" {n++} END {print n+0}')" -eq 3 ] || fail 'stale Snap mount inflated actionable failed-unit count'
: > "$TRACE_FILE"
cc_health_diagnose_tsv '24 hours ago' 9 >/dev/null
grep -q -- '--unit failed.service' "$TRACE_FILE" || fail 'diagnose did not request failed unit journal'
grep -q -- ' -n 9' "$TRACE_FILE" || fail 'diagnose did not retain bounded record count'
if _cc_log_query system '24 hours ago' all >/dev/null 2>&1; then fail 'unbounded journal request was accepted'; fi
printf 'Health fixture tests: PASS\n'
