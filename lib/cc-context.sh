#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-context.sh
# Version     : reads VERSION
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Shared toolkit and repository context helpers.
# ==============================================================================

# Consumed by other libraries after this file is sourced.
# shellcheck disable=SC2034
CC_CONTEXT_LOADED=1

cc_context_default_toolkit_root() {
    echo "${CAPTAIN_CRONOS_DEFAULT_TOOLKIT_ROOT:-$HOME/GitHub/CaptainCronos-01-ShellToolkit}"
}

cc_context_canonical_dir() {
    local path="$1"
    [ -d "$path" ] || return 1
    (cd "$path" && pwd -P)
}

cc_context_is_toolkit_root() {
    local root="${1:-}"
    [ -n "$root" ] &&
        [ -f "$root/lib/cc-context.sh" ] &&
        [ -f "$root/lib/cc-common.sh" ] &&
        [ -f "$root/tools/cc" ] &&
        [ -d "$root/tools/commands" ]
}

cc_context_resolve_toolkit_root() {
    local raw candidate git_root

    git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"

    for raw in \
        "${1:-}" \
        "${TOOLKIT_ROOT:-}" \
        "${CAPTAIN_CRONOS_TOOLKIT_ROOT:-}" \
        "${CAPTAIN_CRONOS_REPO:-}" \
        "${PROJECT_ROOT:-}" \
        "$git_root" \
        "$(cc_context_default_toolkit_root)"
    do
        [ -n "$raw" ] || continue
        candidate="$(cc_context_canonical_dir "$raw" 2>/dev/null || true)"
        if cc_context_is_toolkit_root "$candidate"; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

cc_context_resolve_current_repo() {
    local start="${1:-${CURRENT_REPO:-${PWD:-}}}" root

    [ -n "$start" ] || start="$(pwd)"

    if [ -d "$start" ]; then
        root="$(git -C "$start" rev-parse --show-toplevel 2>/dev/null || true)"
        if [ -n "$root" ]; then
            cc_context_canonical_dir "$root"
            return 0
        fi

        cc_context_canonical_dir "$start"
        return 0
    fi

    pwd -P
}

cc_context_init() {
    local toolkit_arg="${1:-}" current_arg="${2:-}" root current

    root="$(cc_context_resolve_toolkit_root "$toolkit_arg")" || return 1
    current="$(cc_context_resolve_current_repo "$current_arg")" || current="$root"

    TOOLKIT_ROOT="$root"
    CURRENT_REPO="$current"

    # Backwards compatibility for existing commands that still read PROJECT_ROOT.
    PROJECT_ROOT="$TOOLKIT_ROOT"

    export TOOLKIT_ROOT CURRENT_REPO PROJECT_ROOT
}

cc_toolkit_root() {
    if [ -n "${TOOLKIT_ROOT:-}" ]; then
        echo "$TOOLKIT_ROOT"
        return 0
    fi

    cc_context_resolve_toolkit_root
}

cc_current_repo() {
    if [ -n "${CURRENT_REPO:-}" ]; then
        echo "$CURRENT_REPO"
        return 0
    fi

    cc_context_resolve_current_repo
}

cc_repo_root() {
    cc_current_repo
}

cc_repo_exists() {
    local repo="${1:-$(cc_current_repo 2>/dev/null || true)}"
    [ -n "$repo" ] && [ -d "$repo" ]
}

cc_repo_is_git() {
    local repo="${1:-$(cc_current_repo 2>/dev/null || true)}"
    [ -n "$repo" ] && git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

cc_repo_name() {
    local repo="${1:-$(cc_current_repo 2>/dev/null || true)}" canonical
    [ -n "$repo" ] || return 1
    canonical="$(cc_context_canonical_dir "$repo" 2>/dev/null || echo "$repo")"
    basename "$canonical"
}

cc_repo_branch() {
    local repo="${1:-$(cc_current_repo 2>/dev/null || true)}" branch
    cc_repo_is_git "$repo" || return 1

    branch="$(git -C "$repo" branch --show-current 2>/dev/null || true)"
    [ -n "$branch" ] || branch="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || true)"
    [ -n "$branch" ] || return 1
    echo "$branch"
}

cc_repo_head_display() {
    local repo="${1:-$(cc_current_repo 2>/dev/null || true)}" branch commit
    cc_repo_is_git "$repo" || return 1

    branch="$(git -C "$repo" branch --show-current 2>/dev/null || true)"
    if [ -n "$branch" ]; then
        echo "$branch"
        return 0
    fi

    commit="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || true)"
    [ -n "$commit" ] || return 1
    echo "detached at $commit"
}

cc_repo_remote() {
    local repo="${1:-$(cc_current_repo 2>/dev/null || true)}" remote="${2:-origin}"
    cc_repo_is_git "$repo" || return 1
    git -C "$repo" remote get-url "$remote" 2>/dev/null
}

cc_repo_clean() {
    local repo="${1:-$(cc_current_repo 2>/dev/null || true)}"
    cc_repo_is_git "$repo" || return 1
    [ -z "$(git -C "$repo" status --short 2>/dev/null)" ]
}

cc_repo_status_short() {
    local repo="${1:-$(cc_current_repo 2>/dev/null || true)}"
    cc_repo_is_git "$repo" || return 1
    git -C "$repo" status --short 2>/dev/null
}

cc_repo_default_branch() {
    local repo="${1:-$(cc_current_repo 2>/dev/null || true)}" remote="${2:-origin}" ref branch
    cc_repo_is_git "$repo" || return 1

    ref="$(git -C "$repo" symbolic-ref --quiet --short "refs/remotes/$remote/HEAD" 2>/dev/null || true)"
    if [ -n "$ref" ]; then
        echo "${ref#"$remote/"}"
        return 0
    fi

    for branch in main master; do
        if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
            echo "$branch"
            return 0
        fi
    done

    cc_repo_branch "$repo" 2>/dev/null || echo main
}
