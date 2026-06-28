#!/usr/bin/env bash
#
# Captain Cronos Shell Toolkit Installer

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT"

BACKUP_DIR="$HOME/.captaincronos/backups/$(date +%Y%m%d-%H%M%S)"

echo "Captain Cronos Shell Toolkit Installer"
echo "Project root: $PROJECT_ROOT"
echo "Backup dir  : $BACKUP_DIR"
echo

mkdir -p "$BACKUP_DIR"

require_file() {
    if [[ ! -f "$1" ]]; then
        echo "ERROR: Required file missing: $1"
        exit 1
    fi
}

install_file() {
    local src="$1"
    local dest="$2"

    require_file "$src"

    if [[ -f "$dest" ]]; then
        cp -f "$dest" "$BACKUP_DIR/$(basename "$dest")"
        echo "Backed up: $dest"
    fi

    cp -f "$src" "$dest"
    echo "Installed: $src -> $dest"
}

echo "Checking Bash files..."
require_file bash/bash_aliases
require_file bash/bash_functions

bash -n bash/bash_aliases
bash -n bash/bash_functions

if [[ -f bash/bashrc ]]; then
    bash -n bash/bashrc
fi

echo "Syntax OK"
echo

install_file bash/bash_aliases "$HOME/.bash_aliases"
install_file bash/bash_functions "$HOME/.bash_functions"

if [[ -f bash/bashrc ]]; then
    install_file bash/bashrc "$HOME/.bashrc"
else
    if ! grep -q "Captain Cronos Shell Toolkit" "$HOME/.bashrc" 2>/dev/null; then
        cp -f "$HOME/.bashrc" "$BACKUP_DIR/bashrc"
        cat >> "$HOME/.bashrc" <<'EOF'

# Captain Cronos Shell Toolkit
if [ -f "$HOME/.bash_aliases" ]; then
    source "$HOME/.bash_aliases"
fi

if [ -f "$HOME/.bash_functions" ]; then
    source "$HOME/.bash_functions"
fi
EOF
        echo "Updated: $HOME/.bashrc"
    fi
fi

echo
echo "Install complete."
echo "Backup saved in: $BACKUP_DIR"
echo
echo "Reload with:"
echo "  source ~/.bashrc"
