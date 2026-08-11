#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TOOLKIT_ROOT="$PROJECT_ROOT"
source "$PROJECT_ROOT/tools/commands/doctor"
source "$PROJECT_ROOT/tools/commands/monthly-health"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    local text="$1" expected="$2" label="$3"
    printf '%s\n' "$text" | grep -Fq -- "$expected" || fail "$label"
}

declare -A TEST_KERNEL_SNAPSHOT=()
TEST_KERNEL_FINDINGS=''
TEST_KERNEL_CAPTURE_FAIL=0
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
DOCTOR_OUTPUT=''

kernel_fixture() {
    local health="$1" reboot="$2" candidates="$3" findings="${4:-}"
    TEST_KERNEL_SNAPSHOT=(
        [health_status]="$health"
        [running]="7.0.0-running"
        [newest]="7.0.0-running"
        [running_is_newest]="yes"
        [reboot_state]="$reboot"
        [os]="Linux"
        [distribution_family]="debian"
        [package_model]="Debian linux-image packages"
        [initramfs_provider]="initramfs-tools"
        [bootloader]="grub"
        [efi_filesystem_state]="present"
        [efi_runtime_state]="active"
        [installed_count]="4"
        [protected_count]="3"
        [cleanup_candidate_count]="$candidates"
        [boot_path]="/boot"
        [boot_filesystem]="/dev/root"
        [boot_filesystem_mount]="/"
        [boot_filesystem_usage]="39%"
        [boot_artifact_bytes]="440401920"
        [boot_artifact_usage]="420.0 MiB"
        [efi_usage]="1%"
        [artifact_matched]="4"
        [artifact_partial]="0"
        [artifact_unmatched]="0"
        [artifact_missing]="0"
        [artifact_unknown]="0"
    )
    TEST_KERNEL_FINDINGS="$findings"
    TEST_KERNEL_CAPTURE_FAIL=0
}

_cc_kernel_snapshot_capture() {
    [ "$TEST_KERNEL_CAPTURE_FAIL" -eq 0 ]
}

_cc_kernel_snapshot_get() {
    [ "$#" -eq 1 ] || return 2
    printf '%s\n' "${TEST_KERNEL_SNAPSHOT[$1]:-unknown}"
}

_cc_kernel_snapshot_findings() {
    [ -n "$TEST_KERNEL_FINDINGS" ] && printf '%s\n' "$TEST_KERNEL_FINDINGS"
    return 0
}

run_doctor_fixture() {
    doctor_kernel_check >"$TEST_DIR/doctor.out" 2>&1
    DOCTOR_OUTPUT="$(<"$TEST_DIR/doctor.out")"
}

kernel_fixture PASS not-required 1 $'PASS\tCONSISTENT\tKernel packages and boot artifacts are consistent.'
WARNINGS=0; FAILURES=0
run_doctor_fixture
assert_contains "$DOCTOR_OUTPUT" 'Kernel health......................... PASS' 'doctor did not propagate kernel PASS'
assert_contains "$DOCTOR_OUTPUT" 'Running kernel:    7.0.0-running' 'doctor omitted the running kernel'
[ "$WARNINGS" -eq 0 ] || fail 'cleanup opportunity changed doctor PASS to WARN'
[ "$FAILURES" -eq 0 ] || fail 'cleanup opportunity changed doctor PASS to FAIL'

kernel_fixture WARN required 0 $'WARN\tREBOOT_REQUIRED\tThe host reboot marker is present.'
WARNINGS=0; FAILURES=0
run_doctor_fixture
assert_contains "$DOCTOR_OUTPUT" 'Kernel health......................... WARN' 'doctor did not propagate reboot WARN'
assert_contains "$DOCTOR_OUTPUT" REBOOT_REQUIRED 'doctor omitted the reboot finding code'
[ "$WARNINGS" -eq 1 ] || fail 'doctor did not aggregate reboot WARN'
[ "$FAILURES" -eq 0 ] || fail 'routine reboot state became doctor FAIL'

kernel_fixture WARN newer-kernel-installed 0 $'WARN\tNEWER_KERNEL_AVAILABLE\tA newer installed kernel is not currently running.'
WARNINGS=0; FAILURES=0
run_doctor_fixture
assert_contains "$DOCTOR_OUTPUT" NEWER_KERNEL_AVAILABLE 'doctor omitted newer-kernel advisory'
[ "$WARNINGS" -eq 1 ] || fail 'newer kernel did not aggregate as WARN'

kernel_fixture WARN not-required 0 $'WARN\tARTIFACT_PARTIAL\tA protected kernel has partial artifacts.'
WARNINGS=0; FAILURES=0
doctor_kernel_check >/dev/null 2>&1
[ "$WARNINGS" -eq 1 ] || fail 'semantic kernel WARN was not propagated'

kernel_fixture FAIL not-required 0 $'FAIL\tRUNNING_KERNEL_ARTIFACT_FAILURE\tRunning kernel image is missing.'
WARNINGS=0; FAILURES=0
{ doctor_kernel_check; printf 'CONTINUED\n'; } >"$TEST_DIR/doctor.out" 2>&1
continued_output="$(<"$TEST_DIR/doctor.out")"
assert_contains "$continued_output" 'Kernel health......................... FAIL' 'doctor did not propagate kernel FAIL'
assert_contains "$continued_output" CONTINUED 'doctor stopped after a kernel failure'
[ "$FAILURES" -eq 1 ] || fail 'doctor did not aggregate kernel FAIL'

kernel_fixture WARN unknown 0 $'WARN\tREDUCED_INSPECTION\tDetailed boot-artifact inspection is unsupported on FreeBSD.'
TEST_KERNEL_SNAPSHOT[os]=FreeBSD
TEST_KERNEL_SNAPSHOT[distribution_family]='not-applicable'
TEST_KERNEL_SNAPSHOT[initramfs_provider]='not applicable'
TEST_KERNEL_SNAPSHOT[bootloader]=unknown
TEST_KERNEL_SNAPSHOT[efi_runtime_state]=unknown
WARNINGS=0; FAILURES=0
doctor_kernel_check >/dev/null 2>&1
[ "$FAILURES" -eq 0 ] || fail 'reduced non-Linux inspection became doctor FAIL'

TEST_KERNEL_CAPTURE_FAIL=1
WARNINGS=0; FAILURES=0
run_doctor_fixture
assert_contains "$DOCTOR_OUTPUT" 'semantic snapshot' 'doctor did not handle snapshot failure gracefully'
[ "$WARNINGS" -eq 1 ] || fail 'snapshot failure did not produce a diagnostic WARN'
[ "$FAILURES" -eq 0 ] || fail 'snapshot failure unexpectedly became a hard FAIL'

kernel_fixture PASS not-required 1 $'PASS\tCONSISTENT\tKernel packages and boot artifacts are consistent.'
monthly_output="$(print_kernel_health)"
assert_contains "$monthly_output" 'Overall health:              PASS' 'monthly health omitted kernel PASS'
assert_contains "$monthly_output" 'Cleanup candidates:          1' 'monthly health omitted cleanup candidate count'
assert_contains "$monthly_output" 'old kernel cleanup available' 'cleanup candidate was not a maintenance advisory'
assert_contains "$monthly_output" 'Initramfs provider:          initramfs-tools' 'monthly health omitted initramfs provider'
assert_contains "$monthly_output" 'Bootloader:                  grub' 'monthly health omitted bootloader'
assert_contains "$monthly_output" 'EFI runtime:                 active' 'monthly health omitted EFI runtime'
assert_contains "$monthly_output" 'Boot filesystem usage:       39%' 'monthly health omitted boot usage'
assert_contains "$monthly_output" '/boot artifact allocation:   420.0 MiB' 'monthly health omitted boot allocation'
assert_contains "$monthly_output" 'Matched:                     4' 'monthly health omitted artifact counts'

kernel_fixture WARN required 0 $'WARN\tREBOOT_REQUIRED\tThe host reboot marker is present.'
monthly_rc=0
monthly_output="$(print_kernel_health)" || monthly_rc=$?
[ "$monthly_rc" -eq 10 ] || fail 'monthly kernel WARN did not return semantic WARN'
assert_contains "$monthly_output" 'Overall health:              WARN' 'monthly health omitted WARN severity'
assert_contains "$monthly_output" 'reboot recommended' 'monthly health omitted reboot maintenance advisory'
assert_contains "$monthly_output" REBOOT_REQUIRED 'monthly health omitted WARN findings'

kernel_fixture FAIL not-required 0 $'FAIL\tBOOT_PATH_INACCESSIBLE\tBoot path is inaccessible.'
monthly_rc=0
monthly_output="$(print_kernel_health)" || monthly_rc=$?
[ "$monthly_rc" -eq 1 ] || fail 'monthly kernel FAIL did not return failure'
assert_contains "$monthly_output" 'Overall health:              FAIL' 'monthly health omitted FAIL severity'
assert_contains "$monthly_output" BOOT_PATH_INACCESSIBLE 'monthly health omitted FAIL findings'

kernel_fixture WARN unknown 0 $'WARN\tREDUCED_INSPECTION\tDetailed boot-artifact inspection is unsupported on FreeBSD.'
TEST_KERNEL_SNAPSHOT[os]=FreeBSD
TEST_KERNEL_SNAPSHOT[distribution_family]='not-applicable'
TEST_KERNEL_SNAPSHOT[artifact_matched]=unavailable
monthly_rc=0
monthly_output="$(print_kernel_health)" || monthly_rc=$?
[ "$monthly_rc" -eq 10 ] || fail 'reduced monthly kernel inspection did not return WARN'
assert_contains "$monthly_output" 'OS:                          FreeBSD' 'monthly health omitted reduced platform'
assert_contains "$monthly_output" 'Matched:                     unavailable' 'monthly health faked Linux artifact counts'

grep -Fq "source \"\$TOOLKIT_ROOT/lib/cc-kernel.sh\"" "$PROJECT_ROOT/tools/commands/doctor" ||
    fail 'doctor does not source the semantic kernel library'
grep -Fq "source \"\$PROJECT_ROOT/lib/cc-kernel.sh\"" "$PROJECT_ROOT/tools/commands/monthly-health" ||
    fail 'monthly-health does not source the semantic kernel library'
grep -Fq '_cc_kernel_snapshot_capture' "$PROJECT_ROOT/tools/commands/doctor" ||
    fail 'doctor does not consume the kernel snapshot API'
grep -Fq '_cc_kernel_snapshot_capture' "$PROJECT_ROOT/tools/commands/monthly-health" ||
    fail 'monthly-health does not consume the kernel snapshot API'
if grep -Eq 'tools/commands/kernel|tools/cc"[[:space:]]+kernel|kernel[[:space:]]+cleanup[[:space:]]+--|cleanup --apply' \
    "$PROJECT_ROOT/tools/commands/doctor" "$PROJECT_ROOT/tools/commands/monthly-health"; then
    fail 'health consumer invokes a kernel CLI or cleanup path'
fi

printf 'Kernel health integration tests: PASS\n'
