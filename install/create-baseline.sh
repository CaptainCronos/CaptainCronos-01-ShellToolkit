#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : create-baseline.sh
# Version     : reads VERSION
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Capture Ubuntu baseline shell files from /etc/skel.
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT"

source "$PROJECT_ROOT/lib/cc-common.sh"

case "${1:-}" in
    --help|-h)
        echo "Usage: install/create-baseline.sh"
        exit 0
        ;;
    --version)
        cc_version
        exit 0
        ;;
esac

cc_banner

BASELINE_DIR="baseline/ubuntu-26.04"
mkdir -p "$BASELINE_DIR"

[ -f /etc/skel/.bashrc ] && cp -f /etc/skel/.bashrc "$BASELINE_DIR/bashrc.original" || : > "$BASELINE_DIR/bashrc.original"
[ -f /etc/skel/.bash_aliases ] && cp -f /etc/skel/.bash_aliases "$BASELINE_DIR/bash_aliases.original" || : > "$BASELINE_DIR/bash_aliases.original"

: > "$BASELINE_DIR/bash_functions.original"

{
    echo "Captured: $(date)"
    echo "Kernel: $(uname -r)"
    echo
    echo "Bash:"
    bash --version
    echo
    echo "OS:"
    lsb_release -a 2>/dev/null || cat /etc/os-release
} > "$BASELINE_DIR/shell-version.txt"

apt-mark showmanual > "$BASELINE_DIR/packages.list" 2>/dev/null || true
env | sort > "$BASELINE_DIR/env.txt"

cat > "$BASELINE_DIR/README.md" <<'EOFBASE'
# Ubuntu 26.04 Baseline

Pristine shell baseline captured from the operating system skeleton files.

These files are for recovery, comparison, and factory reference.
EOFBASE

cc_log "Baseline captured in $BASELINE_DIR"
