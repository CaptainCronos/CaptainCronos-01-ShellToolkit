#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-common.sh"
source "$PROJECT_ROOT/lib/cc-smart.sh"
source "$PROJECT_ROOT/lib/cc-storage.sh"
source "$PROJECT_ROOT/lib/cc-storage-logs.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

TEST_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

cat > "$TEST_DIR/lsblk" <<'EOF_LSBLK'
#!/usr/bin/env bash
case "$*" in
    '-dn -o NAME,TYPE') printf '%s\n' 'sdz disk' 'zram0 disk' ;;
    '-dnro MODEL /dev/sdz') printf '%s\n' 'Vendor\x20\x22Model\x22,\x20Series' ;;
    '-dnro SERIAL /dev/sdz') printf '%s\n' 'SERIAL-1' ;;
    '-dnro SIZE /dev/sdz') printf '%s\n' '1.8T' ;;
    '-dnro TRAN /dev/sdz') printf '%s\n' 'sata' ;;
    '-nr -o MOUNTPOINT /dev/sdz') exit 0 ;;
    *) exit 2 ;;
esac
EOF_LSBLK
cat > "$TEST_DIR/smartctl" <<'EOF_SMARTCTL'
#!/usr/bin/env bash
cat <<'EOF_DATA'
SMART overall-health self-assessment test result: PASSED
  9 Power_On_Hours          0x0032   100   100   000    Old_age   Always       -       1234
EOF_DATA
EOF_SMARTCTL
cat > "$TEST_DIR/sudo" <<'EOF_SUDO'
#!/usr/bin/env bash
exit 1
EOF_SUDO
chmod 755 "$TEST_DIR/lsblk" "$TEST_DIR/smartctl" "$TEST_DIR/sudo"

rows="$(PATH="$TEST_DIR:$PATH" cc_storage_inventory_rows)" || fail 'unmounted inventory row returned failure'
[ "$(printf '%s\n' "$rows" | wc -l)" -eq 1 ] || fail 'RAM-backed device was included as a physical drive'
IFS=$'\t' read -r device model serial size transport health hours mounts <<< "$rows"
[ "$device" = /dev/sdz ] || fail 'inventory device changed'
[ "$model" = 'Vendor "Model", Series' ] || fail 'lsblk model spaces or quotes were split'
[ "$serial" = SERIAL-1 ] || fail 'inventory serial changed'
[ "$transport" = sata ] || fail 'inventory transport changed'
[ "$health" = PASSED ] || fail 'SMART health parsing changed'
[ "$hours" = 1234 ] || fail 'SMART hours parsing changed'
[ "$mounts" = - ] || fail 'unmounted disk did not use the mount placeholder'

csv="$(PATH="$TEST_DIR:$PATH" cc_storage_inventory_csv)" || fail 'CSV inventory returned failure'
printf '%s\n' "$csv" | grep -Fq '"Vendor ""Model"", Series"' || fail 'CSV quotes were not escaped'

printf 'Storage inventory tests: PASS\n'

# Component 3 uses pair-form adapters and stable local links, never the
# developer's disks.  Empty lsblk fields are normalized rather than shifting.
DEVICE_ROOT="$TEST_DIR/dev"
mkdir -p "$DEVICE_ROOT/by-id" "$DEVICE_ROOT/by-path"
touch "$DEVICE_ROOT/sda" "$DEVICE_ROOT/sda1" "$DEVICE_ROOT/nvme0n1" "$DEVICE_ROOT/sdb"
ln -s ../sda "$DEVICE_ROOT/by-id/wwn-0x5000"
ln -s ../sda "$DEVICE_ROOT/by-path/pci-usb-sata"
CC_STORAGE_BY_ID_DIR="$DEVICE_ROOT/by-id"
CC_STORAGE_BY_PATH_DIR="$DEVICE_ROOT/by-path"
_cc_storage_linux_devices_raw() {
    printf '%s\n' \
        "PATH=\"$DEVICE_ROOT/sda\" NAME=\"sda\" KNAME=\"sda\" PKNAME=\"\" TYPE=\"disk\" MODEL=\"SATA Disk\" SERIAL=\"SERIAL-A\" WWN=\"0x5000\" SIZE=\"1000\" LOG-SEC=\"512\" TRAN=\"sata\" RM=\"0\" RO=\"0\"" \
        "PATH=\"$DEVICE_ROOT/sda1\" NAME=\"sda1\" KNAME=\"sda1\" PKNAME=\"sda\" TYPE=\"part\" MODEL=\"\" SERIAL=\"\" WWN=\"\" SIZE=\"900\" LOG-SEC=\"512\" TRAN=\"\" RM=\"0\" RO=\"0\"" \
        "PATH=\"$DEVICE_ROOT/nvme0n1\" NAME=\"nvme0n1\" KNAME=\"nvme0n1\" PKNAME=\"\" TYPE=\"disk\" MODEL=\"NVMe\" SERIAL=\"\" WWN=\"\" SIZE=\"2000\" LOG-SEC=\"4096\" TRAN=\"nvme\" RM=\"0\" RO=\"0\"" \
        "PATH=\"$DEVICE_ROOT/sdb\" NAME=\"sdb\" KNAME=\"sdb\" PKNAME=\"\" TYPE=\"disk\" MODEL=\"USB bridge\" SERIAL=\"USB-1\" WWN=\"\" SIZE=\"3000\" LOG-SEC=\"512\" TRAN=\"usb\" RM=\"1\" RO=\"0\""
}
records="$(cc_storage_devices_tsv)"
printf '%s\n' "$records" | grep -Fq "$DEVICE_ROOT/sda"$'\t'"$DEVICE_ROOT/by-id/wwn-0x5000" || fail 'stable by-id correlation failed'
printf '%s\n' "$records" | grep -Fq $'sda1\t' || fail 'partition was not represented'
printf '%s\n' "$records" | grep -Fq $'\tnvme\t' || fail 'NVMe transport was not represented'
printf '%s\n' "$records" | grep -Fq $'\tusb\t' || fail 'USB transport was not represented'

_cc_storage_linux_mounts_raw() {
    printf '%s\n' \
        'TARGET="/data" SOURCE="/dev/sda1" FSTYPE="ext4" OPTIONS="rw,relatime" SIZE="1000" USED="950" AVAIL="50" USE%="95%"' \
        'TARGET="/archive" SOURCE="/dev/sdb" FSTYPE="xfs" OPTIONS="ro,relatime" SIZE="3000" USED="10" AVAIL="2990" USE%="1%"'
}
CC_STORAGE_MDSTAT_PATH="$TEST_DIR/mdstat"
printf 'md0 : active raid1 sda1[0] sdb1[1]\nmd1 : active raid1 sdc1[0] sdd1[_]\n      [>....................]  recovery = 5.0%%\n' > "$CC_STORAGE_MDSTAT_PATH"
CC_STORAGE_ZPOOL_PROGRAM="$TEST_DIR/zpool"
CC_STORAGE_ZFS_PROGRAM="$TEST_DIR/zfs"
cat > "$TEST_DIR/zpool" <<'EOF_ZPOOL'
#!/usr/bin/env bash
case "$1:$2" in list:-H) printf 'tank\tDEGRADED\t80%%\n';; status:tank) printf '  scan: scrub repaired 0B in 0 days with 0 errors\n';; esac
EOF_ZPOOL
cat > "$TEST_DIR/zfs" <<'EOF_ZFS'
#!/usr/bin/env bash
printf 'tank/data\t100\t900\tyes\t/data\toff\n'
EOF_ZFS
chmod 755 "$TEST_DIR/zpool" "$TEST_DIR/zfs"
cc_storage_snapshot_reset
findings="$(cc_storage_local_findings_tsv)"
printf '%s\n' "$findings" | grep -q 'CAPACITY_PRESSURE' || fail 'capacity pressure finding absent'
printf '%s\n' "$findings" | grep -q 'FILESYSTEM_READONLY' || fail 'read-only mount finding absent'
printf '%s\n' "$findings" | grep -q 'MDRAID_DEGRADED' || fail 'mdraid degraded finding absent'
printf '%s\n' "$findings" | grep -q 'MDRAID_RECOVERING' || fail 'mdraid recovery finding absent'
printf '%s\n' "$findings" | grep -q 'ZFS_POOL_DEGRADED' || fail 'ZFS degraded finding absent'

cc_storage_log_since_tsv() {
    cat <<'EOF_LOGS'
2026-09-13T00:00:00+00:00 host kernel: usb 1-1: reset SuperSpeed USB device number 2
2026-09-13T00:01:00+00:00 host kernel: uas: UAS abort task set timeout
2026-09-13T00:02:00+00:00 host kernel: blk_update_request: I/O error, dev sdb, sector 1
2026-09-13T00:03:00+00:00 host kernel: EXT4-fs error (device sda1): ext4_find_entry
2026-09-13T00:04:00+00:00 host kernel: Remounting filesystem read-only
EOF_LOGS
}
logs="$(cc_storage_log_findings_tsv '24 hours ago')"
printf '%s\n' "$logs" | grep -q $'USB_RESET\tusb' || fail 'USB reset layer absent'
printf '%s\n' "$logs" | grep -q $'USB_UAS_TIMEOUT\tusb' || fail 'UAS layer absent'
printf '%s\n' "$logs" | grep -q $'BLOCK_IO_ERROR\tkernel_io' || fail 'kernel I/O layer absent'
printf '%s\n' "$logs" | grep -q $'FILESYSTEM_ERROR\tfilesystem' || fail 'filesystem layer absent'
printf '%s\n' "$logs" | grep -q $'FILESYSTEM_READONLY\tmount' || fail 'mount layer absent'

printf 'Storage verification fixture tests: PASS\n'
