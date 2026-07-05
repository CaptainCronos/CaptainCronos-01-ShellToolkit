#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-prompt-engine.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash awk find sort
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Shared prompt template discovery, rendering, and formatting helpers.
# ==============================================================================

CC_PROMPT_ENGINE_LOADED=1

if [ -z "${CC_CONTEXT_LOADED:-}" ]; then
    _cc_prompt_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_prompt_lib_dir/cc-context.sh"
    cc_context_init "${TOOLKIT_ROOT:-${PROJECT_ROOT:-}}" "${CURRENT_REPO:-${PWD:-$(pwd)}}"
    unset _cc_prompt_lib_dir
fi

_cc_prompt_error() {
    if command -v cc_error >/dev/null 2>&1; then
        cc_error "$@"
    else
        echo "[CC ERROR] $*" >&2
    fi
}

cc_prompt_engine_loaded() {
    command -v cc_prompt_template_path >/dev/null 2>&1 && \
    command -v cc_prompt_render >/dev/null 2>&1 && \
    command -v cc_prompt_question_rows >/dev/null 2>&1
}

cc_prompt_engine_dependencies() {
    echo "bash awk find sort"
}

cc_prompt_template_dir() {
    local root=""

    if command -v cc_toolkit_root >/dev/null 2>&1; then
        root="$(cc_toolkit_root 2>/dev/null || true)"
    fi

    [ -n "$root" ] || root="${TOOLKIT_ROOT:-${PROJECT_ROOT:-}}"
    if [ -z "$root" ]; then
        root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
    fi

    echo "$root/templates/prompts"
}

cc_prompt_template_id_valid() {
    local id="${1:-}"
    [[ "$id" =~ ^[a-z][a-z0-9-]*$ ]]
}

cc_prompt_variable_valid() {
    local name="${1:-}"
    [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

cc_prompt_metadata_field() {
    local file="$1" field="$2"
    awk -v field="$field" '
        $0 ~ "^# " field "[[:space:]]*:" {
            sub("^# " field "[[:space:]]*:[[:space:]]*", "")
            print
            exit
        }
    ' "$file"
}

cc_prompt_template_files() {
    local dir
    dir="$(cc_prompt_template_dir)"
    [ -d "$dir" ] || return 0
    find "$dir" -maxdepth 1 -type f -name '*.prompt' | sort
}

cc_prompt_template_id_for_file() {
    local file="$1" id
    id="$(cc_prompt_metadata_field "$file" "Template")"
    [ -n "$id" ] || id="$(cc_prompt_metadata_field "$file" "Id")"
    [ -n "$id" ] || id="$(basename "$file" .prompt)"
    echo "$id"
}

cc_prompt_template_path() {
    local id="$1" dir direct file template_id

    if ! cc_prompt_template_id_valid "$id"; then
        _cc_prompt_error "Invalid prompt template id: $id"
        return 2
    fi

    dir="$(cc_prompt_template_dir)"
    direct="$dir/$id.prompt"
    if [ -f "$direct" ]; then
        template_id="$(cc_prompt_template_id_for_file "$direct")"
        if [ "$template_id" = "$id" ]; then
            echo "$direct"
            return 0
        fi
    fi

    while IFS= read -r file; do
        [ -n "$file" ] || continue
        template_id="$(cc_prompt_template_id_for_file "$file")"
        if [ "$template_id" = "$id" ]; then
            echo "$file"
            return 0
        fi
    done < <(cc_prompt_template_files)

    _cc_prompt_error "Prompt template not found: $id"
    return 1
}

cc_prompt_template_ids() {
    local file id
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        id="$(cc_prompt_template_id_for_file "$file")"
        [ -n "$id" ] && echo "$id"
    done < <(cc_prompt_template_files)
}

cc_prompt_template_field() {
    local id="$1" field="$2" file
    file="$(cc_prompt_template_path "$id")" || return $?
    cc_prompt_metadata_field "$file" "$field"
}

cc_prompt_template_default_format() {
    local id="$1" format
    format="$(cc_prompt_template_field "$id" "Output")"
    [ -n "$format" ] || format="$(cc_prompt_template_field "$id" "Format")"
    [ -n "$format" ] || format="markdown"
    echo "$format"
}

cc_prompt_template_clipboard_mode() {
    local id="$1" mode
    mode="$(cc_prompt_template_field "$id" "Clipboard")"
    [ -n "$mode" ] || mode="planned"
    echo "$mode"
}

cc_prompt_template_metadata() {
    local id="$1" file version category format clipboard purpose
    file="$(cc_prompt_template_path "$id")" || return $?
    version="$(cc_prompt_metadata_field "$file" "Version")"
    category="$(cc_prompt_metadata_field "$file" "Category")"
    format="$(cc_prompt_template_default_format "$id")"
    clipboard="$(cc_prompt_template_clipboard_mode "$id")"
    purpose="$(cc_prompt_metadata_field "$file" "Purpose")"

    [ -n "$version" ] || version="unknown"
    [ -n "$category" ] || category="Prompt"
    [ -n "$purpose" ] || purpose="unknown"

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$version" "$category" "$format" "$clipboard" "$purpose"
}

cc_prompt_template_catalog() {
    local id
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        cc_prompt_template_metadata "$id"
    done < <(cc_prompt_template_ids)
}

cc_prompt_template_section() {
    local id="$1" section="$2" file
    file="$(cc_prompt_template_path "$id")" || return $?
    awk -v section="[$section]" '
        $0 == section {inside=1; next}
        inside && $0 ~ /^\[[A-Za-z0-9_-]+\]$/ {exit}
        inside {print}
    ' "$file"
}

cc_prompt_template_body() {
    cc_prompt_template_section "$1" "template"
}

cc_prompt_question_rows() {
    local id="$1" rows
    rows="$(cc_prompt_template_section "$id" "questions")" || return $?
    printf '%s\n' "$rows" | awk -F'|' '
        /^[[:space:]]*$/ {next}
        /^[[:space:]]*#/ {next}
        NF < 4 {
            print "Invalid prompt question row: " $0 > "/dev/stderr"
            bad=1
            next
        }
        {
            for (i = 1; i <= 6; i++) {
                gsub(/^[ \t]+/, "", $i)
                gsub(/[ \t]+$/, "", $i)
            }
            printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4, $5, $6
        }
        END {exit bad}
    '
}

cc_prompt_question_names() {
    local id="$1"
    cc_prompt_question_rows "$id" | awk -F'\t' '{print $1}'
}

cc_prompt_question_defined() {
    local id="$1" name="$2" question
    while IFS= read -r question; do
        [ "$question" = "$name" ] && return 0
    done < <(cc_prompt_question_names "$id")
    return 1
}

cc_prompt_template_variables() {
    local id="$1" body
    body="$(cc_prompt_template_body "$id")" || return $?
    printf '%s\n' "$body" | awk '
        {
            line = $0
            while (match(line, /\{\{[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\}\}/)) {
                token = substr(line, RSTART, RLENGTH)
                gsub(/^\{\{[[:space:]]*/, "", token)
                gsub(/[[:space:]]*\}\}$/, "", token)
                if (!(token in seen)) {
                    seen[token] = 1
                    print token
                }
                line = substr(line, RSTART + RLENGTH)
            }
        }
    '
}

cc_prompt_assignment_valid() {
    local assignment="${1:-}" name
    case "$assignment" in
        *=*) ;;
        *)
            _cc_prompt_error "Invalid prompt variable assignment: $assignment"
            return 2
            ;;
    esac

    name="${assignment%%=*}"
    if ! cc_prompt_variable_valid "$name"; then
        _cc_prompt_error "Invalid prompt variable name: $name"
        return 2
    fi
}

cc_prompt_assignments_validate() {
    local assignment
    for assignment in "$@"; do
        cc_prompt_assignment_valid "$assignment" || return $?
    done
}

cc_prompt_variable_defined() {
    local name="$1" assignment
    shift || true
    for assignment in "$@"; do
        case "$assignment" in
            "$name"=*) return 0 ;;
        esac
    done
    return 1
}

cc_prompt_variable_value_for() {
    local name="$1" assignment
    shift || true
    for assignment in "$@"; do
        case "$assignment" in
            "$name"=*)
                printf '%s' "${assignment#*=}"
                return 0
                ;;
        esac
    done
    return 1
}

cc_prompt_missing_variables() {
    local id="$1" name
    shift || true
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        if ! cc_prompt_variable_defined "$name" "$@"; then
            echo "$name"
        fi
    done < <(cc_prompt_template_variables "$id")
}

cc_prompt_substitute() {
    local assignments=("$@")
    local line token name value guard

    while IFS= read -r line || [ -n "$line" ]; do
        guard=0
        while [[ "$line" =~ \{\{[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\}\} ]]; do
            token="${BASH_REMATCH[0]}"
            name="${BASH_REMATCH[1]}"
            if ! value="$(cc_prompt_variable_value_for "$name" "${assignments[@]}")"; then
                value="$token"
            fi
            line="${line/"$token"/$value}"
            guard=$((guard + 1))
            if [ "$guard" -gt 200 ]; then
                _cc_prompt_error "Prompt substitution exceeded safety limit."
                return 2
            fi
        done
        printf '%s\n' "$line"
    done
}

cc_prompt_render() {
    local id missing="" name body

    if [ "$#" -lt 1 ]; then
        _cc_prompt_error "Missing prompt template id."
        return 2
    fi

    id="$1"
    shift

    cc_prompt_template_path "$id" >/dev/null || return $?
    cc_prompt_assignments_validate "$@" || return $?

    while IFS= read -r name; do
        [ -n "$name" ] || continue
        missing="${missing}${missing:+ }$name"
    done < <(cc_prompt_missing_variables "$id" "$@")

    if [ -n "$missing" ]; then
        _cc_prompt_error "Missing prompt variables for $id: $missing"
        return 2
    fi

    body="$(cc_prompt_template_body "$id")" || return $?
    printf '%s\n' "$body" | cc_prompt_substitute "$@"
}

cc_prompt_output_format_supported() {
    case "${1:-}" in
        markdown|raw|terminal) return 0 ;;
        *) return 1 ;;
    esac
}

cc_prompt_format_output() {
    local format="${1:-markdown}" id="${2:-prompt}"

    case "$format" in
        markdown|raw)
            cat
            ;;
        terminal)
            printf 'Prompt Template: %s\n' "$id"
            printf '%s\n\n' "----------------"
            cat
            ;;
        *)
            _cc_prompt_error "Unsupported prompt output format: $format"
            return 2
            ;;
    esac
}

cc_prompt_render_formatted() {
    local id format rendered

    if [ "$#" -lt 2 ]; then
        _cc_prompt_error "Usage: cc_prompt_render_formatted TEMPLATE_ID FORMAT name=value ..."
        return 2
    fi

    id="$1"
    format="$2"
    shift 2

    if ! cc_prompt_output_format_supported "$format"; then
        _cc_prompt_error "Unsupported prompt output format: $format"
        return 2
    fi

    rendered="$(cc_prompt_render "$id" "$@")" || return $?
    printf '%s\n' "$rendered" | cc_prompt_format_output "$format" "$id"
}

cc_prompt_questions_validate() {
    local id="$1" rows name type required prompt default help issues=0

    if ! rows="$(cc_prompt_question_rows "$id")"; then
        return 1
    fi

    while IFS=$'\t' read -r name type required prompt default help; do
        [ -n "$name" ] || continue
        if ! cc_prompt_variable_valid "$name"; then
            _cc_prompt_error "Invalid question variable in $id: $name"
            issues=$((issues + 1))
        fi
        case "$type" in
            text|textarea|select|confirm) ;;
            *)
                _cc_prompt_error "Invalid question type in $id for $name: $type"
                issues=$((issues + 1))
                ;;
        esac
        case "$required" in
            yes|no) ;;
            *)
                _cc_prompt_error "Invalid required flag in $id for $name: $required"
                issues=$((issues + 1))
                ;;
        esac
        [ -n "$prompt" ] || {
            _cc_prompt_error "Missing question prompt in $id for $name"
            issues=$((issues + 1))
        }
    done <<< "$rows"

    [ "$issues" -eq 0 ]
}

cc_prompt_template_validate() {
    local id="$1" file template_id format variable body issues=0

    file="$(cc_prompt_template_path "$id")" || return $?
    template_id="$(cc_prompt_template_id_for_file "$file")"
    format="$(cc_prompt_template_default_format "$id")"

    if ! cc_prompt_template_id_valid "$template_id"; then
        _cc_prompt_error "Invalid template id in $file: $template_id"
        issues=$((issues + 1))
    fi

    if ! cc_prompt_output_format_supported "$format"; then
        _cc_prompt_error "Invalid output format in $id: $format"
        issues=$((issues + 1))
    fi

    body="$(cc_prompt_template_body "$id")" || {
        issues=$((issues + 1))
        body=""
    }

    if ! printf '%s\n' "$body" | awk 'NF {found=1} END {exit found ? 0 : 1}'; then
        _cc_prompt_error "Missing [template] body in prompt template: $id"
        issues=$((issues + 1))
    fi

    cc_prompt_questions_validate "$id" || issues=$((issues + 1))

    while IFS= read -r variable; do
        [ -n "$variable" ] || continue
        if ! cc_prompt_question_defined "$id" "$variable"; then
            _cc_prompt_error "Template variable in $id has no question definition: $variable"
            issues=$((issues + 1))
        fi
    done < <(cc_prompt_template_variables "$id")

    [ "$issues" -eq 0 ]
}

cc_prompt_validate_templates() {
    local id seen=0 issues=0
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        seen=$((seen + 1))
        cc_prompt_template_validate "$id" || issues=$((issues + 1))
    done < <(cc_prompt_template_ids)
    if [ "$seen" -eq 0 ]; then
        _cc_prompt_error "No prompt templates were discovered."
        issues=$((issues + 1))
    fi
    [ "$issues" -eq 0 ]
}

cc_prompt_clipboard_available() {
    return 1
}

cc_prompt_clipboard_design_note() {
    echo "Clipboard support is reserved for future cc prompt commands and is not implemented by this internal engine."
}
