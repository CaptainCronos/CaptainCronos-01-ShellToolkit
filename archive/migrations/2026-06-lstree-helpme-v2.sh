#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : patch-lstree-helpme.sh
# Version     : reads VERSION
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Patch bash_functions with cleaned lstree and expanded helpme.
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT"

source "$PROJECT_ROOT/lib/cc-common.sh"

case "${1:-}" in
    --help|-h)
        echo "Usage: tools/patch-lstree-helpme.sh"
        echo
        echo "Updates bash/bash_functions with lstree v2 behavior and expanded helpme sections."
        exit 0
        ;;
    --version)
        cc_version
        exit 0
        ;;
esac

cc_banner

TARGET="bash/bash_functions"
BACKUP="${TARGET}.pre-lstree-helpme.$(date +%Y%m%d-%H%M%S).bak"

cc_require_file "$TARGET"
cp -f "$TARGET" "$BACKUP"
cc_log "Backup created: $BACKUP"

python3 - <<'PY'
from pathlib import Path

path = Path("bash/bash_functions")
text = path.read_text()

new_lstree = r'''# @name lstree
# @group Filesystem
# @desc Display a clean tree view of a mounted USB drive, jump drive, repository, or directory.
# @usage lstree [--all|--git|--depth N|--dirs|--help] [drive-label-or-path]
# @example lstree
# @example lstree .
# @example lstree --depth 2 .
# @example lstree --git ~/GitHub/CaptainCronos-01-ShellToolkit
# @example lstree Ventoy
lstree() {
    local root target path="" show_git="no" show_all="no" dirs_only="no" depth=""
    local tree_args ignore_pattern repo_root repo_name branch commit

    if ! command -v tree >/dev/null 2>&1; then
        echo "Missing dependency: tree"
        echo "Install with: sudo apt install tree"
        return 1
    fi

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --help|-h)
                cat <<'EOF_HELP'
lstree v2
=========

Usage:
  lstree [options] [drive-label-or-path]

Options:
  --all           Show all hidden files. Default still hides noisy development/cache files.
  --git           Include .git and .github directories.
  --depth N       Limit tree depth.
  --dirs          Show directories only.
  --help, -h      Show this help.

Examples:
  lstree
  lstree .
  lstree --depth 2 .
  lstree --git ~/GitHub/CaptainCronos-01-ShellToolkit
  lstree Ventoy

Default exclusions:
  .git, .github, __pycache__, .pytest_cache, node_modules, .cache,
  *.pyc, *.pyo, *.swp, *~, .DS_Store, Thumbs.db
EOF_HELP
                return 0
                ;;
            --git)
                show_git="yes"
                shift
                ;;
            --all)
                show_all="yes"
                shift
                ;;
            --dirs)
                dirs_only="yes"
                shift
                ;;
            --depth|-L)
                shift
                if [ -z "${1:-}" ]; then
                    echo "Usage: lstree --depth <number> [path]"
                    return 1
                fi
                depth="$1"
                shift
                ;;
            --)
                shift
                break
                ;;
            -* )
                echo "Unknown option: $1"
                echo "Try: lstree --help"
                return 1
                ;;
            *)
                path="$1"
                shift
                ;;
        esac
    done

    if [ -z "$path" ] && [ "$#" -gt 0 ]; then
        path="$1"
    fi

    tree_args=(-C -h --dirsfirst)
    [ "$show_all" = "yes" ] && tree_args=(-a "${tree_args[@]}")
    [ "$dirs_only" = "yes" ] && tree_args=("${tree_args[@]}" -d)
    [ -n "$depth" ] && tree_args=("${tree_args[@]}" -L "$depth")

    ignore_pattern='__pycache__|.pytest_cache|*.pyc|*.pyo|*.swp|*~|node_modules|.cache|.DS_Store|Thumbs.db'
    if [ "$show_git" != "yes" ]; then
        ignore_pattern=".git|.github|$ignore_pattern"
    fi
    tree_args=("${tree_args[@]}" -I "$ignore_pattern")

    _lstree_one() {
        local p="$1"

        if [ -d "$p/.git" ] && command -v git >/dev/null 2>&1; then
            repo_root="$(cd "$p" && git rev-parse --show-toplevel 2>/dev/null || true)"
            if [ -n "$repo_root" ]; then
                repo_name="$(basename "$repo_root")"
                branch="$(cd "$repo_root" && git branch --show-current 2>/dev/null || true)"
                commit="$(cd "$repo_root" && git rev-parse --short HEAD 2>/dev/null || true)"
                echo "Captain Cronos Repository Tree"
                echo "=============================="
                echo "Repository : $repo_name"
                echo "Branch     : ${branch:-unknown}"
                echo "Commit     : ${commit:-none}"
                echo
            fi
        fi

        tree "${tree_args[@]}" "$p"
    }

    if [ -z "$path" ]; then
        for root in "/media/$USER" "/run/media/$USER"; do
            [ -d "$root" ] && _lstree_one "$root"
        done
        return
    fi

    if [ -d "$path" ]; then
        _lstree_one "$path"
        return
    fi

    for root in "/media/$USER" "/run/media/$USER"; do
        target="$root/$path"
        if [ -d "$target" ]; then
            _lstree_one "$target"
            return
        fi
    done

    echo "Drive or directory not found: $path"
    return 1
}
'''

new_helpme = r'''# @name helpme
# @group Shell
# @desc Show Captain Cronos Toolkit help, command details, search results, engineering tools, docs, standards, or stats.
# @usage helpme [command|search <term>|stats|aliases|functions|github|engineering|install|docs|standards|version]
# @example helpme
# @example helpme lstree
# @example helpme engineering
# @example helpme search backup
# @example helpme stats
# @example helpme version
helpme() {
    local cmd term repo version_file

    _cc_help_version() {
        repo="${CAPTAIN_CRONOS_REPO:-$HOME/GitHub/CaptainCronos-01-ShellToolkit}"
        version_file="$repo/VERSION"
        if [ -f "$version_file" ]; then
            # shellcheck disable=SC1090
            . "$version_file"
        fi
        echo "Captain Cronos Shell Toolkit"
        echo "Version : ${TOOLKIT_VERSION:-unknown}"
        echo "Codename: ${TOOLKIT_CODENAME:-unknown}"
        echo
    }

    _cc_help_engineering() {
        echo "Engineering Commands"
        echo "--------------------"
        printf "%-22s %s\n" "cc-version" "Display toolkit version information."
        printf "%-22s %s\n" "cc-doctor" "Run repository health checks."
        printf "%-22s %s\n" "install/verify.sh" "Verify repository structure and Bash syntax."
        printf "%-22s %s\n" "install/update.sh" "Pull latest changes and reinstall toolkit."
        printf "%-22s %s\n" "install/create-baseline.sh" "Capture operating-system baseline shell files."
        printf "%-22s %s\n" "install/promote-defaults.sh" "Promote active bash files to defaults/v1."
    }

    _cc_help_docs() {
        echo "Documentation"
        echo "-------------"
        printf "%-28s %s\n" "docs/user/" "User documentation."
        printf "%-28s %s\n" "docs/developer/" "Developer documentation and standards."
        printf "%-28s %s\n" "README.md" "Project overview."
        printf "%-28s %s\n" "ROADMAP.md" "Project roadmap."
        printf "%-28s %s\n" "CHANGELOG.md" "Change history."
    }

    _cc_help_standards() {
        echo "Standards"
        echo "---------"
        printf "%-16s %s\n" "CC-STD-001" "Script Header Standard"
        echo
        echo "Standards location: docs/developer/"
    }

    case "${1:-}" in
        ""|list)
            _cc_help_version
            echo "ALIASES"
            echo "-------"
            _cc_alias_table | awk -F '\t' '{ printf "%-16s %s\n", $1, $2 }'
            echo
            echo "FUNCTIONS"
            echo "---------"
            _cc_function_table | awk -F '\t' '{ printf "%-16s %-12s %s\n", $2, $1, $3 }'
            echo
            _cc_help_engineering
            echo
            echo "Usage:"
            echo "  helpme"
            echo "  helpme <command>"
            echo "  helpme search <term>"
            echo "  helpme engineering"
            echo "  helpme install"
            echo "  helpme docs"
            echo "  helpme standards"
            echo "  helpme stats"
            echo "  helpme version"
            echo "  helpme github"
            ;;
        version|--version)
            _cc_help_version
            ;;
        engineering|engineer|dev)
            _cc_help_version
            _cc_help_engineering
            ;;
        install|installer|update)
            _cc_help_version
            echo "Install / Update Commands"
            echo "-------------------------"
            printf "%-28s %s\n" "install/install.sh" "Install shell toolkit files."
            printf "%-28s %s\n" "install/update.sh" "Pull latest changes and reinstall."
            printf "%-28s %s\n" "install/verify.sh" "Verify structure and syntax."
            printf "%-28s %s\n" "install/create-baseline.sh" "Capture OS baseline files."
            printf "%-28s %s\n" "install/promote-defaults.sh" "Promote bash files to deployable defaults."
            ;;
        docs|documentation)
            _cc_help_version
            _cc_help_docs
            ;;
        standards|standard)
            _cc_help_version
            _cc_help_standards
            ;;
        github|git|workflow|gitflow)
            _cc_gitflow_help
            ;;
        aliases)
            _cc_alias_table | awk -F '\t' '{ printf "%-16s %s\n", $1, $2 }'
            ;;
        functions)
            _cc_function_table | awk -F '\t' '{ printf "%-16s %-12s %s\n", $2, $1, $3 }'
            ;;
        search)
            shift
            term="$*"
            if [ -z "$term" ]; then
                echo "Usage: helpme search <term>"
                return 1
            fi
            echo "Search results for: $term"
            echo "------------------------"
            {
                _cc_alias_table | awk -F '\t' '{ print "alias\t" $1 "\t" $2 }'
                _cc_function_table | awk -F '\t' '{ print "function\t" $2 "\t" $3 }'
                _cc_help_engineering | awk 'NF { print "engineering\t" $1 "\t" substr($0, index($0,$2)) }'
            } | awk -F '\t' -v q="$term" 'BEGIN{IGNORECASE=1} $0 ~ q { printf "%-12s %-22s %s\n", $1, $2, $3 }'
            ;;
        stats)
            _cc_help_version
            echo "Toolkit Statistics"
            echo "=================="
            printf "Aliases       : %s\n" "$(_cc_alias_names | wc -l)"
            printf "Functions     : %s\n" "$(_cc_function_names | wc -l)"
            printf "Function file : %s\n" "$(_cc_meta_file)"
            printf "Alias file    : %s\n" "$(_cc_alias_file)"
            ;;
        *)
            cmd="$1"
            if _cc_command_help "$cmd"; then
                return 0
            fi
            if _cc_alias_help "$cmd"; then
                return 0
            fi
            echo "No help entry for: $cmd"
            echo "Try: helpme search $cmd"
            return 1
            ;;
    esac
}
'''

start = text.index('# @name lstree')
end = text.index('# =============================\n# GIT / GITHUB HELPERS', start)
text = text[:start] + new_lstree + '\n' + text[end:]

start = text.index('# @name helpme')
text = text[:start] + new_helpme

path.write_text(text)
PY

bash -n "$TARGET"
cc_log "Patched $TARGET"
cc_log "Run: git diff -- bash/bash_functions"
