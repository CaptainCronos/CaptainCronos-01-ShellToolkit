#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-config.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash awk grep mktemp stat cp mv chmod hostname date sed tr
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Resolve, validate, and safely mutate toolkit configuration.
# ==============================================================================

# Stored expansion syntax is deliberately matched as literal configuration data.
# shellcheck disable=SC2016

if [ -z "${CC_TEMP_LOADED:-}" ]; then
    _cc_config_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_config_lib_dir/cc-temp.sh"
    unset _cc_config_lib_dir
fi

CC_CONFIG_SCHEMA_VERSION=1

cc_config_dir() { printf '%s\n' "${CAPTAIN_CRONOS_CONFIG_DIR:-${CC_HOME:-$HOME/.captaincronos}}"; }
cc_config_file() { printf '%s/config\n' "$(cc_config_dir)"; }
cc_config_identity_file() { printf '%s/host-id\n' "$(cc_config_dir)"; }

cc_config_defaults_file() {
    local lib_dir root
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    root="${TOOLKIT_ROOT:-${PROJECT_ROOT:-${lib_dir}/..}}"
    printf '%s/config/defaults.conf\n' "$root"
}

cc_config_safe_id() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' |
        sed 's/[^a-z0-9._-]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

_cc_config_value_from_file() {
    local file="$1" key="$2" value
    [ -f "$file" ] && [ ! -L "$file" ] || return 1
    value="$(awk -v key="$key" '$0 ~ "^" key "=" {value=substr($0,length(key)+2)} END{if(value!="") print value}' "$file" 2>/dev/null)"
    [ -n "$value" ] || return 1
    if [[ "$value" == \"*\" ]] && [ "${#value}" -ge 2 ]; then
        value="${value:1:${#value}-2}"
        value="${value//\\\"/\"}"
        value="${value//\\\\/\\}"
    fi
    case "$value" in
        '$HOME') value="$HOME" ;;
        '$HOME/'*) value="$HOME/${value#\$HOME/}" ;;
        '${HOME}') value="$HOME" ;;
        '${HOME}/'*) value="$HOME/${value#\$\{HOME\}/}" ;;
    esac
    printf '%s\n' "$value"
}

cc_config_host_id() {
    local identity raw safe
    if [ -n "${CC_HOST_ID:-}" ]; then
        safe="$(cc_config_safe_id "$CC_HOST_ID")"
        [ -n "$safe" ] || return 1
        printf '%s\n' "$safe"
        return
    fi
    identity="$(cc_config_identity_file)"
    if [ -e "$identity" ] || [ -L "$identity" ]; then
        _cc_config_target_safe "$identity" && [ -r "$identity" ] || return 1
        raw="$(<"$identity")"
        safe="$(cc_config_safe_id "$raw")"
        [ -n "$raw" ] && [ "$safe" = "$raw" ] || return 1
        printf '%s\n' "$safe"
        return
    fi
    raw="$(_cc_config_value_from_file "$(cc_config_file)" HOST_ID 2>/dev/null || true)"
    if [ -n "$raw" ]; then
        safe="$(cc_config_safe_id "$raw")"
        [ -n "$safe" ] || return 1
        printf '%s\n' "$safe"
        return
    fi
    raw="$(hostname -s 2>/dev/null || hostname 2>/dev/null || printf unknown-host)"
    safe="$(cc_config_safe_id "$raw")"
    printf '%s\n' "${safe:-unknown-host}"
}

cc_config_identity_source() {
    local identity
    if [ -n "${CC_HOST_ID:-}" ]; then
        printf 'runtime override (CC_HOST_ID)\n'
        return
    fi
    identity="$(cc_config_identity_file)"
    if [ -f "$identity" ] && [ ! -L "$identity" ]; then
        printf 'stored identity\n'
    elif _cc_config_value_from_file "$(cc_config_file)" HOST_ID >/dev/null 2>&1; then
        printf 'legacy global HOST_ID\n'
    else
        printf 'hostname fallback\n'
    fi
}

cc_config_host_home() {
    if [ -n "${CC_HOST_HOME:-}" ]; then printf '%s\n' "$CC_HOST_HOME"
    else printf '%s/hosts/%s\n' "$(cc_config_dir)" "$(cc_config_host_id)"; fi
}

cc_config_host_file() {
    if [ -n "${CC_CONFIG:-}" ]; then printf '%s\n' "$CC_CONFIG"
    else printf '%s/config\n' "$(cc_config_host_home)"; fi
}

_cc_config_path_lexically_safe() {
    local path="$1" remainder component
    [ -n "$path" ] && [ "$path" != / ] && [[ "$path" == /* ]] || return 1
    remainder="${path#/}"
    while :; do
        component="${remainder%%/*}"
        [ "$component" != .. ] || return 1
        [ "$remainder" != "$component" ] || break
        remainder="${remainder#*/}"
    done
}

_cc_config_path_has_no_symlinks() {
    local probe="$1"
    while [ "$probe" != / ]; do
        [ ! -L "$probe" ] || return 1
        probe="${probe%/*}"
        [ -n "$probe" ] || probe=/
    done
}

_cc_config_target_safe() {
    local path="$1" owner
    _cc_config_path_lexically_safe "$path" || return 1
    _cc_config_path_has_no_symlinks "$path" || return 1
    if [ -e "$path" ]; then
        [ -f "$path" ] || return 1
        owner="$(stat -c %u -- "$path" 2>/dev/null)" || return 1
        [ "$owner" = "$EUID" ] || return 1
    fi
}

_cc_config_ensure_private_dir() {
    local dir="$1" parent owner
    _cc_config_path_lexically_safe "$dir" || return 1
    _cc_config_path_has_no_symlinks "$dir" || return 1
    if [ -e "$dir" ]; then
        [ -d "$dir" ] || return 1
        owner="$(stat -c %u -- "$dir" 2>/dev/null)" || return 1
        [ "$owner" = "$EUID" ] || return 1
        chmod 700 "$dir"
        return
    fi
    parent="${dir%/*}"; [ "$parent" != "$dir" ] || return 1
    [ -d "$parent" ] || _cc_config_ensure_private_dir "$parent" || return
    (umask 077; mkdir -- "$dir")
}

_cc_config_atomic_replace() {
    local target="$1" source="$2" parent tmp="" before="" current=""
    _cc_config_target_safe "$target" || return 1
    [ -f "$source" ] && [ ! -L "$source" ] || return 1
    parent="${target%/*}"; _cc_config_ensure_private_dir "$parent" || return 1
    [ ! -e "$target" ] || before="$(stat -c '%u:%d:%i' -- "$target")" || return 1
    cc_temp_file tmp "$parent/.cc-config.XXXXXX" || return 1
    command cp -- "$source" "$tmp" || { cc_temp_remove "$tmp" || :; return 1; }
    chmod 600 "$tmp" || { cc_temp_remove "$tmp" || :; return 1; }
    if [ -n "$before" ]; then
        current="$(stat -c '%u:%d:%i' -- "$target" 2>/dev/null || true)"
        [ "$current" = "$before" ] || { cc_temp_remove "$tmp" || :; return 1; }
    else
        [ ! -e "$target" ] && [ ! -L "$target" ] || { cc_temp_remove "$tmp" || :; return 1; }
    fi
    command mv -- "$tmp" "$target" || { cc_temp_remove "$tmp" || :; return 1; }
    cc_temp_unregister "$tmp"
}

_cc_config_write_text() {
    local target="$1" text="$2" parent staging=""
    parent="${target%/*}"; _cc_config_ensure_private_dir "$parent" || return 1
    cc_temp_file staging "$parent/.cc-content.XXXXXX" || return 1
    printf '%s' "$text" > "$staging" || { cc_temp_remove "$staging" || :; return 1; }
    _cc_config_atomic_replace "$target" "$staging" || { cc_temp_remove "$staging" || :; return 1; }
    cc_temp_remove "$staging" || :
}

cc_config_identity_init() {
    local requested="$1" identity current safe
    identity="$(cc_config_identity_file)"; safe="$(cc_config_safe_id "$requested")"
    [ -n "$safe" ] && [ "$safe" = "$requested" ] || return 2
    if [ -e "$identity" ] || [ -L "$identity" ]; then
        _cc_config_target_safe "$identity" || return 1
        current="$(<"$identity")"
        [ "$current" = "$safe" ]
        return
    fi
    _cc_config_write_text "$identity" "$safe"$'\n'
}

cc_config_init() {
    local initialize_identity="${1:-0}" cfg identity host_id content identity_exists=0
    cfg="$(cc_config_file)"
    if [ -e "$cfg" ] || [ -L "$cfg" ]; then
        _cc_config_target_safe "$cfg" || return 1
        if [ "$initialize_identity" = 1 ]; then
            host_id="$(cc_config_host_id)" || return 1
            cc_config_identity_init "$host_id" || return 1
        fi
        return
    fi
    host_id="$(cc_config_host_id)" || return 1
    identity="$(cc_config_identity_file)"
    if [ -e "$identity" ] || [ -L "$identity" ]; then
        identity_exists=1
        cc_config_identity_init "$host_id" || return 1
    fi
    content="# Captain Cronos global user configuration
CONFIG_VERSION=\"$CC_CONFIG_SCHEMA_VERSION\"
REPO_ROOT=\"\$HOME/GitHub\"
DOCS_DIR=\"docs/generated\"
AUTO_DOCS=\"no\"
AUTO_PUSH=\"no\"
DEV_UPDATES=\"no\"
EDITOR=\"nano\"
"
    _cc_config_write_text "$cfg" "$content" || return
    if [ "$identity_exists" -eq 0 ]; then
        cc_config_identity_init "$host_id"
    fi
}

cc_config_get() {
    local key="$1" default="${2:-}" file value="" candidate found=0
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 2
    for file in "$(cc_config_defaults_file)" "$(cc_config_file)" "$(cc_config_host_file 2>/dev/null || true)"; do
        [ -n "$file" ] || continue
        if candidate="$(_cc_config_value_from_file "$file" "$key" 2>/dev/null)"; then value="$candidate"; found=1; fi
    done
    [ "$found" -eq 0 ] || { printf '%s\n' "$value"; return; }
    printf '%s\n' "$default"
}

cc_config_set() {
    local key="$1" value="$2" cfg tmp="" encoded status
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 2
    case "$value" in *$'\n'*|*$'\r'*) return 2 ;; esac
    cfg="$(cc_config_file)"; cc_config_init || return
    _cc_config_target_safe "$cfg" || return 1
    cc_temp_file tmp "${cfg%/*}/.cc-set.XXXXXX" || return 1
    encoded="${value//\\/\\\\}"; encoded="${encoded//\"/\\\"}"
    awk -v k="$key" '$0!~"^"k"="{print}' "$cfg" > "$tmp" || { status=$?; cc_temp_remove "$tmp" || :; return "$status"; }
    printf '%s="%s"\n' "$key" "$encoded" >> "$tmp" || { status=$?; cc_temp_remove "$tmp" || :; return "$status"; }
    _cc_config_atomic_replace "$cfg" "$tmp" || { status=$?; cc_temp_remove "$tmp" || :; return "$status"; }
    cc_temp_remove "$tmp" || :
}

_cc_config_secret_key() {
    local key="${1^^}"
    case "$key" in
        *TOKEN*|*PASSWORD*|*PASSWD*|*SECRET*|*AUTH*|*PRIVATE_KEY*|*API_KEY*|*ACCESS_KEY*|*CREDENTIAL*|*BEARER*|*COOKIE*) return 0 ;;
        *) return 1 ;;
    esac
}

_cc_config_known_key() {
    case "$1" in
        CONFIG_VERSION|HOST_ID|HOST_ROLE|HOST_PROFILE|HOST_PLATFORM|HOST_OS|HOST_OS_VERSION|HOST_ARCH|PACKAGE_MANAGER|INIT_SYSTEM|REPO_ROOT|REPORT_DIR|ASSET_DIR|PLUGIN_DIR|CACHE_DIR|LOG_DIR|DOCS_DIR|AUTO_DOCS|AUTO_PUSH|DEV_UPDATES|EDITOR|READ_ONLY|DRIVE_QUALIFICATION|NO_SYSTEM_UPDATE|MONTHLY_HEALTH_RETENTION_MIN_COUNT|MONTHLY_HEALTH_RETENTION_MAX_AGE_DAYS|DRIVE_REPORT_RETENTION_MIN_COUNT|DRIVE_REPORT_RETENTION_MAX_AGE_DAYS) return 0;;
        *) return 1;;
    esac
}

_cc_config_validate_file() {
    local label="$1" file="$2" required="$3" line key line_number=0 seen=" " status=PASS mode owner unknown=0 unknown_keys=""
    if [ ! -e "$file" ] && [ ! -L "$file" ]; then
        [ "$required" = yes ] && status=WARN || status=PASS
        printf '%s\t%s\t%s\n' "$status" "$label" absent; return
    fi
    if ! _cc_config_path_lexically_safe "$file" || ! _cc_config_path_has_no_symlinks "$file" || [ ! -f "$file" ]; then
        printf 'FAIL\t%s\tunsafe target\n' "$label"; return 1
    fi
    owner="$(stat -c %u -- "$file" 2>/dev/null || printf unknown)"; mode="$(stat -c %a -- "$file" 2>/dev/null || printf unknown)"
    [ "$owner" = "$EUID" ] || status=FAIL
    [ "$mode" = 600 ] || { [ "$status" = FAIL ] || status=WARN; }
    while IFS= read -r line || [ -n "$line" ]; do
        line_number=$((line_number + 1)); case "$line" in ''|'#'*) continue;; esac
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(\"([^\"\\]|\\.)*\"|[^[:space:]]*)$ ]]; then key="${BASH_REMATCH[1]}"
        else printf 'FAIL\t%s\tmalformed line %s\n' "$label" "$line_number"; return 1; fi
        case "$seen" in *" $key "*) printf 'FAIL\t%s\tduplicate key %s\n' "$label" "$key"; return 1;; esac
        seen="$seen$key "
        if ! _cc_config_known_key "$key"; then
            unknown=$((unknown + 1))
            unknown_keys="${unknown_keys:+$unknown_keys,}$key"
            [ "$status" = FAIL ] || status=WARN
        fi
    done < "$file"
    if [ "$unknown" -gt 0 ]; then
        printf '%s\t%s\tmode %s; unknown keys: %s\n' "$status" "$label" "$mode" "$unknown_keys"
    else
        printf '%s\t%s\tmode %s; unknown keys 0\n' "$status" "$label" "$mode"
    fi
    [ "$status" != FAIL ]
}

_cc_config_validate_dir() {
    local label="$1" dir="$2" mode owner
    if [ ! -e "$dir" ] && [ ! -L "$dir" ]; then printf 'PASS\t%s\tabsent\n' "$label"; return; fi
    if ! _cc_config_path_lexically_safe "$dir" || ! _cc_config_path_has_no_symlinks "$dir" || [ ! -d "$dir" ]; then
        printf 'FAIL\t%s\tunsafe target\n' "$label"; return 1
    fi
    mode="$(stat -c %a -- "$dir" 2>/dev/null || printf unknown)"; owner="$(stat -c %u -- "$dir" 2>/dev/null || printf unknown)"
    if [ "$owner" != "$EUID" ]; then printf 'FAIL\t%s\twrong owner\n' "$label"; return 1
    elif [ "$mode" != 700 ]; then printf 'WARN\t%s\tmode %s, expected 700\n' "$label" "$mode"
    else printf 'PASS\t%s\tmode 700\n' "$label"; fi
}

cc_config_validation_rows() {
    local global host identity version role profile selected_id configured_id global_id stored_id="" result=0
    global="$(cc_config_file)"; host="$(cc_config_host_file 2>/dev/null || true)"; identity="$(cc_config_identity_file)"
    _cc_config_validate_dir "Configuration root" "$(cc_config_dir)" || result=1
    if [ -n "$host" ]; then
        _cc_config_validate_dir "Current host root" "${host%/*}" || result=1
    fi
    _cc_config_validate_file "Global config" "$global" yes || result=1
    if [ -n "$host" ]; then
        _cc_config_validate_file "Host config" "$host" no || result=1
    fi
    if [ -e "$identity" ] || [ -L "$identity" ]; then
        if [ -f "$identity" ] && [ ! -L "$identity" ]; then
            stored_id="$(<"$identity")"
        fi
        if [ -L "$identity" ] || [ ! -f "$identity" ] || [ -z "$stored_id" ] || [ "$(cc_config_safe_id "$stored_id")" != "$stored_id" ]; then
            printf 'FAIL\tHost identity\tunsafe or malformed\n'; result=1
        elif [ "$(stat -c %u -- "$identity" 2>/dev/null)" != "$EUID" ]; then
            printf 'FAIL\tHost identity\twrong owner\n'; result=1
        elif [ "$(stat -c %a -- "$identity" 2>/dev/null)" != 600 ]; then
            printf 'WARN\tHost identity\tpermissions not 0600\n'
        else
            printf 'PASS\tHost identity\tstable file\n'
        fi
    else printf 'WARN\tHost identity\thostname fallback\n'; fi
    selected_id="$(cc_config_host_id 2>/dev/null || true)"
    if [ -n "${CC_HOST_ID:-}" ]; then
        if [ -n "$stored_id" ] && [ "$selected_id" != "$stored_id" ]; then
            printf 'WARN\tHost selection\tCC_HOST_ID override selects %s instead of stored %s\n' "$selected_id" "$stored_id"
        else
            printf 'WARN\tHost selection\tCC_HOST_ID runtime override active (%s)\n' "$selected_id"
        fi
    else
        printf 'PASS\tHost selection\t%s (%s)\n' "$selected_id" "$(cc_config_identity_source)"
    fi
    global_id="$(_cc_config_value_from_file "$global" HOST_ID 2>/dev/null || true)"
    if [ -n "$global_id" ] && [ -n "$stored_id" ]; then
        if [ "$(cc_config_safe_id "$global_id")" != "$global_id" ]; then
            printf 'FAIL\tLegacy host reference\tglobal HOST_ID is malformed\n'; result=1
        elif [ "$global_id" != "$stored_id" ]; then
            printf 'WARN\tLegacy host reference\tglobal HOST_ID %s differs from stored %s\n' "$global_id" "$stored_id"
        else
            printf 'PASS\tLegacy host reference\tmatches stored identity\n'
        fi
    fi
    version="$(_cc_config_value_from_file "$global" CONFIG_VERSION 2>/dev/null || true)"
    if [ ! -e "$global" ]; then printf 'WARN\tConfiguration schema\tnot initialized\n'
    elif [ -z "$version" ]; then printf 'WARN\tConfiguration schema\tlegacy; migration available\n'
    elif ! [[ "$version" =~ ^[0-9]+$ ]]; then printf 'FAIL\tConfiguration schema\tmalformed\n'; result=1
    elif [ "$version" -gt "$CC_CONFIG_SCHEMA_VERSION" ]; then printf 'FAIL\tConfiguration schema\tfuture v%s\n' "$version"; result=1
    elif [ "$version" -lt "$CC_CONFIG_SCHEMA_VERSION" ]; then printf 'WARN\tConfiguration schema\told v%s; migration available\n' "$version"
    else printf 'PASS\tConfiguration schema\tv%s\n' "$version"; fi
    role="$(cc_config_get HOST_ROLE workstation 2>/dev/null || true)"
    case "$role" in developer|workbench|server|nas|laptop|custom|workstation) printf 'PASS\tHost role\t%s\n' "$role";; *) printf 'FAIL\tHost role\tinvalid\n'; result=1;; esac
    profile="$(cc_config_get HOST_PROFILE default 2>/dev/null || true)"
    case "$profile" in developer|workbench|server|truenas-scale|laptop|default) printf 'PASS\tHost profile\t%s\n' "$profile";; *) printf 'FAIL\tHost profile\tmissing or invalid\n'; result=1;; esac
    if [ -n "$host" ] && [ -f "$host" ]; then
        configured_id="$(_cc_config_value_from_file "$host" HOST_ID 2>/dev/null || true)"
        if [ -z "$configured_id" ]; then printf 'WARN\tHost reference\tHOST_ID missing\n'
        elif [ "$configured_id" = "$selected_id" ]; then printf 'PASS\tHost reference\tcurrent host\n'
        else printf 'FAIL\tHost reference\tdoes not match current host\n'; result=1; fi
    fi
    return "$result"
}

cc_config_validate() {
    local rows status label detail warnings=0 failures=0 overall
    rows="$(cc_config_validation_rows)" || true
    while IFS=$'\t' read -r status label detail; do
        [ -n "$status" ] || continue; printf '%-24s %-5s %s\n' "$label" "$status" "$detail"
        [ "$status" != WARN ] || warnings=$((warnings + 1)); [ "$status" != FAIL ] || failures=$((failures + 1))
    done <<< "$rows"
    if [ "$failures" -gt 0 ]; then overall=FAIL; elif [ "$warnings" -gt 0 ]; then overall=WARN; else overall=PASS; fi
    printf '%-24s %s\n' Overall "$overall"; [ "$failures" -eq 0 ]
}

cc_config_status() {
    local global host host_id schema global_count=0 host_count=0
    global="$(cc_config_file)"; host="$(cc_config_host_file 2>/dev/null || true)"
    host_id="$(cc_config_host_id 2>/dev/null || printf invalid)"; schema="$(_cc_config_value_from_file "$global" CONFIG_VERSION 2>/dev/null || printf legacy)"
    [ ! -f "$global" ] || global_count="$(awk '/^[A-Za-z_][A-Za-z0-9_]*=/{n++}END{print n+0}' "$global")"
    [ -z "$host" ] || [ ! -f "$host" ] || host_count="$(awk '/^[A-Za-z_][A-Za-z0-9_]*=/{n++}END{print n+0}' "$host")"
    printf '%-18s %s\n' Schema: "$schema"; printf '%-18s %s\n' Defaults: "$(cc_config_defaults_file)"
    printf '%-18s %s (%s keys)\n' 'Global config:' "$global" "$global_count"; printf '%-18s %s (%s keys)\n' 'Host config:' "${host:-unresolved}" "$host_count"
    printf '%-18s %s\n' 'Host ID:' "$host_id"; printf '%-18s %s\n' 'Identity source:' "$(cc_config_identity_source)"
    printf '%-18s %s\n' Role: "$(cc_config_get HOST_ROLE workstation 2>/dev/null || printf invalid)"; printf '%-18s %s\n' Profile: "$(cc_config_get HOST_PROFILE default 2>/dev/null || printf invalid)"
    printf '%-18s %s\n' Precedence: 'defaults -> global -> host -> command line'; echo; cc_config_validate
}

cc_config_show() {
    local file line key
    for file in "$(cc_config_defaults_file)" "$(cc_config_file)" "$(cc_config_host_file 2>/dev/null || true)"; do
        [ -f "$file" ] && [ ! -L "$file" ] || continue; printf '# Source: %s\n' "$file"
        while IFS= read -r line || [ -n "$line" ]; do
            if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)= ]]; then key="${BASH_REMATCH[1]}"; _cc_config_secret_key "$key" && printf '%s="<redacted>"\n' "$key" || printf '%s\n' "$line"
            else printf '%s\n' "$line"; fi
        done < "$file"
    done
}

cc_config_migrate() {
    local apply="${1:-0}" cfg version backup_dir backup tmp=""
    cfg="$(cc_config_file)"; [ -f "$cfg" ] && [ ! -L "$cfg" ] || { printf 'No legacy global config to migrate.\n'; return; }
    _cc_config_validate_file 'Global config' "$cfg" yes | grep -q '^FAIL' && return 1
    version="$(_cc_config_value_from_file "$cfg" CONFIG_VERSION 2>/dev/null || true)"
    if [ "$version" = "$CC_CONFIG_SCHEMA_VERSION" ]; then printf 'Configuration already uses schema v%s.\n' "$version"; return; fi
    [ -z "$version" ] || { [[ "$version" =~ ^[0-9]+$ ]] && [ "$version" -lt "$CC_CONFIG_SCHEMA_VERSION" ]; } || return 1
    printf 'Migration: %s -> schema v%s (preserve all existing keys)\n' "${version:-legacy}" "$CC_CONFIG_SCHEMA_VERSION"
    [ "$apply" = 1 ] || { printf 'Preview only; re-run with --apply.\n'; return; }
    backup_dir="$(cc_config_dir)/backups/config"; _cc_config_ensure_private_dir "$backup_dir" || return 1
    backup="$(mktemp -- "$backup_dir/$(date +%Y%m%d-%H%M%S)-config.XXXXXX")" || return 1
    command cp -- "$cfg" "$backup" || return 1; chmod 600 "$backup" || return 1
    cc_temp_file tmp "${cfg%/*}/.cc-migrate.XXXXXX" || return 1
    printf 'CONFIG_VERSION="%s"\n' "$CC_CONFIG_SCHEMA_VERSION" > "$tmp"; awk '$0!~/^CONFIG_VERSION=/' "$cfg" >> "$tmp" || { cc_temp_remove "$tmp" || :; return 1; }
    _cc_config_atomic_replace "$cfg" "$tmp" || { cc_temp_remove "$tmp" || :; return 1; }; cc_temp_remove "$tmp" || :
    printf 'Migrated global config; backup: %s\n' "$backup"
}
