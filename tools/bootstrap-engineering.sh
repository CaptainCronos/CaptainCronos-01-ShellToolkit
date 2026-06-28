#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : bootstrap-engineering.sh
# Version     : reads VERSION
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Establish shared engineering framework, versioning, and standards.
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT"

mkdir -p lib install baseline/ubuntu-26.04 defaults/v1 docs/developer docs/user install/manifests

cat > VERSION <<'EOF'
TOOLKIT_VERSION="1.0.0-alpha1"
TOOLKIT_CODENAME="Blackbeard"
STANDARDS_VERSION="0.1.0"
BASELINE_VERSION="ubuntu-26.04"
RELEASE_DATE="2026-06-28"
EOF

cat > manifest.yml <<'EOF'
project:
  name: Captain Cronos Shell Toolkit
  repository: CaptainCronos-01-ShellToolkit
  status: alpha

version:
  source: VERSION

paths:
  bashrc: bash/bashrc
  aliases: bash/bash_aliases
  functions: bash/bash_functions
  baseline: baseline/ubuntu-26.04
  defaults: defaults/v1
  backups: ~/.captaincronos/backups

standards:
  script_header: CC-STD-001
  repository_layout: CC-STD-002
EOF

cat > lib/cc-common.sh <<'EOF'
#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-common.sh
# Version     : reads VERSION
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Shared library for Captain Cronos scripts.
# ==============================================================================

cc_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null || pwd
}

cc_load_version() {
    local root
    root="$(cc_repo_root)"
    if [ -f "$root/VERSION" ]; then
        # shellcheck disable=SC1091
        source "$root/VERSION"
    fi
}

cc_banner() {
    cc_load_version
    echo "Captain Cronos Shell Toolkit"
    echo "Version : ${TOOLKIT_VERSION:-unknown}"
    echo "Codename: ${TOOLKIT_CODENAME:-unknown}"
    echo
}

cc_version() {
    cc_load_version
    echo "Toolkit : ${TOOLKIT_VERSION:-unknown}"
    echo "Codename: ${TOOLKIT_CODENAME:-unknown}"
    echo "Standard: ${STANDARDS_VERSION:-unknown}"
    echo "Baseline: ${BASELINE_VERSION:-unknown}"
    echo "Release : ${RELEASE_DATE:-unknown}"
}

cc_log() {
    echo "[CC] $*"
}

cc_warn() {
    echo "[CC WARN] $*" >&2
}

cc_error() {
    echo "[CC ERROR] $*" >&2
}

cc_require_file() {
    if [ ! -f "$1" ]; then
        cc_error "Missing required file: $1"
        return 1
    fi
}

cc_require_dir() {
    if [ ! -d "$1" ]; then
        cc_error "Missing required directory: $1"
        return 1
    fi
}
EOF

cat > install/verify.sh <<'EOF'
#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : verify.sh
# Version     : reads VERSION
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Verify repository structure and shell syntax.
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT"

source "$PROJECT_ROOT/lib/cc-common.sh"

case "${1:-}" in
    --help|-h)
        echo "Usage: install/verify.sh"
        exit 0
        ;;
    --version)
        cc_version
        exit 0
        ;;
esac

cc_banner

for d in bash install lib baseline/ubuntu-26.04 defaults/v1 docs; do
    cc_require_dir "$d"
done

for f in VERSION manifest.yml lib/cc-common.sh bash/bashrc bash/bash_aliases bash/bash_functions install/install.sh; do
    cc_require_file "$f"
done

bash -n lib/cc-common.sh
bash -n bash/bashrc
bash -n bash/bash_aliases
bash -n bash/bash_functions
bash -n install/install.sh

cc_log "Verification passed."
EOF

cat > install/create-baseline.sh <<'EOF'
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
EOF

cat > install/promote-defaults.sh <<'EOF'
#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : promote-defaults.sh
# Version     : reads VERSION
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Promote active bash files into defaults/v1.
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT"

source "$PROJECT_ROOT/lib/cc-common.sh"

case "${1:-}" in
    --help|-h)
        echo "Usage: install/promote-defaults.sh"
        exit 0
        ;;
    --version)
        cc_version
        exit 0
        ;;
esac

cc_banner

cc_require_file bash/bashrc
cc_require_file bash/bash_aliases
cc_require_file bash/bash_functions

bash -n bash/bashrc
bash -n bash/bash_aliases
bash -n bash/bash_functions

mkdir -p defaults/v1

cp -f bash/bashrc defaults/v1/bashrc
cp -f bash/bash_aliases defaults/v1/bash_aliases
cp -f bash/bash_functions defaults/v1/bash_functions

cat > defaults/v1/manifest.txt <<EOFDEF
Captain Cronos Shell Toolkit Defaults
Version: ${TOOLKIT_VERSION:-unknown}
Promoted: $(date)

Files:
  bashrc
  bash_aliases
  bash_functions
EOFDEF

cat > defaults/v1/README.md <<'EOFREADME'
# Captain Cronos Defaults v1

Approved deployable default shell configuration for Captain Cronos Shell Toolkit v1.
EOFREADME

cc_log "Defaults promoted to defaults/v1"
EOF

cat > docs/developer/CC-STD-001-Script-Header.md <<'EOF'
# CC-STD-001 — Script Header Standard

Every executable Captain Cronos script must include:

- Shebang
- Project name
- Script name
- Version source
- Repository
- Purpose
- `--help` support where practical
- `--version` support where practical

Runtime version data should come from the repository `VERSION` file.
EOF

chmod +x \
    lib/cc-common.sh \
    install/verify.sh \
    install/create-baseline.sh \
    install/promote-defaults.sh

echo
echo "Engineering framework installed."
echo
git status --short