#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-plugins.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash find sort stat
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Discover and validate local data-only plugin manifests safely.
# ==============================================================================

if ! declare -F cc_dep_execution_status >/dev/null 2>&1; then
    _cc_plugins_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_plugins_lib_dir/cc-deps.sh"
    unset _cc_plugins_lib_dir
fi
if ! declare -F cc_platform_type >/dev/null 2>&1; then
    _cc_plugins_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_plugins_lib_dir/cc-platform.sh"
    unset _cc_plugins_lib_dir
fi
if ! declare -F cc_config_host_home >/dev/null 2>&1; then
    _cc_plugins_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_plugins_lib_dir/cc-config.sh"
    unset _cc_plugins_lib_dir
fi

CC_PLUGIN_API_VERSION=1

cc_plugin_repository_root() {
    local lib_dir root
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    root="${TOOLKIT_ROOT:-${PROJECT_ROOT:-${lib_dir}/..}}"
    printf '%s/plugins\n' "$root"
}

cc_plugin_host_root() {
    printf '%s/plugins\n' "${CC_HOST_HOME:-$(cc_config_host_home)}"
}

_cc_plugin_safe_token() {
    [[ "$1" =~ ^[a-z0-9][a-z0-9._-]*$ ]]
}

_cc_plugin_safe_list() {
    local value="$1" item
    [ -z "$value" ] && return 0
    IFS=',' read -r -a _cc_plugin_items <<< "$value"
    for item in "${_cc_plugin_items[@]}"; do
        _cc_plugin_safe_token "$item" || return 1
    done
}

_cc_plugin_relative_path_safe() {
    local path="$1" remainder component
    [ -n "$path" ] && [[ "$path" != /* ]] || return 1
    remainder="$path"
    while :; do
        component="${remainder%%/*}"
        [ -n "$component" ] && [ "$component" != . ] && [ "$component" != .. ] || return 1
        [[ "$component" != *$'\t'* && "$component" != *$'\n'* && "$component" != *$'\r'* ]] || return 1
        [ "$remainder" != "$component" ] || break
        remainder="${remainder#*/}"
    done
}

_cc_plugin_path_has_no_symlinks() {
    local base="$1" relative="$2"
    local probe="$base" remainder component
    [ ! -L "$base" ] || return 1
    remainder="$relative"
    while :; do
        component="${remainder%%/*}"
        probe="$probe/$component"
        [ ! -L "$probe" ] || return 1
        [ "$remainder" != "$component" ] || break
        remainder="${remainder#*/}"
    done
}

_cc_plugin_entrypoint_directories_safe() {
    local base="$1" relative="$2"
    local probe="$base" remainder component owner mode
    remainder="$relative"
    while [[ "$remainder" == */* ]]; do
        component="${remainder%%/*}"
        probe="$probe/$component"
        [ -d "$probe" ] && [ ! -L "$probe" ] || return 1
        owner="$(stat -c %u -- "$probe" 2>/dev/null)" || return 1
        mode="$(stat -c %a -- "$probe" 2>/dev/null)" || return 1
        [ "$owner" = "$EUID" ] || return 1
        (( (8#$mode & 0002) == 0 )) || return 1
        remainder="${remainder#*/}"
    done
}

_cc_plugin_owned_regular_file() {
    local file="$1" owner mode
    [ -f "$file" ] && [ ! -L "$file" ] && [ -r "$file" ] || return 1
    owner="$(stat -c %u -- "$file" 2>/dev/null)" || return 1
    mode="$(stat -c %a -- "$file" 2>/dev/null)" || return 1
    [ "$owner" = "$EUID" ] || return 1
    (( (8#$mode & 0002) == 0 ))
}

_cc_plugin_root_safe() {
    local root="$1" owner mode
    [ -d "$root" ] && [ ! -L "$root" ] && [ -r "$root" ] && [ -x "$root" ] || return 1
    _cc_config_path_lexically_safe "$root" || return 1
    _cc_config_path_has_no_symlinks "$root" || return 1
    owner="$(stat -c %u -- "$root" 2>/dev/null)" || return 1
    mode="$(stat -c %a -- "$root" 2>/dev/null)" || return 1
    [ "$owner" = "$EUID" ] || return 1
    (( (8#$mode & 0002) == 0 ))
}

_cc_plugin_parse_manifest() {
    local manifest="$1" line key value line_number=0 seen=' '
    CC_PLUGIN_PARSE_ERROR=""
    CC_PLUGIN_ID="" CC_PLUGIN_NAME="" CC_PLUGIN_VERSION="" CC_PLUGIN_DESCRIPTION=""
    CC_PLUGIN_ENTRYPOINT="" CC_PLUGIN_PROVIDES="" CC_PLUGIN_DEPENDENCIES=""
    CC_PLUGIN_OPTIONAL_DEPENDENCIES="" CC_PLUGIN_PLATFORMS="" CC_PLUGIN_ENABLED=""
    CC_PLUGIN_API=""

    _cc_plugin_owned_regular_file "$manifest" || {
        CC_PLUGIN_PARSE_ERROR="manifest must be an owner-controlled regular file"
        return 1
    }

    while IFS= read -r line || [ -n "$line" ]; do
        line_number=$((line_number + 1))
        case "$line" in ''|'#'*) continue ;; esac
        [[ "$line" != *$'\t'* && "$line" != *$'\r'* ]] || {
            CC_PLUGIN_PARSE_ERROR="invalid control character at line $line_number"
            return 1
        }
        [[ ! "$line" =~ [[:cntrl:]] ]] || {
            CC_PLUGIN_PARSE_ERROR="invalid control character at line $line_number"
            return 1
        }
        [[ "$line" =~ ^([a-z_]+)=(.*)$ ]] || {
            CC_PLUGIN_PARSE_ERROR="malformed line $line_number"
            return 1
        }
        key="${BASH_REMATCH[1]}" value="${BASH_REMATCH[2]}"
        [ -n "$value" ] || {
            CC_PLUGIN_PARSE_ERROR="empty $key at line $line_number"
            return 1
        }
        case "$seen" in *" $key "*)
            CC_PLUGIN_PARSE_ERROR="duplicate field $key"
            return 1
        esac
        seen="$seen$key "
        case "$key" in
            plugin_api) CC_PLUGIN_API="$value" ;;
            id) CC_PLUGIN_ID="$value" ;;
            name) CC_PLUGIN_NAME="$value" ;;
            version) CC_PLUGIN_VERSION="$value" ;;
            description) CC_PLUGIN_DESCRIPTION="$value" ;;
            entrypoint) CC_PLUGIN_ENTRYPOINT="$value" ;;
            provides) CC_PLUGIN_PROVIDES="$value" ;;
            dependencies) CC_PLUGIN_DEPENDENCIES="$value" ;;
            optional_dependencies) CC_PLUGIN_OPTIONAL_DEPENDENCIES="$value" ;;
            platforms) CC_PLUGIN_PLATFORMS="$value" ;;
            enabled) CC_PLUGIN_ENABLED="$value" ;;
            *)
                CC_PLUGIN_PARSE_ERROR="unknown field $key"
                return 1
                ;;
        esac
    done < "$manifest"

    for key in plugin_api id name version description entrypoint provides platforms enabled; do
        case "$key" in
            plugin_api) value="$CC_PLUGIN_API" ;;
            id) value="$CC_PLUGIN_ID" ;;
            name) value="$CC_PLUGIN_NAME" ;;
            version) value="$CC_PLUGIN_VERSION" ;;
            description) value="$CC_PLUGIN_DESCRIPTION" ;;
            entrypoint) value="$CC_PLUGIN_ENTRYPOINT" ;;
            provides) value="$CC_PLUGIN_PROVIDES" ;;
            platforms) value="$CC_PLUGIN_PLATFORMS" ;;
            enabled) value="$CC_PLUGIN_ENABLED" ;;
        esac
        [ -n "$value" ] || { CC_PLUGIN_PARSE_ERROR="missing field $key"; return 1; }
    done

    [ "$CC_PLUGIN_API" = "$CC_PLUGIN_API_VERSION" ] || {
        CC_PLUGIN_PARSE_ERROR="unsupported plugin_api $CC_PLUGIN_API"
        return 1
    }
    _cc_plugin_safe_token "$CC_PLUGIN_ID" || { CC_PLUGIN_PARSE_ERROR="invalid plugin id"; return 1; }
    _cc_plugin_safe_token "$CC_PLUGIN_VERSION" || { CC_PLUGIN_PARSE_ERROR="invalid version"; return 1; }
    _cc_plugin_safe_list "$CC_PLUGIN_PROVIDES" || { CC_PLUGIN_PARSE_ERROR="invalid capability list"; return 1; }
    _cc_plugin_safe_list "$CC_PLUGIN_DEPENDENCIES" || { CC_PLUGIN_PARSE_ERROR="invalid dependency list"; return 1; }
    _cc_plugin_safe_list "$CC_PLUGIN_OPTIONAL_DEPENDENCIES" || { CC_PLUGIN_PARSE_ERROR="invalid optional dependency list"; return 1; }
    _cc_plugin_safe_list "$CC_PLUGIN_PLATFORMS" || { CC_PLUGIN_PARSE_ERROR="invalid platform list"; return 1; }
    _cc_plugin_relative_path_safe "$CC_PLUGIN_ENTRYPOINT" || { CC_PLUGIN_PARSE_ERROR="unsafe entrypoint path"; return 1; }
    case "$CC_PLUGIN_ENABLED" in yes|no) ;; *) CC_PLUGIN_PARSE_ERROR="enabled must be yes or no"; return 1 ;; esac
}

_cc_plugin_platform_supported() {
    local platforms="$1" platform item
    platform="$(cc_platform_type)"
    IFS=',' read -r -a _cc_plugin_items <<< "$platforms"
    for item in "${_cc_plugin_items[@]}"; do
        [ "$item" = any ] && return 0
        [ "$item" = "$platform" ] && return 0
    done
    return 1
}

_cc_plugin_add_record() {
    local index="${#CC_PLUGIN_IDS[@]}" escaped_path
    printf -v escaped_path '%q' "$7"
    CC_PLUGIN_IDS[index]="$1" CC_PLUGIN_NAMES[index]="$2" CC_PLUGIN_STATES[index]="$3"
    CC_PLUGIN_VERSIONS[index]="$4" CC_PLUGIN_PROVIDES_LIST[index]="$5"
    CC_PLUGIN_ORIGINS[index]="$6" CC_PLUGIN_PATHS[index]="$escaped_path" CC_PLUGIN_REASONS[index]="$8"
    CC_PLUGIN_ENTRYPOINTS[index]="${9:-}"
    CC_PLUGIN_RAW_PATHS[index]="$7"
}

_cc_plugin_scan_directory() {
    local directory="$1" origin="$2" manifest entrypoint state reason dep status
    local optional_missing="" directory_mode manifest_mode entrypoint_mode candidate
    candidate="$(basename "$directory")"
    _cc_plugin_safe_token "$candidate" || candidate=invalid-material
    if [ -L "$directory" ]; then
        _cc_plugin_add_record "$candidate" "$candidate" FAIL - - "$origin" "$directory" "symlink plugin directory"
        return
    fi
    [ -d "$directory" ] || return
    if ! _cc_plugin_root_safe "$directory"; then
        _cc_plugin_add_record "$candidate" "$candidate" FAIL - - "$origin" "$directory" "unsafe plugin directory"
        return
    fi
    manifest="$directory/plugin.conf"
    if [ ! -e "$manifest" ] && [ ! -L "$manifest" ]; then
        _cc_plugin_add_record "$candidate" "$candidate" WARN - - "$origin" "$directory" "no plugin.conf manifest"
        return
    fi
    if ! _cc_plugin_parse_manifest "$manifest"; then
        _cc_plugin_add_record "$candidate" "$candidate" FAIL - - "$origin" "$directory" "$CC_PLUGIN_PARSE_ERROR"
        return
    fi
    [ "$candidate" = "$CC_PLUGIN_ID" ] || {
        _cc_plugin_add_record "$CC_PLUGIN_ID" "$CC_PLUGIN_NAME" FAIL "$CC_PLUGIN_VERSION" "$CC_PLUGIN_PROVIDES" "$origin" "$directory" "directory name must match plugin id" "$CC_PLUGIN_ENTRYPOINT" "$CC_PLUGIN_DEPENDENCIES" "$CC_PLUGIN_OPTIONAL_DEPENDENCIES" "$CC_PLUGIN_PLATFORMS" "$CC_PLUGIN_ENABLED"
        return
    }
    entrypoint="$directory/$CC_PLUGIN_ENTRYPOINT"
    if ! _cc_plugin_path_has_no_symlinks "$directory" "$CC_PLUGIN_ENTRYPOINT"; then
        state=FAIL reason="symlink entrypoint path"
    elif ! _cc_plugin_entrypoint_directories_safe "$directory" "$CC_PLUGIN_ENTRYPOINT"; then
        state=FAIL reason="unsafe entrypoint directory"
    elif ! _cc_plugin_owned_regular_file "$entrypoint"; then
        state=FAIL reason="entrypoint must be owner-controlled regular file"
    elif [ ! -x "$entrypoint" ]; then
        state=FAIL reason="entrypoint is not executable"
    elif [ "$CC_PLUGIN_ENABLED" = no ]; then
        state=SKIP reason="disabled by manifest"
    elif ! _cc_plugin_platform_supported "$CC_PLUGIN_PLATFORMS"; then
        state=SKIP reason="unsupported on $(cc_platform_type)"
    else
        state=PASS reason="enabled and healthy"
        if [ -n "$CC_PLUGIN_DEPENDENCIES" ]; then
            IFS=',' read -r -a _cc_plugin_items <<< "$CC_PLUGIN_DEPENDENCIES"
            for dep in "${_cc_plugin_items[@]}"; do
                status="$(cc_dep_execution_status "$dep")"
                [ "$status" = OK ] || { state=FAIL; reason="missing required dependency: $dep ($status)"; break; }
            done
        fi
        if [ "$state" = PASS ] && [ -n "$CC_PLUGIN_OPTIONAL_DEPENDENCIES" ]; then
            IFS=',' read -r -a _cc_plugin_items <<< "$CC_PLUGIN_OPTIONAL_DEPENDENCIES"
            for dep in "${_cc_plugin_items[@]}"; do
                status="$(cc_dep_execution_status "$dep")"
                [ "$status" = OK ] || optional_missing="${optional_missing:+$optional_missing,}$dep"
            done
            if [ -n "$optional_missing" ]; then state=WARN; reason="missing optional dependency: $optional_missing"; fi
        fi
    fi
    directory_mode="$(stat -c %a -- "$directory" 2>/dev/null || printf unknown)"
    manifest_mode="$(stat -c %a -- "$manifest" 2>/dev/null || printf unknown)"
    entrypoint_mode="$(stat -c %a -- "$entrypoint" 2>/dev/null || printf unknown)"
    if [ "$state" = PASS ] && {
        { [[ "$directory_mode" =~ ^[0-7]+$ ]] && (( (8#$directory_mode & 0020) != 0 )); } ||
        { [[ "$manifest_mode" =~ ^[0-7]+$ ]] && (( (8#$manifest_mode & 0020) != 0 )); } ||
        { [[ "$entrypoint_mode" =~ ^[0-7]+$ ]] && (( (8#$entrypoint_mode & 0020) != 0 )); }
    }; then
        state=WARN reason="plugin material is group-writable"
    fi
    _cc_plugin_add_record "$CC_PLUGIN_ID" "$CC_PLUGIN_NAME" "$state" "$CC_PLUGIN_VERSION" "$CC_PLUGIN_PROVIDES" "$origin" "$directory" "$reason" "$CC_PLUGIN_ENTRYPOINT" "$CC_PLUGIN_DEPENDENCIES" "$CC_PLUGIN_OPTIONAL_DEPENDENCIES" "$CC_PLUGIN_PLATFORMS" "$CC_PLUGIN_ENABLED"
}

_cc_plugin_inventory_load() {
    local root origin item index other duplicate_count capability candidate
    declare -A capability_counts=()
    CC_PLUGIN_IDS=() CC_PLUGIN_NAMES=() CC_PLUGIN_STATES=() CC_PLUGIN_VERSIONS=()
    CC_PLUGIN_PROVIDES_LIST=() CC_PLUGIN_ORIGINS=() CC_PLUGIN_PATHS=() CC_PLUGIN_REASONS=()
    CC_PLUGIN_ENTRYPOINTS=() CC_PLUGIN_RAW_PATHS=()

    for origin in repository host; do
        if [ "$origin" = repository ]; then root="$(cc_plugin_repository_root)"; else root="$(cc_plugin_host_root)"; fi
        [ -e "$root" ] || [ -L "$root" ] || continue
        if ! _cc_plugin_root_safe "$root"; then
            _cc_plugin_add_record "$origin-root" "$origin plugin root" FAIL - - "$origin" "$root" "unsafe plugin root"
            continue
        fi
        while IFS= read -r -d '' item; do
            if [ -d "$item" ] || [ -L "$item" ]; then
                _cc_plugin_scan_directory "$item" "$origin"
            elif [ "$(basename "$item")" != README.md ] && [ "$(basename "$item")" != .gitkeep ]; then
                candidate="$(basename "$item")"
                _cc_plugin_safe_token "$candidate" || candidate=unknown-material
                _cc_plugin_add_record "$candidate" "$candidate" WARN - - "$origin" "$item" "unknown material"
            fi
        done < <(find "$root" -mindepth 1 -maxdepth 1 -print0 2>/dev/null | LC_ALL=C sort -z)
    done

    for index in "${!CC_PLUGIN_IDS[@]}"; do
        [ "${CC_PLUGIN_PROVIDES_LIST[index]}" != - ] || continue
        duplicate_count=0
        for other in "${!CC_PLUGIN_IDS[@]}"; do
            [ "${CC_PLUGIN_PROVIDES_LIST[other]}" != - ] || continue
            [ "${CC_PLUGIN_IDS[index]}" = "${CC_PLUGIN_IDS[other]}" ] && duplicate_count=$((duplicate_count + 1))
        done
        if [ "$duplicate_count" -gt 1 ]; then
            CC_PLUGIN_STATES[index]=FAIL CC_PLUGIN_REASONS[index]="duplicate plugin id"
        fi
    done

    for index in "${!CC_PLUGIN_IDS[@]}"; do
        case "${CC_PLUGIN_STATES[index]}" in PASS|WARN) ;; *) continue ;; esac
        [ "${CC_PLUGIN_PROVIDES_LIST[index]}" != - ] || continue
        IFS=',' read -r -a _cc_plugin_caps <<< "${CC_PLUGIN_PROVIDES_LIST[index]}"
        for capability in "${_cc_plugin_caps[@]}"; do
            capability_counts["$capability"]=$(( ${capability_counts["$capability"]:-0} + 1 ))
        done
    done
    for index in "${!CC_PLUGIN_IDS[@]}"; do
        case "${CC_PLUGIN_STATES[index]}" in PASS|WARN) ;; *) continue ;; esac
        [ "${CC_PLUGIN_PROVIDES_LIST[index]}" != - ] || continue
        IFS=',' read -r -a _cc_plugin_caps <<< "${CC_PLUGIN_PROVIDES_LIST[index]}"
        for capability in "${_cc_plugin_caps[@]}"; do
            if cc_program_is_capability "$capability" || cc_platform_capability_known "$capability"; then
                CC_PLUGIN_STATES[index]=FAIL CC_PLUGIN_REASONS[index]="capability conflicts with core: $capability"
                break
            elif [ "${capability_counts["$capability"]}" -gt 1 ]; then
                CC_PLUGIN_STATES[index]=FAIL CC_PLUGIN_REASONS[index]="duplicate capability provider: $capability"
                break
            fi
        done
    done
}

cc_plugin_inventory_tsv() {
    local index
    _cc_plugin_inventory_load
    for index in "${!CC_PLUGIN_IDS[@]}"; do
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "${CC_PLUGIN_IDS[index]}" "${CC_PLUGIN_NAMES[index]}" "${CC_PLUGIN_STATES[index]}" \
            "${CC_PLUGIN_VERSIONS[index]}" "${CC_PLUGIN_PROVIDES_LIST[index]}" \
            "${CC_PLUGIN_ORIGINS[index]}" "${CC_PLUGIN_PATHS[index]}" "${CC_PLUGIN_REASONS[index]}" \
            "${CC_PLUGIN_ENTRYPOINTS[index]}"
    done
}

cc_plugin_capability_tsv() {
    local requested="${1:-}" index capability
    _cc_plugin_inventory_load
    for index in "${!CC_PLUGIN_IDS[@]}"; do
        [ "${CC_PLUGIN_PROVIDES_LIST[index]}" != - ] || continue
        IFS=',' read -r -a _cc_plugin_caps <<< "${CC_PLUGIN_PROVIDES_LIST[index]}"
        for capability in "${_cc_plugin_caps[@]}"; do
            [ -z "$requested" ] || [ "$requested" = "$capability" ] || continue
            printf '%s\t%s\t%s\t%s\t%s\n' "$capability" "${CC_PLUGIN_IDS[index]}" \
                "${CC_PLUGIN_STATES[index]}" "${CC_PLUGIN_ORIGINS[index]}" "${CC_PLUGIN_REASONS[index]}"
        done
    done
}

cc_plugin_runtime_resolve() {
    local requested="$1" index match=-1 count=0
    CC_PLUGIN_RUNTIME_ERROR=""
    _cc_plugin_safe_token "$requested" || {
        CC_PLUGIN_RUNTIME_ERROR="invalid plugin id"
        return 2
    }
    _cc_plugin_inventory_load
    for index in "${!CC_PLUGIN_IDS[@]}"; do
        [ "${CC_PLUGIN_IDS[index]}" = "$requested" ] || continue
        match="$index"
        count=$((count + 1))
    done
    [ "$count" -gt 0 ] || {
        CC_PLUGIN_RUNTIME_ERROR="plugin not found: $requested"
        return 1
    }
    [ "$count" -eq 1 ] || {
        CC_PLUGIN_RUNTIME_ERROR="plugin id is not unique: $requested"
        return 1
    }
    case "${CC_PLUGIN_STATES[match]}:${CC_PLUGIN_REASONS[match]}" in
        PASS:*|WARN:missing\ optional\ dependency:*) ;;
        *)
            CC_PLUGIN_RUNTIME_ERROR="plugin is not executable: ${CC_PLUGIN_STATES[match]} (${CC_PLUGIN_REASONS[match]})"
            return 1
            ;;
    esac
    CC_PLUGIN_RUNTIME_ID="${CC_PLUGIN_IDS[match]}"
    CC_PLUGIN_RUNTIME_ROOT="${CC_PLUGIN_RAW_PATHS[match]}"
    CC_PLUGIN_RUNTIME_ENTRYPOINT="$CC_PLUGIN_RUNTIME_ROOT/${CC_PLUGIN_ENTRYPOINTS[match]}"
}

cc_plugin_run() {
    local plugin_id="${1:-}" toolkit_root
    [ "$#" -ge 2 ] || {
        printf 'Plugin ID and operation are required.\n' >&2
        return 2
    }
    shift
    if ! cc_plugin_runtime_resolve "$plugin_id"; then
        printf '%s\n' "$CC_PLUGIN_RUNTIME_ERROR" >&2
        return 126
    fi
    toolkit_root="${TOOLKIT_ROOT:-${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}}"

    # Resolution above deliberately performs a new manifest, platform,
    # dependency, ownership, permission, and entrypoint-path validation. The
    # exact absolute entrypoint is then executed directly without a shell
    # command string, PATH lookup, sourcing, privilege elevation, or eval.
    BASH_ENV='' ENV='' CDPATH='' PATH=/usr/sbin:/usr/bin:/sbin:/bin \
        CC_PLUGIN_ID="$CC_PLUGIN_RUNTIME_ID" \
        CC_PLUGIN_API="$CC_PLUGIN_API_VERSION" \
        CC_PLUGIN_ROOT="$CC_PLUGIN_RUNTIME_ROOT" \
        CC_TOOLKIT_ROOT="$toolkit_root" CC_PROGRAMS_CONFIG='' CC_PROGRAMS_LOADED='' \
        "$CC_PLUGIN_RUNTIME_ENTRYPOINT" "$@"
}
