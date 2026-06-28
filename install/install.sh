#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : install.sh
# Version     : reads VERSION
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Install Captain Cronos shell files with verification and backup.
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT"

source "$PROJECT_ROOT/lib/cc-common.sh"

INSTALL_VERSION="2.0.0-alpha1"
BACKUP_ROOT="$HOME/.captaincronos/backups"
BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
DRY_RUN="no"
SKIP_BACKUP="no"
SKIP_BASELINE="no"
INSTALL_BASHRC="yes"

show_help() {
    cat <<'EOF_HELP'
Captain Cronos Shell Toolkit Installer
======================================

Usage:
  install/install.sh [options]

Options:
  --dry-run          Show what would be done without copying files.
  --no-backup        Do not create timestamped backups before installing.
  --no-baseline      Do not create baseline files if baseline appears empty.
  --no-bashrc        Install aliases/functions only; do not replace ~/.bashrc.
  --help, -h         Show this help.
  --version          Show installer and toolkit version.

What it does:
  1. Loads VERSION from the repository.
  2. Verifies required repository files.
  3. Verifies Bash syntax.
  4. Optionally captures baseline OS shell files.
  5. Backs up current ~/.bashrc, ~/.bash_aliases, and ~/.bash_functions.
  6. Installs bash/bashrc, bash/bash_aliases, and bash/bash_functions.
  7. Verifies installed files.
  8. Prints a final install report.
EOF_HELP
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN="yes"
            shift
            ;;
        --no-backup)
            SKIP_BACKUP="yes"
            shift
            ;;
        --no-baseline)
            SKIP_BASELINE="yes"
            shift
            ;;
        --no-bashrc)
            INSTALL_BASHRC="no"
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        --version)
            echo "install.sh $INSTALL_VERSION"
            cc_version
            exit 0
            ;;
        *)
            cc_error "Unknown option: $1"
            echo "Try: install/install.sh --help"
            exit 1
            ;;
    esac
done

install_copy() {
    local src="$1"
    local dest="$2"

    cc_require_file "$src"

    if [ "$DRY_RUN" = "yes" ]; then
        cc_log "DRY RUN: would install $src -> $dest"
        return 0
    fi

    install -m 0644 "$src" "$dest"
    cc_log "Installed: $src -> $dest"
}

backup_file() {
    local src="$1"

    if [ "$SKIP_BACKUP" = "yes" ]; then
        return 0
    fi

    if [ -f "$src" ]; then
        mkdir -p "$BACKUP_DIR"
        cp -f "$src" "$BACKUP_DIR/$(basename "$src")"
        cc_log "Backed up: $src"
    fi
}

verify_bash_sources() {
    cc_require_file bash/bash_aliases
    cc_require_file bash/bash_functions
    cc_require_file bash/bashrc

    bash -n bash/bash_aliases
    bash -n bash/bash_functions
    bash -n bash/bashrc
}

verify_installed_files() {
    [ -f "$HOME/.bash_aliases" ] || { cc_error "Missing installed file: ~/.bash_aliases"; return 1; }
    [ -f "$HOME/.bash_functions" ] || { cc_error "Missing installed file: ~/.bash_functions"; return 1; }

    bash -n "$HOME/.bash_aliases"
    bash -n "$HOME/.bash_functions"

    if [ "$INSTALL_BASHRC" = "yes" ]; then
        [ -f "$HOME/.bashrc" ] || { cc_error "Missing installed file: ~/.bashrc"; return 1; }
        bash -n "$HOME/.bashrc"
    fi
}

capture_baseline_if_needed() {
    local baseline_file="baseline/ubuntu-26.04/bashrc.original"

    if [ "$SKIP_BASELINE" = "yes" ]; then
        return 0
    fi

    if [ ! -s "$baseline_file" ]; then
        if [ "$DRY_RUN" = "yes" ]; then
            cc_log "DRY RUN: would capture baseline with install/create-baseline.sh"
        else
            cc_log "Baseline appears empty. Capturing baseline."
            install/create-baseline.sh
        fi
    fi
}

print_report() {
    echo
    echo "Install Report"
    echo "=============="
    printf '%-18s %s\n' "Project root:" "$PROJECT_ROOT"
    printf '%-18s %s\n' "Toolkit:" "${TOOLKIT_VERSION:-unknown}"
    printf '%-18s %s\n' "Codename:" "${TOOLKIT_CODENAME:-unknown}"
    printf '%-18s %s\n' "Installer:" "$INSTALL_VERSION"
    printf '%-18s %s\n' "Backup dir:" "$([ "$SKIP_BACKUP" = "yes" ] && echo "skipped" || echo "$BACKUP_DIR")"
    printf '%-18s %s\n' "Dry run:" "$DRY_RUN"
    printf '%-18s %s\n' "Install bashrc:" "$INSTALL_BASHRC"
    echo
    echo "Reload with:"
    echo "  source ~/.bashrc"
    echo
    echo "Verify with:"
    echo "  helpme version"
    echo "  helpme engineering"
    echo "  lstree --depth 2 ."
}

cc_load_version
cc_banner

cc_log "Starting installer v$INSTALL_VERSION"

cc_log "Verifying repository framework..."
install/verify.sh

cc_log "Verifying Bash source files..."
verify_bash_sources

capture_baseline_if_needed

cc_log "Preparing backups..."
backup_file "$HOME/.bashrc"
backup_file "$HOME/.bash_aliases"
backup_file "$HOME/.bash_functions"

cc_log "Installing shell files..."
install_copy bash/bash_aliases "$HOME/.bash_aliases"
install_copy bash/bash_functions "$HOME/.bash_functions"

if [ "$INSTALL_BASHRC" = "yes" ]; then
    install_copy bash/bashrc "$HOME/.bashrc"
else
    cc_log "Skipping ~/.bashrc install by request."
fi

if [ "$DRY_RUN" != "yes" ]; then
    cc_log "Verifying installed shell files..."
    verify_installed_files
fi

cc_log "Install complete."
print_report
