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
EDITOR="nano"
EOF_CONFIG
    fi
}

cc_config_get() {
    local key="$1" default="${2:-}"
    local cfg value
    cfg="$(cc_config_file)"
    if [ -f "$cfg" ]; then
        value="$(grep -E "^${key}=" "$cfg" 2>/dev/null | tail -n 1 | cut -d= -f2- | sed 's/^"//; s/"$//')"
        if [ -n "$value" ]; then
            eval "printf '%s\n' \"$value\""
            return 0
        fi
    fi
    printf '%s\n' "$default"
}

cc_config_set() {
    local key="$1" value="$2" cfg tmp
    cfg="$(cc_config_file)"
    cc_config_init
    tmp="${cfg}.tmp.$$"
    if grep -qE "^${key}=" "$cfg"; then
        awk -v k="$key" -v v="$value" 'BEGIN{done=0} $0 ~ "^" k "=" {print k "=\"" v "\""; done=1; next} {print} END{if(!done) print k "=\"" v "\""}' "$cfg" > "$tmp"
    else
        cp "$cfg" "$tmp"
        printf '%s="%s"\n' "$key" "$value" >> "$tmp"
    fi
    mv "$tmp" "$cfg"
}

cc_config_show() {
    cc_config_init
    cat "$(cc_config_file)"
}
