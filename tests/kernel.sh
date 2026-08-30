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
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

BOOT_DIR="$TEST_DIR/boot"
BIN_DIR="$TEST_DIR/bin"
MUTATION_LOG="$TEST_DIR/mutations.log"
DPKG_LOG="$TEST_DIR/dpkg.log"
mkdir -p "$BOOT_DIR" "$BIN_DIR"
touch "$BOOT_DIR/vmlinuz-6.8.0-10-generic"
touch "$BOOT_DIR/vmlinuz-6.8.0-20-generic"
touch "$BOOT_DIR/vmlinuz-6.8.0-30-generic"
touch "$BOOT_DIR/vmlinuz-6.8.0-40-generic"
touch "$BOOT_DIR/vmlinuz-6.8.0-50-generic"
touch "$BOOT_DIR/vmlinuz-6.8.0-99-generic.safe"

CC_KERNEL_OS=Linux
CC_KERNEL_RUNNING=6.8.0-10-generic
CC_KERNEL_BOOT_DIR="$BOOT_DIR"
CC_KERNEL_REBOOT_MARKER="$TEST_DIR/reboot-required"
export CC_KERNEL_OS CC_KERNEL_RUNNING CC_KERNEL_BOOT_DIR CC_KERNEL_REBOOT_MARKER

_cc_pkg_list_installed() {
    printf '%s\n' \
        linux-image-generic \
        linux-image-6.8.0-10-generic linux-modules-6.8.0-10-generic \
        linux-image-6.8.0-20-generic linux-modules-6.8.0-20-generic linux-headers-6.8.0-20-generic \
        linux-image-6.8.0-30-generic linux-modules-6.8.0-30-generic \
        linux-image-6.8.0-40-generic linux-modules-6.8.0-40-generic \
        linux-image-6.8.0-50-generic linux-modules-6.8.0-50-generic
}
_cc_pkg_owners_of_path() { printf '%s\n' "linux-image-${1##*vmlinuz-}"; }
_cc_pkg_is_installed() { _cc_pkg_list_installed | grep -Fxq -- "$1"; }

[ "$(_cc_kernel_running)" = 6.8.0-10-generic ] || fail 'running kernel detection changed'
ordered_text="$(printf '%s\n' 6.8.0-40 6.8.0-9 6.8.0-10 | _cc_kernel_version_order)"
[ "$ordered_text" = $'6.8.0-9\n6.8.0-10\n6.8.0-40' ] || fail 'kernel version ordering changed'

selection_releases=(
    6.8.0-10-generic
    6.8.0-20-generic
    6.8.0-30-generic
    6.8.0-40-generic
    6.8.0-50-generic
)
[ "$(_cc_kernel_select_pending 6.8.0-30-generic "${selection_releases[@]}")" = 6.8.0-50-generic ] ||
    fail 'newest verified pending kernel selection changed'
[ "$(_cc_kernel_select_fallback 6.8.0-30-generic "${selection_releases[@]}")" = 6.8.0-20-generic ] ||
    fail 'nearest older fallback kernel selection changed'
[ -z "$(_cc_kernel_select_fallback 6.8.0-10-generic "${selection_releases[@]}")" ] ||
    fail 'pending kernel was incorrectly treated as a safe fallback'
minimal_protected="$(_cc_kernel_select_protected 0 6.8.0-30-generic "${selection_releases[@]}")"
assert_contains "$minimal_protected" 6.8.0-20-generic 'safe fallback was not protected with KEEP_COUNT=0'
assert_contains "$minimal_protected" 6.8.0-30-generic 'running kernel was not protected with KEEP_COUNT=0'
assert_contains "$minimal_protected" 6.8.0-50-generic 'pending kernel was not protected with KEEP_COUNT=0'
if printf '%s\n' "$minimal_protected" | grep -Fxq 6.8.0-40-generic; then
    fail 'KEEP_COUNT=0 protected an unrelated additional kernel'
fi

installed_text="$(_cc_kernel_list)"
assert_contains "$installed_text" 6.8.0-50-generic 'package-only kernel was not discovered'
if printf '%s\n' "$installed_text" | grep -Fq 6.8.0-99-generic.safe; then
    fail 'safe artifact was classified as an installed kernel'
fi
[ "$(_cc_kernel_newest)" = 6.8.0-50-generic ] || fail 'newest kernel selection changed'

protected_text="$(_cc_kernel_protected 2)"
assert_contains "$protected_text" 6.8.0-10-generic 'old running kernel was not protected'
assert_contains "$protected_text" 6.8.0-40-generic 'KEEP_COUNT omitted a recent kernel'
assert_contains "$protected_text" 6.8.0-50-generic 'KEEP_COUNT omitted newest kernel'
candidate_text="$(_cc_kernel_cleanup_candidates 2)"
if printf '%s\n' "$candidate_text" | grep -Fxq 6.8.0-10-generic; then
    fail 'running kernel entered cleanup candidates'
fi
assert_contains "$candidate_text" 6.8.0-20-generic 'expected old candidate missing'
assert_contains "$candidate_text" 6.8.0-30-generic 'expected old candidate missing'

[ -z "$(_cc_kernel_cleanup_candidates 4)" ] || fail 'zero-candidate condition changed'

package_text="$(_cc_kernel_packages_for_version 6.8.0-20-generic)"
assert_contains "$package_text" linux-image-6.8.0-20-generic 'kernel image package mapping failed'
assert_contains "$package_text" linux-modules-6.8.0-20-generic 'kernel module package mapping failed'
assert_contains "$package_text" linux-headers-6.8.0-20-generic 'kernel header package mapping failed'

# shellcheck disable=SC2329 # Invoked indirectly by kernel mapping helpers.
_cc_pkg_owners_of_path() {
    printf '%s\n' "linux-image-${1##*vmlinuz-}" "unexpected-owner"
}
if _cc_kernel_packages_for_version 6.8.0-20-generic >/dev/null 2>&1; then
    fail 'ambiguous package ownership did not fail safe'
fi
_cc_pkg_owners_of_path() { printf '%s\n' "linux-image-${1##*vmlinuz-}"; }

[ "$(_cc_kernel_reboot_state)" = newer-kernel-installed ] || fail 'newer-kernel reboot state changed'
touch "$CC_KERNEL_REBOOT_MARKER"
[ "$(_cc_kernel_reboot_state)" = required ] || fail 'reboot marker was not honored'
rm -f "$CC_KERNEL_REBOOT_MARKER"
CC_KERNEL_RUNNING=6.8.0-50-generic
[ "$(_cc_kernel_reboot_state)" = not-required ] || fail 'current-kernel reboot state changed'
CC_KERNEL_RUNNING=6.8.0-10-generic

CC_KERNEL_OS=FreeBSD
[ "$(_cc_kernel_reboot_state)" = unknown ] || fail 'unsupported reboot state was not unknown'
if _cc_kernel_cleanup_candidates 2 >/dev/null 2>&1; then
    fail 'unsupported platform offered cleanup candidates'
fi
CC_KERNEL_OS=Linux

update_grub_called=0
# Intentionally proves that the abstraction does not invoke this command.
# shellcheck disable=SC2329
update-grub() { update_grub_called=1; }
export -f update-grub
_cc_kernel_cleanup_supported() { return 0; }
[ "$(_cc_kernel_refresh_bootloader)" = package-lifecycle-managed ] || fail 'bootloader policy changed'
[ "$update_grub_called" -eq 0 ] || fail 'bootloader refresh invoked update-grub'
unset -f update-grub

cat > "$BIN_DIR/dpkg" <<'EOF_DPKG'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CC_KERNEL_TEST_DPKG_LOG"
if [ "${1:-}" = --compare-versions ]; then
    /usr/bin/dpkg "$@"
else
    exit 2
fi
EOF_DPKG
cat > "$BIN_DIR/dpkg-query" <<'EOF_DPKG_QUERY'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CC_KERNEL_TEST_DPKG_LOG"
if [ "${1:-}" = -l ]; then
    for version in 10 20 30 40; do
        printf 'ii  linux-image-6.8.0-%s-generic  1  amd64  image\n' "$version"
        printf 'ii  linux-modules-6.8.0-%s-generic  1  amd64  modules\n' "$version"
        printf 'ii  linux-headers-6.8.0-%s-generic  1  amd64  headers\n' "$version"
    done
elif [ "${1:-}" = -S ]; then
    version="${2##*vmlinuz-}"
    printf 'linux-image-%s: %s\n' "$version" "$2"
elif [ "${1:-}" = -s ]; then
    printf 'Status: install ok installed\n'
elif [ "${1:-}" = -W ]; then
    if [ "$#" -ge 3 ]; then printf '100\n'; fi
else
    exit 2
fi
EOF_DPKG_QUERY
cat > "$BIN_DIR/apt-mark" <<'EOF_APT_MARK'
#!/usr/bin/env bash
case "${1:-}" in
    showmanual) printf '%s\n' "${2:-}" ;;
    showauto) : ;;
    *) exit 2 ;;
esac
EOF_APT_MARK
cat > "$BIN_DIR/sudo" <<'EOF_SUDO'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CC_KERNEL_TEST_MUTATION_LOG"
EOF_SUDO
chmod 755 "$BIN_DIR/dpkg" "$BIN_DIR/dpkg-query" "$BIN_DIR/apt-mark" "$BIN_DIR/sudo"

export CC_KERNEL_TEST_MUTATION_LOG="$MUTATION_LOG"
export CC_KERNEL_TEST_DPKG_LOG="$DPKG_LOG"
status_output="$(PATH="$BIN_DIR:$PATH" bash "$PROJECT_ROOT/tools/commands/kernel" status)"
assert_contains "$status_output" 'Running kernel:' 'status omitted running kernel'
assert_contains "$status_output" 'Cleanup candidates:' 'status omitted candidate count'
: > "$DPKG_LOG"
list_output="$(PATH="$BIN_DIR:$PATH" KEEP_COUNT=2 bash "$PROJECT_ROOT/tools/commands/kernel" list)"
assert_contains "$list_output" 'RUNNING' 'list omitted running protection'
assert_contains "$list_output" 'PENDING' 'list omitted pending-kernel protection'
assert_contains "$list_output" 'CANDIDATE' 'list omitted candidate classification'
[ "$(grep -c '^-l$' "$DPKG_LOG")" -eq 1 ] || fail 'list did not use one prepared installed-package inventory'

: > "$MUTATION_LOG"
dry_output="$(PATH="$BIN_DIR:$PATH" KEEP_COUNT=2 LOG="$TEST_DIR/kernel.log" bash "$PROJECT_ROOT/tools/commands/kernel" cleanup --dry-run)"
assert_contains "$dry_output" 'DRY RUN only' 'dry-run did not report safe mode'
[ ! -s "$MUTATION_LOG" ] || fail 'dry-run reached a mutation operation'
[ ! -e "$TEST_DIR/kernel.log" ] || fail 'dry-run wrote a cleanup log'

: > "$MUTATION_LOG"
compat_output="$(PATH="$BIN_DIR:$PATH" KEEP_COUNT=2 LOG="$TEST_DIR/kernel.log" \
    bash "$PROJECT_ROOT/tools/commands/kernel-cleanup" --dry-run)"
assert_contains "$compat_output" 'DRY RUN only' 'kernel-cleanup compatibility wrapper changed behavior'
[ ! -s "$MUTATION_LOG" ] || fail 'kernel-cleanup compatibility dry-run reached a mutation operation'

: > "$MUTATION_LOG"
PATH="$BIN_DIR:$PATH" KEEP_COUNT=2 LOG="$TEST_DIR/kernel.log" \
    bash "$PROJECT_ROOT/tools/commands/kernel" cleanup --apply >/dev/null
mutations="$(cat "$MUTATION_LOG")"
assert_contains "$mutations" 'apt-get purge -y --' 'apply did not reach bounded semantic package purge'
if printf '%s\n' "$mutations" | grep -Eq 'autoremove|autoclean'; then
    fail 'apply reached an unbounded package-manager cleanup operation'
fi
if printf '%s\n' "$mutations" | grep -Fq 6.8.0-10-generic; then
    fail 'apply attempted to purge the running kernel'
fi

kernel_home="$TEST_DIR/home"
canonical_log="$kernel_home/.captaincronos/hosts/kernel-fixture/logs/kernel-cleanup.log"
mkdir -p "$kernel_home"
PATH="$BIN_DIR:$PATH" HOME="$kernel_home" CC_HOME="$kernel_home/.captaincronos" \
    CC_HOST_ID=kernel-fixture KEEP_COUNT=2 \
    bash "$PROJECT_ROOT/tools/commands/kernel" cleanup --apply >/dev/null
[ -f "$canonical_log" ] || fail 'kernel cleanup did not use the canonical host log'
[ "$(stat -c %a "$canonical_log")" = 600 ] || fail 'kernel cleanup log was not private'
[ "$(stat -c %a "$(dirname "$canonical_log")")" = 700 ] || fail 'kernel cleanup log directory was not private'

printf 'Kernel management tests: PASS\n'
