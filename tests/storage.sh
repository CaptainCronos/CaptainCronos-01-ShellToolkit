#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-common.sh"
source "$PROJECT_ROOT/lib/cc-smart.sh"
source "$PROJECT_ROOT/lib/cc-storage.sh"

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
