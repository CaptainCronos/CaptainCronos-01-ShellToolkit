#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-config.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Shared configuration helper functions.
# ==============================================================================

cc_config_dir() {
    echo "${CAPTAIN_CRONOS_CONFIG_DIR:-$HOME/.captaincronos}"
}

cc_config_file() {
    echo "$(cc_config_dir)/config"
}

cc_config_init() {
    local cfg
    cfg="$(cc_config_file)"
    mkdir -p "$(dirname "$cfg")"
    if [ ! -f "$cfg" ]; then
        cat > "$cfg" <<'EOF_CONFIG'
# Captain Cronos Shell Toolkit configuration
REPO_ROOT="$HOME/GitHub"
REPORT_DIR="$HOME/.captaincronos/reports"
DOCS_DIR="docs/generated"
AUTO_DOCS="no"
AUTO_PUSH="no"
DEV_UPDATES="no"
EDITOR="nano"
EOF_CONFIG
    fi
}

cc_config_get() {
    local key="$1" default="${2:-}"
    local cfg value
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 2
    cfg="$(cc_config_file)"
    if [ -f "$cfg" ]; then
        value="$(grep -E "^${key}=" "$cfg" 2>/dev/null || true)"
        value="$(printf '%s\n' "$value" | tail -n 1 | cut -d= -f2-)"
        if [ -n "$value" ]; then
            if [[ "$value" == \"*\" ]]; then
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
            return 0
        fi
    fi
    printf '%s\n' "$default"
}

cc_config_set() {
    local key="$1" value="$2" cfg tmp encoded
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 2
    case "$value" in
        *$'\n'*|*$'\r'*) return 2 ;;
    esac
    cfg="$(cc_config_file)"
    cc_config_init
    tmp="$(mktemp "${cfg}.tmp.XXXXXX")" || return 1
    encoded="${value//\\/\\\\}"
    encoded="${encoded//\"/\\\"}"
    if grep -qE "^${key}=" "$cfg"; then
        awk -v k="$key" -v v="$encoded" 'BEGIN{done=0} $0 ~ "^" k "=" {print k "=\"" v "\""; done=1; next} {print} END{if(!done) print k "=\"" v "\""}' "$cfg" > "$tmp"
    else
        cp "$cfg" "$tmp"
        printf '%s="%s"\n' "$key" "$encoded" >> "$tmp"
    fi
    mv "$tmp" "$cfg"
}

cc_config_show() {
    cc_config_init
    cat "$(cc_config_file)"
}
