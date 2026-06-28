#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Project Scaffold
# ==============================================================================
# Creates the standard directory structure for a Captain Cronos repository.
#
# Usage:
#   ./create-project-structure.sh
#
# ==============================================================================

set -e

echo
echo "========================================="
echo " Captain Cronos Project Scaffold"
echo "========================================="
echo

# ----------------------------------------------------------------------
# Create directory structure
# ----------------------------------------------------------------------

mkdir -p \
    assets/images \
    bash \
    docs \
    examples \
    install \
    scripts \
    tests \
    archive

# ----------------------------------------------------------------------
# Create standard project files if they do not already exist
# ----------------------------------------------------------------------

touch README.md
touch CHANGELOG.md
touch ROADMAP.md
touch LICENSE
touch .gitignore

# ----------------------------------------------------------------------
# Documentation
# ----------------------------------------------------------------------

touch docs/Installation.md
touch docs/Commands.md
touch docs/GitAssistant.md
touch docs/Examples.md
touch docs/Troubleshooting.md
touch docs/ReleaseNotes.md

# ----------------------------------------------------------------------
# Bash toolkit
# ----------------------------------------------------------------------

touch bash/bashrc
touch bash/bash_aliases
touch bash/bash_functions

# ----------------------------------------------------------------------
# Installation
# ----------------------------------------------------------------------

touch install/install.sh
touch install/update.sh
touch install/uninstall.sh

chmod +x install/*.sh

# ----------------------------------------------------------------------
# Examples
# ----------------------------------------------------------------------

touch examples/README.md

# ----------------------------------------------------------------------
# Scripts
# ----------------------------------------------------------------------

touch scripts/README.md

# ----------------------------------------------------------------------
# Tests
# ----------------------------------------------------------------------

touch tests/README.md

# ----------------------------------------------------------------------
# Assets
# ----------------------------------------------------------------------

touch assets/README.md
touch assets/images/README.md

# ----------------------------------------------------------------------
# Archive
# ----------------------------------------------------------------------

touch archive/README.md

echo
echo "Repository structure created successfully."
echo

tree -a -C -h --dirsfirst .
