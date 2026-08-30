#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-kernel.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    local text="$1" expected="$2" label="$3"
    printf '%s\n' "$text" | grep -Fq -- "$expected" || fail "$label"
}

TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
BOOT_DIR="$TEST_DIR/boot"
EFI_DIR="$BOOT_DIR/efi"
BIN_DIR="$TEST_DIR/bin"
DU_LOG="$TEST_DIR/du.log"
mkdir -p "$BOOT_DIR" "$EFI_DIR" "$BIN_DIR"

cat > "$BIN_DIR/findmnt" <<'EOF_FINDMNT'
#!/usr/bin/env bash
field="${2:-}"
mode="${3:-}"
path="${4:-}"
case "$mode:$path:$CC_TEST_MOUNT_SCENARIO" in
    "--target:$CC_KERNEL_BOOT_DIR:root"|"--target:$CC_KERNEL_BOOT_DIR:efi"|"--target:$CC_KERNEL_BOOT_DIR:efi-high")
        source=/dev/root-device; fstype=ext4; target=/; size=100G; used=20G; avail=80G; use=20%
        ;;
    "--target:$CC_KERNEL_BOOT_DIR:dedicated")
        source=/dev/boot-device; fstype=ext4; target="$CC_KERNEL_BOOT_DIR"; size=1G; used=400M; avail=600M; use=40%
        ;;
    "--mountpoint:$CC_KERNEL_EFI_PATH:efi")
        source=/dev/efi-device; fstype=vfat; target="$CC_KERNEL_EFI_PATH"; size=512M; used=8M; avail=504M; use=2%
        ;;
    "--mountpoint:$CC_KERNEL_EFI_PATH:efi-high")
        source=/dev/efi-device; fstype=vfat; target="$CC_KERNEL_EFI_PATH"; size=512M; used=490M; avail=22M; use=96%
        ;;
    *) exit 1 ;;
esac
case "$field" in
    SOURCE) printf '%s\n' "$source" ;;
    FSTYPE) printf '%s\n' "$fstype" ;;
    TARGET) printf '%s\n' "$target" ;;
    SIZE) printf '%s\n' "$size" ;;
    USED) printf '%s\n' "$used" ;;
    AVAIL) printf '%s\n' "$avail" ;;
    USE%) printf '%s\n' "$use" ;;
    *) exit 2 ;;
esac
EOF_FINDMNT

cat > "$BIN_DIR/du-fixture" <<'EOF_DU'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CC_TEST_DU_LOG"
printf '123\t%s\n' "${@: -1}"
EOF_DU

cat > "$BIN_DIR/dpkg" <<'EOF_DPKG'
#!/usr/bin/env bash
if [ "${1:-}" = --compare-versions ]; then
    /usr/bin/dpkg "$@"
else
    exit 2
fi
EOF_DPKG
cat > "$BIN_DIR/dpkg-query" <<'EOF_DPKG_QUERY'
#!/usr/bin/env bash
if [ "${1:-}" = -l ]; then
    printf 'ii  linux-image-1.0-test  1  amd64  image\n'
elif [ "${1:-}" = -S ]; then
    printf 'linux-image-1.0-test: %s\n' "$2"
else
    exit 2
fi
EOF_DPKG_QUERY
chmod 755 "$BIN_DIR/findmnt" "$BIN_DIR/du-fixture" "$BIN_DIR/dpkg" "$BIN_DIR/dpkg-query"

CC_KERNEL_OS=Linux
CC_KERNEL_RUNNING=1.0-test
CC_KERNEL_BOOT_DIR="$BOOT_DIR"
CC_KERNEL_EFI_PATH="$EFI_DIR"
CC_KERNEL_FINDMNT_PROGRAM="$BIN_DIR/findmnt"
CC_KERNEL_REBOOT_MARKER="$TEST_DIR/reboot-required"
export CC_KERNEL_OS CC_KERNEL_RUNNING CC_KERNEL_BOOT_DIR CC_KERNEL_EFI_PATH
export CC_KERNEL_FINDMNT_PROGRAM CC_KERNEL_REBOOT_MARKER

CC_TEST_MOUNT_SCENARIO=root
export CC_TEST_MOUNT_SCENARIO
[ "$(_cc_kernel_boot_filesystem_field SOURCE)" = /dev/root-device ] || fail '/boot-on-root source detection failed'
[ "$(_cc_kernel_boot_filesystem_field TARGET)" = / ] || fail '/boot-on-root mount detection failed'

CC_TEST_MOUNT_SCENARIO=dedicated
[ "$(_cc_kernel_boot_filesystem_field SOURCE)" = /dev/boot-device ] || fail 'dedicated /boot source detection failed'
[ "$(_cc_kernel_boot_filesystem_field TARGET)" = "$BOOT_DIR" ] || fail 'dedicated /boot mount detection failed'

CC_TEST_MOUNT_SCENARIO=efi
[ "$(_cc_kernel_efi_path)" = "$EFI_DIR" ] || fail 'EFI mount detection failed'
[ "$(_cc_kernel_efi_filesystem_field SOURCE)" = /dev/efi-device ] || fail 'EFI source reporting failed'
[ "$(_cc_kernel_efi_filesystem_field FSTYPE)" = vfat ] || fail 'EFI filesystem type reporting failed'
[ "$(_cc_kernel_efi_filesystem_field SIZE)" = 512M ] || fail 'EFI size reporting failed'
[ "$(_cc_kernel_efi_filesystem_field USE%)" = 2% ] || fail 'EFI utilization reporting failed'

CC_TEST_MOUNT_SCENARIO=root
if _cc_kernel_efi_path >/dev/null 2>&1; then
    fail 'unmounted EFI directory was reported as a mounted filesystem'
fi

CC_KERNEL_DU_PROGRAM="$BIN_DIR/du-fixture"
CC_TEST_DU_LOG="$DU_LOG"
export CC_KERNEL_DU_PROGRAM CC_TEST_DU_LOG
[ "$(_cc_kernel_boot_usage_bytes)" -eq 125952 ] || fail 'actual /boot usage conversion changed'
assert_contains "$(cat "$DU_LOG")" '-skx' 'boot usage did not preserve filesystem boundaries'
unset CC_KERNEL_DU_PROGRAM

printf '%4096s' x > "$BOOT_DIR/usage-fixture"
dd if=/dev/zero of="$TEST_DIR/external-large" bs=1048576 count=1 status=none
usage_before="$(_cc_kernel_boot_usage_bytes)"
ln -s "$TEST_DIR/external-large" "$BOOT_DIR/external-link"
usage_after="$(_cc_kernel_boot_usage_bytes)"
[ "$((usage_after - usage_before))" -lt 1048576 ] || fail 'boot usage followed a symlink outside /boot'

make_set() {
    local release="$1"
    printf kernel > "$BOOT_DIR/vmlinuz-$release"
    printf initramfs > "$BOOT_DIR/initrd.img-$release"
    printf map > "$BOOT_DIR/System.map-$release"
    printf config > "$BOOT_DIR/config-$release"
}

make_set 1.0-test
make_set 2.0-test
make_set 3.0-test
make_set 6.0-unmatched
make_set 9.0-unknown
make_set 10.0-ambiguous
printf kernel > "$BOOT_DIR/vmlinuz-4.0-missing-initramfs"
printf map > "$BOOT_DIR/System.map-4.0-missing-initramfs"
printf config > "$BOOT_DIR/config-4.0-missing-initramfs"
printf initramfs > "$BOOT_DIR/initrd.img-5.0-missing-kernel"
printf map > "$BOOT_DIR/System.map-5.0-missing-kernel"
printf config > "$BOOT_DIR/config-5.0-missing-kernel"
printf initramfs > "$BOOT_DIR/initrd.img-7.0-unmatched-initramfs"
printf kernel > "$BOOT_DIR/vmlinuz-8.0-partial"
printf initramfs > "$BOOT_DIR/initrd.img-8.0-partial"
ln -s "$TEST_DIR/external-large" "$BOOT_DIR/vmlinuz-symlink-test"
printf odd > "$BOOT_DIR/"$'vmlinuz-bad\tname'
printf odd > "$BOOT_DIR/initrd.img-space release"
printf odd > "$BOOT_DIR/initramfs-fedora-test.img"

_cc_pkg_list_installed() {
    printf '%s\n' \
        linux-image-1.0-test linux-image-2.0-test linux-image-3.0-test \
        linux-image-4.0-missing-initramfs linux-image-5.0-missing-kernel \
        linux-image-8.0-partial linux-image-9.0-unknown linux-image-10.0-ambiguous
}

_cc_pkg_owners_of_path() {
    local release="${1##*vmlinuz-}"
    case "$release" in
        9.0-unknown) return 1 ;;
        10.0-ambiguous) printf '%s\n' linux-image-10.0-ambiguous second-owner ;;
        *) printf '%s\n' "linux-image-$release" ;;
    esac
}

[ "$(_cc_kernel_artifact_state 1.0-test)" = MATCHED ] || fail 'complete artifact set was not MATCHED'
[ "$(_cc_kernel_artifact_size_bytes 1.0-test)" -eq 24 ] || fail 'per-release artifact size calculation changed'
[ "$(_cc_kernel_artifact_state 4.0-missing-initramfs)" = MISSING ] || fail 'missing initramfs was not MISSING'
[ "$(_cc_kernel_artifact_state 5.0-missing-kernel)" = MISSING ] || fail 'missing kernel image was not MISSING'
[ "$(_cc_kernel_artifact_state 6.0-unmatched)" = UNMATCHED ] || fail 'unmatched kernel image was not UNMATCHED'
[ "$(_cc_kernel_artifact_state 7.0-unmatched-initramfs)" = UNMATCHED ] || fail 'unmatched initramfs was not UNMATCHED'
[ "$(_cc_kernel_artifact_state 8.0-partial)" = PARTIAL ] || fail 'partial artifact set was not PARTIAL'
[ "$(_cc_kernel_artifact_state 9.0-unknown)" = UNKNOWN ] || fail 'unknown ownership was not UNKNOWN'
[ "$(_cc_kernel_artifact_state 10.0-ambiguous)" = UNKNOWN ] || fail 'ambiguous ownership was not UNKNOWN'
[ "$(_cc_kernel_artifact_presence kernel symlink-test)" = unknown ] || fail 'versioned symlink was followed'
[ "$(_cc_kernel_artifact_state 'space release')" = UNMATCHED ] || fail 'artifact filename with spaces was not handled safely'
[ "$(_cc_kernel_artifact_presence initramfs fedora-test)" = yes ] || fail 'dracut-style initramfs name was not recognized'
[ "$(_cc_kernel_artifact_unsafe_count)" -ge 1 ] || fail 'unsafe artifact name was not isolated'

classification="$(_cc_kernel_classification 1.0-test 1)"
assert_contains "$classification" RUNNING 'running artifact correlation lost kernel classification'
assert_contains "$classification" PROTECTED 'running artifact correlation lost protection'
assert_contains "$(_cc_kernel_classification 2.0-test 1)" CANDIDATE 'candidate artifact correlation changed'
assert_contains "$(_cc_kernel_classification 10.0-ambiguous 1)" PROTECTED 'newest protected artifact correlation changed'

PASS_BOOT="$TEST_DIR/pass-boot"
mkdir -p "$PASS_BOOT"
CC_KERNEL_BOOT_DIR="$PASS_BOOT"
CC_KERNEL_RUNNING=1.0-test
CC_KERNEL_EFI_PATH="$TEST_DIR/no-efi"
export CC_KERNEL_BOOT_DIR CC_KERNEL_RUNNING CC_KERNEL_EFI_PATH
make_set() {
    local release="$1"
    printf kernel > "$CC_KERNEL_BOOT_DIR/vmlinuz-$release"
    printf initramfs > "$CC_KERNEL_BOOT_DIR/initrd.img-$release"
    printf map > "$CC_KERNEL_BOOT_DIR/System.map-$release"
    printf config > "$CC_KERNEL_BOOT_DIR/config-$release"
}
make_set 1.0-test
_cc_pkg_list_installed() { printf '%s\n' linux-image-1.0-test; }
_cc_pkg_owners_of_path() { printf '%s\n' linux-image-1.0-test; }
[ "$(_cc_kernel_health_severity 1)" = PASS ] || fail 'healthy fixture did not report PASS'

CC_KERNEL_EFI_PATH="$EFI_DIR"
CC_TEST_MOUNT_SCENARIO=efi-high
export CC_KERNEL_EFI_PATH CC_TEST_MOUNT_SCENARIO
[ "$(_cc_kernel_health_severity 1)" = WARN ] || fail 'high EFI utilization did not report WARN'
CC_KERNEL_EFI_PATH="$TEST_DIR/no-efi"
CC_TEST_MOUNT_SCENARIO=root
export CC_KERNEL_EFI_PATH CC_TEST_MOUNT_SCENARIO

printf initramfs > "$PASS_BOOT/initrd.img-2.0-unmatched"
[ "$(_cc_kernel_health_severity 1)" = WARN ] || fail 'unmatched artifact did not report WARN'
rm -f "$PASS_BOOT/initrd.img-2.0-unmatched" "$PASS_BOOT/vmlinuz-1.0-test"
[ "$(_cc_kernel_health_severity 1)" = FAIL ] || fail 'missing running kernel image did not report FAIL'

make_set 1.0-test
CC_KERNEL_EFI_PATH="$EFI_DIR"
CC_TEST_MOUNT_SCENARIO=efi
export CC_KERNEL_EFI_PATH CC_TEST_MOUNT_SCENARIO
command_status="$(PATH="$BIN_DIR:$PATH" bash "$PROJECT_ROOT/tools/commands/kernel" status)"
assert_contains "$command_status" 'Boot filesystem mount:' 'status omitted /boot backing mount'
assert_contains "$command_status" 'INFO   /' 'status conflated /boot with its backing filesystem'
assert_contains "$command_status" '/boot artifacts:' 'status omitted actual /boot consumption'
assert_contains "$command_status" 'EFI filesystem type:' 'status omitted EFI filesystem details'
assert_contains "$command_status" 'INFO   vfat' 'status omitted EFI filesystem type'
command_artifacts="$(PATH="$BIN_DIR:$PATH" bash "$PROJECT_ROOT/tools/commands/kernel" artifacts)"
assert_contains "$command_artifacts" MATCHED 'artifact command omitted correlation state'
assert_contains "$command_artifacts" RUNNING,PROTECTED 'artifact command omitted shared classification'
command_health="$(PATH="$BIN_DIR:$PATH" bash "$PROJECT_ROOT/tools/commands/kernel" health)"
assert_contains "$command_health" 'Overall:           PASS' 'health command did not report PASS fixture'

CC_KERNEL_OS=FreeBSD
CC_KERNEL_FINDMNT_PROGRAM=cc-missing-findmnt
CC_KERNEL_DU_PROGRAM=cc-missing-du
CC_KERNEL_STAT_PROGRAM=cc-missing-stat
export CC_KERNEL_OS
export CC_KERNEL_FINDMNT_PROGRAM CC_KERNEL_DU_PROGRAM CC_KERNEL_STAT_PROGRAM
if bash "$PROJECT_ROOT/tools/commands/kernel" artifacts >/dev/null 2>&1; then
    fail 'unsupported platform accepted detailed artifact inspection'
fi
assert_contains "$(_cc_kernel_health_findings 1)" 'unsupported on FreeBSD' 'unsupported health behavior was unclear'
unsupported_status="$(bash "$PROJECT_ROOT/tools/commands/kernel" status)"
assert_contains "$unsupported_status" 'Running kernel:' 'reduced non-Linux status regressed without Linux tools'
assert_contains "$unsupported_status" '/boot artifacts:' 'reduced status omitted /boot artifact usage'
assert_contains "$unsupported_status" 'INFO   unavailable' 'missing optional usage tool was not graceful'

printf 'Kernel artifact health tests: PASS\n'
