#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : install.sh
# Version     : reads VERSION
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Install Captain Cronos shell files and command front-end.
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT"

source "$PROJECT_ROOT/lib/cc-common.sh"

INSTALL_VERSION="2.1.0-alpha1"
BACKUP_ROOT="$HOME/.captaincronos/backups"
BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
USER_BIN="$HOME/bin"
DRY_RUN="no"
SKIP_BACKUP="no"
SKIP_BASELINE="no"
INSTALL_BASHRC="yes"
INSTALL_COMMANDS="yes"

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
  --no-commands      Do not install command front-end into ~/bin.
  --help, -h         Show this help.
  --version          Show installer and toolkit version.

What it does:
  1. Loads VERSION from the repository.
  2. Verifies required repository files.
  3. Verifies Bash syntax.
  4. Optionally captures baseline OS shell files.
  5. Backs up current ~/.bashrc, ~/.bash_aliases, and ~/.bash_functions.
  6. Installs bash/bashrc, bash/bash_aliases, and bash/bash_functions.
  7. Installs the cc command front-end into ~/bin.
  8. Verifies installed files.
  9. Prints a final install report.
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
        --no-commands)
            INSTALL_COMMANDS="no"
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
    local mode="${3:-0644}"

    cc_require_file "$src"

    if [ "$DRY_RUN" = "yes" ]; then
        cc_log "DRY RUN: would install $src -> $dest mode $mode"
        return 0
    fi

    install -m "$mode" "$src" "$dest"
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

ensure_user_bin() {
    if [ "$INSTALL_COMMANDS" != "yes" ]; then
        return 0
    fi

    if [ "$DRY_RUN" = "yes" ]; then
        cc_log "DRY RUN: would ensure command directory exists: $USER_BIN"
        return 0
    fi

    mkdir -p "$USER_BIN"
}

verify_bash_sources() {
    cc_require_file bash/bash_aliases
    cc_require_file bash/bash_functions
    cc_require_file bash/bashrc
    cc_require_file tools/cc

    bash -n bash/bash_aliases
    bash -n bash/bash_functions
    bash -n bash/bashrc
    bash -n tools/cc
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

    if [ "$INSTALL_COMMANDS" = "yes" ]; then
        [ -x "$HOME/bin/cc" ] || { cc_error "Missing installed command: ~/bin/cc"; return 1; }
        "$HOME/bin/cc" version >/dev/null
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

print_path_note() {
    case ":$PATH:" in
        *":$HOME/bin:"*) return 0 ;;
        *)
            echo
            echo "PATH note:"
            echo "  ~/bin is not currently in PATH. Add this to ~/.bashrc if needed:"
            echo '  export PATH="$HOME/bin:$PATH"'
            ;;
    esac
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
    printf '%-18s %s\n' "Install commands:" "$INSTALL_COMMANDS"
    echo
    echo "Reload with:"
    echo "  source ~/.bashrc"
    echo
    echo "Verify with:"
    echo "  cc version"
    echo "  cc repo"
    echo "  cc doctor"
    echo "  helpme engineering"
    echo "  lstree --depth 2 ."
}

cc_load_version
cc_banner

cc_log "Starting installer v$INSTALL_VERSION"

cc_log "Verifying repository framework..."
install/verify.sh

cc_log "Verifying Bash source files and command front-end..."
verify_bash_sources

capture_baseline_if_needed

cc_log "Preparing backups..."
backup_file "$HOME/.bashrc"
backup_file "$HOME/.bash_aliases"
backup_file "$HOME/.bash_functions"
backup_file "$HOME/bin/cc"

cc_log "Installing shell files..."
install_copy bash/bash_aliases "$HOME/.bash_aliases" 0644
install_copy bash/bash_functions "$HOME/.bash_functions" 0644

if [ "$INSTALL_BASHRC" = "yes" ]; then
    install_copy bash/bashrc "$HOME/.bashrc" 0644
else
    cc_log "Skipping ~/.bashrc install by request."
fi

if [ "$INSTALL_COMMANDS" = "yes" ]; then
    cc_log "Installing command front-end..."
    ensure_user_bin
    install_copy tools/cc "$HOME/bin/cc" 0755
else
    cc_log "Skipping command front-end install by request."
fi

if [ "$DRY_RUN" != "yes" ]; then
    cc_log "Verifying installed shell files and command front-end..."
    verify_installed_files
fi

cc_log "Install complete."
print_report
print_path_note
