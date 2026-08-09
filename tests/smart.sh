#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-smart.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

CRUCIAL_FIXTURE="$PROJECT_ROOT/tests/fixtures/smart/crucial-mx500.txt"
SANDISK_FIXTURE="$PROJECT_ROOT/tests/fixtures/smart/sandisk-ultra-ii.txt"
NVME_FIXTURE="$PROJECT_ROOT/tests/fixtures/smart/nvme.txt"

crucial_text="$(cat "$CRUCIAL_FIXTURE")"
sandisk_text="$(cat "$SANDISK_FIXTURE")"
nvme_text="$(cat "$NVME_FIXTURE")"

[ "$(cc_smart_attr_raw "$crucial_text" Temperature_Celsius)" = "39" ] || fail "ATA raw temperature did not select the first RAW_VALUE field"
[ "$(cc_smart_attr_raw "$sandisk_text" Temperature_Celsius)" = "34" ] || fail "ATA temperature selected the Min/Max suffix"
[ "$(cc_smart_attr_normalized "$crucial_text" Percent_Lifetime_Remain)" = "99" ] || fail "normalized lifetime value was not parsed"
[ "$(cc_smart_attr_normalized "$sandisk_text" Media_Wearout_Indicator)" = "8" ] || fail "normalized wear value was not parsed"

[ "$(printf '%s\n' "$crucial_text" | cc_smart_temperature)" = "39C" ] || fail "Crucial temperature was malformed"
[ "$(printf '%s\n' "$sandisk_text" | cc_smart_temperature)" = "34C" ] || fail "SanDisk temperature was malformed"
[ "$(printf '%s\n' "$crucial_text" | cc_smart_power_on_hours)" = "43599" ] || fail "Crucial power-on hours changed"
[ "$(printf '%s\n' "$sandisk_text" | cc_smart_power_on_hours)" = "41325" ] || fail "SanDisk power-on hours changed"
[ "$(printf '%s\n' "$crucial_text" | cc_smart_life_remaining)" = "99%" ] || fail "Percent_Lifetime_Remain used the vendor raw counter"
[ "$(printf '%s\n' "$sandisk_text" | cc_smart_life_remaining)" = "8%" ] || fail "Media_Wearout_Indicator used the hexadecimal raw counter"

[ "$(printf '%s\n' "$nvme_text" | cc_smart_temperature)" = "41C" ] || fail "NVMe temperature parsing failed"
[ "$(printf '%s\n' "$nvme_text" | cc_smart_power_on_hours)" = "12345" ] || fail "NVMe comma-separated hours parsing failed"
[ "$(printf '%s\n' "$nvme_text" | cc_smart_life_remaining)" = "93%" ] || fail "NVMe percentage-used conversion failed"

summary="$(cc_smart_summary_from_text /dev/sdb "$crucial_text")"
printf '%s\n' "$summary" | grep -Eq '^Temp:[[:space:]]+39C$' || fail "shared SMART summary retained a Min/Max suffix"
printf '%s\n' "$summary" | grep -Eq '^Hours:[[:space:]]+43599$' || fail "shared SMART summary hours changed"

TEST_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

cat > "$TEST_DIR/lsblk" <<'EOF_LSBLK'
#!/usr/bin/env bash
case "$*" in
    *NAME,TYPE*)
        printf '%s\n' 'sdb disk' 'sdc disk' 'zram0 disk'
        ;;
    *ROTA*)
        printf '%s\n' '0'
        ;;
esac
EOF_LSBLK
cat > "$TEST_DIR/smartctl" <<EOF_SMARTCTL
#!/usr/bin/env bash
case "\${!#}" in
    /dev/sdb) cat "$CRUCIAL_FIXTURE" ;;
    /dev/sdc) cat "$SANDISK_FIXTURE" ;;
    *) exit 1 ;;
esac
EOF_SMARTCTL
chmod 755 "$TEST_DIR/lsblk" "$TEST_DIR/smartctl"

command_output="$(PATH="$TEST_DIR:$PATH" bash "$PROJECT_ROOT/tools/cc" smart)" || fail "cc smart failed with controlled SMART fixtures"
printf '%s\n' "$command_output" | grep -Eq '^sdb[[:space:]]+SSD[[:space:]]+PASSED[[:space:]]+UNKNOWN[[:space:]]+39C[[:space:]]+43599[[:space:]]+99%' || fail "cc smart Crucial row remained malformed"
printf '%s\n' "$command_output" | grep -Eq '^sdc[[:space:]]+SSD[[:space:]]+PASSED[[:space:]]+UNKNOWN[[:space:]]+34C[[:space:]]+41325[[:space:]]+8%' || fail "cc smart SanDisk row remained malformed"
if printf '%s\n' "$command_output" | grep -Eq '[0-9]+/[0-9]+\)C|0x[[:xdigit:]]+%'; then
    fail "cc smart emitted vendor suffixes as temperature or life percentages"
fi
if printf '%s\n' "$command_output" | grep -q '^zram'; then
    fail "cc smart treated RAM-backed storage as a physical SSD"
fi
if PATH="$TEST_DIR:$PATH" bash "$PROJECT_ROOT/tools/cc" smart --invalid-option >/dev/null 2>&1; then
    fail "cc smart accepted an unknown option as a device"
fi
if PATH="$TEST_DIR:$PATH" bash "$PROJECT_ROOT/tools/cc" smart sdb --invalid-option >/dev/null 2>&1; then
    fail "cc smart accepted an invalid detail mode"
fi

printf 'SMART parsing tests: PASS\n'
