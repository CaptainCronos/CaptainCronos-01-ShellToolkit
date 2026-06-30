#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-yaml.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash awk mv
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Shared lightweight YAML helper functions for simple key/value files.
# ==============================================================================

cc_yaml_get() {
    local file="$1" key="$2"
    awk -F: -v key="$key" '
        $1 == key {
            sub(/^[ \t]+/, "", $2)
            gsub(/^"|"$/, "", $2)
            print $2
            exit
        }
    ' "$file"
}

cc_yaml_get_nested() {
    local file="$1" section="$2" key="$3"
    awk -F: -v section="$section" -v key="$key" '
        $1 == section {inside=1; next}
        inside && /^[^ ]/ {inside=0}
        inside && $1 ~ "^[ ]+" key "$" {
            sub(/^[ \t]+/, "", $2)
            gsub(/^"|"$/, "", $2)
            print $2
            exit
        }
    ' "$file"
}

cc_yaml_set() {
    local file="$1" key="$2" value="$3" tmp
    tmp="${file}.tmp.$$"
    awk -v key="$key" -v value="$value" '
        BEGIN {found=0}
        $0 ~ "^" key ":" {print key ": \"" value "\""; found=1; next}
        {print}
        END {if (!found) print key ": \"" value "\""}
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
}

cc_yaml_set_nested() {
    local file="$1" section="$2" key="$3" value="$4" tmp
    tmp="${file}.tmp.$$"
    awk -v section="$section" -v key="$key" -v value="$value" '
        BEGIN {inside=0; section_seen=0; key_set=0}
        $0 == section ":" {inside=1; section_seen=1; print; next}
        inside && /^[^ ]/ {
            if (!key_set) {print "  " key ": \"" value "\""; key_set=1}
            inside=0
        }
        inside && $0 ~ "^[ ]+" key ":" {print "  " key ": \"" value "\""; key_set=1; next}
        {print}
        END {
            if (!section_seen) {
                print section ":"
                print "  " key ": \"" value "\""
            } else if (inside && !key_set) {
                print "  " key ": \"" value "\""
            }
        }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
}
