#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : create-baseline.sh
# Version     : 0.1.0
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Capture baseline Ubuntu shell files from /etc/skel.
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT"

source "$PROJECT_ROOT/lib/cc-common.sh"
cc_load_version
cc_banner

BASELINE_DIR="baseline/ubuntu-26.04"
mkdir -p "$BASELINE_DIR"

cp -f /etc/skel/.bashrc "$BASELINE_DIR/bashrc.original"

if [ -f /etc/skel/.bash_aliases ]; then
    cp -f /etc/skel/.bash_aliases "$BASELINE_DIR/bash_aliases.original"
else
    : > "$BASELINE_DIR/bash_aliases.original"
fi

: > "$BASELINE_DIR/bash_functions.original"

bash --version > "$BASELINE_DIR/shell-version.txt"
{
    echo "Date: $(date)"
    echo "Kernel: $(uname -r)"
    echo "OS:"
    lsb_release -a 2>/dev/null || cat /etc/os-release
} >> "$BASELINE_DIR/shell-version.txt"

apt-mark showmanual > "$BASELINE_DIR/packages.list" 2>/dev/null || true
env | sort > "$BASELINE_DIR/env.txt"

cc_log "Baseline captured in $BASELINE_DIR"
