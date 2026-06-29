#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-metadata.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Shared command metadata and registry helpers.
# ==============================================================================

cc_command_dir() {
    echo "$PROJECT_ROOT/tools/commands"
}

cc_command_list() {
    find "$(cc_command_dir)" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort
}

cc_metadata_field() {
    local file="$1"
    local field="$2"
    awk -v field="$field" '
        $0 ~ "^# " field "[[:space:]]*:" {
            sub("^# " field "[[:space:]]*:[[:space:]]*", "")
            print
            exit
        }
    ' "$file"
}

cc_command_file() {
    echo "$(cc_command_dir)/$1"
}

cc_infer_category() {
    case "$1" in
        config|registry|version|install|toolkit-update) echo "Core" ;;
        docs|helpme-refresh) echo "Documentation" ;;
        release|baseline|defaults) echo "Engineering" ;;
        repo|repos|gitflow|status) echo "Repository" ;;
        verify|doctor) echo "Diagnostics" ;;
        drives|smart|kernel-cleanup) echo "Storage" ;;
        system-update|update|monthly-health|monthly-health-timer) echo "Maintenance" ;;
        *) echo "General" ;;
    esac
}

cc_command_metadata() {
    local cmd="$1"
    local file category requires script version purpose repository
    file="$(cc_command_file "$cmd")"
    script="$(cc_metadata_field "$file" "Script")"
    version="$(cc_metadata_field "$file" "Version")"
    purpose="$(cc_metadata_field "$file" "Purpose")"
    category="$(cc_metadata_field "$file" "Category")"
    requires="$(cc_metadata_field "$file" "Requires")"
    repository="$(cc_metadata_field "$file" "Repository")"

    [ -n "$script" ] || script="$cmd"
    [ -n "$version" ] || version="unknown"
    [ -n "$purpose" ] || purpose="unknown"
    [ -n "$category" ] || category="$(cc_infer_category "$cmd")"
    [ -n "$requires" ] || requires="bash"
    [ -n "$repository" ] || repository="CaptainCronos-01-ShellToolkit"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$cmd" "$script" "$version" "$category" "$requires" "$repository" "$purpose"
}

cc_registry_tsv() {
    local cmd
    while read -r cmd; do
        [ -n "$cmd" ] || continue
        cc_command_metadata "$cmd"
    done < <(cc_command_list)
}

cc_registry_markdown() {
    echo "| Command | Version | Category | Requires | Purpose |"
    echo "|---|---|---|---|---|"
    cc_registry_tsv | while IFS=$'\t' read -r cmd script version category requires repository purpose; do
        echo "| cc $cmd | $version | $category | $requires | $purpose |"
    done
}
