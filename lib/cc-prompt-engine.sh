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

if [ -z "${CC_CONTEXT_LOADED:-}" ]; then
    _cc_prompt_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_prompt_lib_dir/cc-context.sh"
    cc_context_init "${TOOLKIT_ROOT:-${PROJECT_ROOT:-}}" "${CURRENT_REPO:-${PWD:-$(pwd)}}"
    unset _cc_prompt_lib_dir
fi

if [ -z "${CC_DATA_LOADED:-}" ]; then
    _cc_prompt_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_prompt_lib_dir/cc-data.sh"
    unset _cc_prompt_lib_dir
fi

_cc_prompt_error() {
    if command -v cc_error >/dev/null 2>&1; then
        cc_error "$@"
    else
        echo "[CC ERROR] $*" >&2
    fi
}

_cc_prompt_lower() {
    printf '%s' "${1,,}"
}

_cc_prompt_trim() {
    local value="${1:-}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

_cc_prompt_tsv_field() {
    local row="$1" field="$2"
    printf '%s\n' "$row" | awk -F '\t' -v field="$field" '{print $field}'
}

cc_prompt_engine_loaded() {
    command -v cc_prompt_template_path >/dev/null 2>&1 && \
    command -v cc_prompt_render >/dev/null 2>&1 && \
    command -v cc_prompt_question_rows >/dev/null 2>&1 && \
    command -v cc_prompt_session_start >/dev/null 2>&1 && \
    command -v cc_prompt_validate_answer >/dev/null 2>&1
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
        BEGIN {
            wanted = tolower(field)
        }
        /^# [A-Za-z][A-Za-z0-9_-]*[[:space:]]*:/ {
            line = $0
            sub(/^# /, "", line)
            key = line
            sub(/[[:space:]]*:.*/, "", key)
            value = line
            sub(/^[^:]*:[[:space:]]*/, "", value)
            if (tolower(key) == wanted) {
                print value
                exit
            }
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

cc_prompt_required_metadata_fields() {
    printf '%s\n' Title Description Version Category Author Tags
}

cc_prompt_template_title() {
    cc_prompt_template_field "$1" "Title"
}

cc_prompt_template_description() {
    cc_prompt_template_field "$1" "Description"
}

cc_prompt_template_tags() {
    cc_prompt_template_field "$1" "Tags"
}

cc_prompt_template_author() {
    cc_prompt_template_field "$1" "Author"
}

cc_prompt_template_validation() {
    cc_prompt_template_field "$1" "Validation"
}

cc_prompt_template_default() {
    cc_prompt_template_field "$1" "Default"
}

cc_prompt_template_examples() {
    cc_prompt_template_field "$1" "Examples"
}

cc_prompt_template_menu_order() {
    local id="$1" order
    order="$(cc_prompt_template_field "$id" "Order")" || return $?
    if [[ "$order" =~ ^[0-9]+$ ]]; then
        echo "$order"
    else
        echo "9999"
    fi
}

cc_prompt_template_menu_row() {
    local id="$1" title description category tags

    title="$(cc_prompt_template_title "$id")" || return $?
    description="$(cc_prompt_template_description "$id")" || return $?
    category="$(cc_prompt_template_field "$id" "Category")" || return $?
    tags="$(cc_prompt_template_tags "$id")" || return $?

    printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$title" "$description" "$category" "$tags"
}

cc_prompt_template_menu_catalog() {
    local id order
    {
        while IFS= read -r id; do
            [ -n "$id" ] || continue
            order="$(cc_prompt_template_menu_order "$id")" || return $?
            printf '%06d\t' "$order"
            cc_prompt_template_menu_row "$id"
        done < <(cc_prompt_template_ids)
    } | sort -t $'\t' -k1,1n -k3,3 | awk -F '\t' '
        {
            for (i = 2; i <= NF; i++) {
                printf "%s%s", (i > 2 ? FS : ""), $i
            }
            printf "\n"
        }
    '
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
    local id="$1" file version category author tags validation default examples format clipboard purpose
    file="$(cc_prompt_template_path "$id")" || return $?
    version="$(cc_prompt_metadata_field "$file" "Version")"
    category="$(cc_prompt_metadata_field "$file" "Category")"
    author="$(cc_prompt_metadata_field "$file" "Author")"
    tags="$(cc_prompt_metadata_field "$file" "Tags")"
    validation="$(cc_prompt_metadata_field "$file" "Validation")"
    default="$(cc_prompt_metadata_field "$file" "Default")"
    examples="$(cc_prompt_metadata_field "$file" "Examples")"
    format="$(cc_prompt_template_default_format "$id")"
    clipboard="$(cc_prompt_template_clipboard_mode "$id")"
    purpose="$(cc_prompt_metadata_field "$file" "Purpose")"

    [ -n "$version" ] || version="unknown"
    [ -n "$category" ] || category="Prompt"
    [ -n "$author" ] || author="unknown"
    [ -n "$tags" ] || tags="unknown"
    [ -n "$validation" ] || validation="question-rules"
    [ -n "$default" ] || default="none"
    [ -n "$examples" ] || examples="none"
    [ -n "$purpose" ] || purpose="unknown"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$id" "$version" "$category" "$author" "$tags" "$validation" \
        "$default" "$examples" "$format" "$clipboard" "$purpose"
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
            for (i = 1; i <= 8; i++) {
                gsub(/^[ \t]+/, "", $i)
                gsub(/[ \t]+$/, "", $i)
            }
            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4, $5, $6, $7, $8
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

cc_prompt_question_row() {
    local id="$1" name="$2" row row_name
    while IFS= read -r row; do
        [ -n "$row" ] || continue
        row_name="$(_cc_prompt_tsv_field "$row" 1)"
        if [ "$row_name" = "$name" ]; then
            printf '%s\n' "$row"
            return 0
        fi
    done < <(cc_prompt_question_rows "$id")
    return 1
}

cc_prompt_question_field() {
    local id="$1" name="$2" field="$3" row
    row="$(cc_prompt_question_row "$id" "$name")" || return $?
    _cc_prompt_tsv_field "$row" "$field"
}

cc_prompt_question_type() {
    cc_prompt_question_field "$1" "$2" 2
}

cc_prompt_question_required() {
    cc_prompt_question_field "$1" "$2" 3
}

cc_prompt_question_prompt() {
    cc_prompt_question_field "$1" "$2" 4
}

cc_prompt_question_default() {
    cc_prompt_question_field "$1" "$2" 5
}

cc_prompt_question_help() {
    cc_prompt_question_field "$1" "$2" 6
}

cc_prompt_question_validation() {
    cc_prompt_question_field "$1" "$2" 7
}

cc_prompt_question_examples() {
    cc_prompt_question_field "$1" "$2" 8
}

cc_prompt_validation_rows() {
    local id="$1" rows
    rows="$(cc_prompt_template_section "$id" "validation")" || return $?
    printf '%s\n' "$rows" | awk -F'|' '
        /^[[:space:]]*$/ {next}
        /^[[:space:]]*#/ {next}
        NF < 2 {
            print "Invalid prompt validation row: " $0 > "/dev/stderr"
            bad=1
            next
        }
        {
            for (i = 1; i <= 4; i++) {
                gsub(/^[ \t]+/, "", $i)
                gsub(/[ \t]+$/, "", $i)
            }
            printf "%s\t%s\t%s\t%s\n", $1, $2, $3, $4
        }
        END {exit bad}
    '
}

cc_prompt_validation_rows_for() {
    local id="$1" name="$2" row row_name
    while IFS= read -r row; do
        [ -n "$row" ] || continue
        row_name="$(_cc_prompt_tsv_field "$row" 1)"
        [ "$row_name" = "$name" ] && printf '%s\n' "$row"
    done < <(cc_prompt_validation_rows "$id")
}

cc_prompt_validation_rule_supported() {
    case "$(_cc_prompt_lower "${1:-}")" in
        required|optional|regex|enum|choices|range|numeric|number|path|exists|file|dir|validator|custom) return 0 ;;
        *) return 1 ;;
    esac
}

_cc_prompt_regex_valid() {
    local pattern="(${1})|.*"
    [[ "" =~ $pattern ]]
}

_cc_prompt_numeric() {
    [[ "${1:-}" =~ ^-?[0-9]+([.][0-9]+)?$ ]]
}

_cc_prompt_range_parse() {
    local spec="$1"

    if [[ "$spec" =~ ^(-?[0-9]+([.][0-9]+)?)\.\.(-?[0-9]+([.][0-9]+)?)$ ]]; then
        printf '%s\t%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[3]}"
        return 0
    fi

    if [[ "$spec" =~ ^(-?[0-9]+([.][0-9]+)?):(-?[0-9]+([.][0-9]+)?)$ ]]; then
        printf '%s\t%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[3]}"
        return 0
    fi

    if [[ "$spec" =~ ^(-?[0-9]+([.][0-9]+)?),(-?[0-9]+([.][0-9]+)?)$ ]]; then
        printf '%s\t%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[3]}"
        return 0
    fi

    return 1
}

_cc_prompt_range_valid() {
    local spec="$1" bounds min max
    bounds="$(_cc_prompt_range_parse "$spec")" || return 1
    min="${bounds%%$'\t'*}"
    max="${bounds#*$'\t'}"
    awk -v min="$min" -v max="$max" 'BEGIN {exit (min + 0 <= max + 0) ? 0 : 1}'
}

_cc_prompt_value_in_enum() {
    local value="$1" choices="$2" choice
    local -a parts=()

    IFS=',' read -r -a parts <<< "$choices"
    for choice in "${parts[@]}"; do
        choice="$(_cc_prompt_trim "$choice")"
        [ "$value" = "$choice" ] && return 0
    done

    return 1
}

_cc_prompt_path_mode_valid() {
    case "$(_cc_prompt_lower "${1:-exists}")" in
        exists|path|file|dir|directory|readable|writable|executable|missing) return 0 ;;
        *) return 1 ;;
    esac
}

cc_prompt_validation_rule_validate() {
    local id="$1" name="$2" rule="$3" argument="${4:-}" normalized
    normalized="$(_cc_prompt_lower "$rule")"

    if ! cc_prompt_validation_rule_supported "$normalized"; then
        _cc_prompt_error "Unsupported validation rule in $id for $name: $rule"
        return 1
    fi

    case "$normalized" in
        regex)
            if [ -z "$argument" ] || ! _cc_prompt_regex_valid "$argument"; then
                _cc_prompt_error "Invalid regex validation in $id for $name: $argument"
                return 1
            fi
            ;;
        enum|choices)
            if [ -z "$argument" ]; then
                _cc_prompt_error "Empty choices validation in $id for $name"
                return 1
            fi
            ;;
        range|numeric|number)
            if ! _cc_prompt_range_valid "$argument"; then
                _cc_prompt_error "Invalid numeric range in $id for $name: $argument"
                return 1
            fi
            ;;
        path|exists|file|dir)
            if ! _cc_prompt_path_mode_valid "${argument:-$normalized}"; then
                _cc_prompt_error "Invalid path validation mode in $id for $name: $argument"
                return 1
            fi
            ;;
        validator|custom)
            if ! cc_prompt_variable_valid "$argument"; then
                _cc_prompt_error "Invalid custom validator hook in $id for $name: $argument"
                return 1
            fi
            ;;
    esac
}

cc_prompt_validation_spec_rows() {
    local spec="${1:-}" token rule argument
    local -a tokens=()

    [ -n "$spec" ] || return 0
    IFS=';' read -r -a tokens <<< "$spec"
    for token in "${tokens[@]}"; do
        token="$(_cc_prompt_trim "$token")"
        [ -n "$token" ] || continue
        if [[ "$token" == *"="* ]]; then
            rule="$(_cc_prompt_trim "${token%%=*}")"
            argument="$(_cc_prompt_trim "${token#*=}")"
        elif [[ "$token" == *":"* ]]; then
            rule="$(_cc_prompt_trim "${token%%:*}")"
            argument="$(_cc_prompt_trim "${token#*:}")"
        else
            rule="$token"
            argument=""
        fi
        printf '%s\t%s\n' "$rule" "$argument"
    done
}

cc_prompt_question_choices() {
    local id="$1" name="$2" spec row rule argument

    spec="$(cc_prompt_question_validation "$id" "$name" 2>/dev/null || true)"
    while IFS= read -r row; do
        rule="$(_cc_prompt_tsv_field "$row" 1)"
        argument="$(_cc_prompt_tsv_field "$row" 2)"
        [ -n "$rule" ] || continue
        case "$(_cc_prompt_lower "$rule")" in
            enum|choices)
                printf '%s\n' "$argument"
                return 0
                ;;
        esac
    done < <(cc_prompt_validation_spec_rows "$spec")

    while IFS= read -r row; do
        rule="$(_cc_prompt_tsv_field "$row" 2)"
        argument="$(_cc_prompt_tsv_field "$row" 3)"
        [ -n "$rule" ] || continue
        case "$(_cc_prompt_lower "$rule")" in
            enum|choices)
                printf '%s\n' "$argument"
                return 0
                ;;
        esac
    done < <(cc_prompt_validation_rows_for "$id" "$name")
}

cc_prompt_validation_error() {
    local name="$1" message="$2"
    if [ -n "$message" ]; then
        _cc_prompt_error "$message"
    else
        _cc_prompt_error "Invalid answer for $name."
    fi
}

cc_prompt_validation_apply_rule() {
    local id="$1" name="$2" value="$3" rule="$4" argument="${5:-}" message="${6:-}"
    local normalized bounds min max mode hook

    normalized="$(_cc_prompt_lower "$rule")"

    case "$normalized" in
        required)
            if [ -z "$value" ]; then
                cc_prompt_validation_error "$name" "${message:-$name is required.}"
                return 1
            fi
            ;;
        optional)
            return 0
            ;;
        regex)
            if ! [[ "$value" =~ $argument ]]; then
                cc_prompt_validation_error "$name" "${message:-$name must match regex: $argument}"
                return 1
            fi
            ;;
        enum|choices)
            if ! _cc_prompt_value_in_enum "$value" "$argument"; then
                cc_prompt_validation_error "$name" "${message:-$name must be one of: $argument}"
                return 1
            fi
            ;;
        range|numeric|number)
            bounds="$(_cc_prompt_range_parse "$argument")" || {
                cc_prompt_validation_error "$name" "${message:-Invalid numeric range for $name: $argument}"
                return 1
            }
            min="${bounds%%$'\t'*}"
            max="${bounds#*$'\t'}"
            if ! _cc_prompt_numeric "$value"; then
                cc_prompt_validation_error "$name" "${message:-$name must be numeric.}"
                return 1
            fi
            if ! awk -v value="$value" -v min="$min" -v max="$max" 'BEGIN {exit (value + 0 >= min + 0 && value + 0 <= max + 0) ? 0 : 1}'; then
                cc_prompt_validation_error "$name" "${message:-$name must be between $min and $max.}"
                return 1
            fi
            ;;
        path|exists|file|dir)
            mode="$(_cc_prompt_lower "${argument:-$normalized}")"
            case "$mode" in
                exists|path) [ -e "$value" ] ;;
                file) [ -f "$value" ] ;;
                dir|directory) [ -d "$value" ] ;;
                readable) [ -r "$value" ] ;;
                writable) [ -w "$value" ] ;;
                executable) [ -x "$value" ] ;;
                missing) [ ! -e "$value" ] ;;
                *) false ;;
            esac || {
                cc_prompt_validation_error "$name" "${message:-$name must reference a $mode path: $value}"
                return 1
            }
            ;;
        validator|custom)
            hook="$argument"
            if ! command -v "$hook" >/dev/null 2>&1; then
                cc_prompt_validation_error "$name" "${message:-Custom validator is not available: $hook}"
                return 1
            fi
            "$hook" "$id" "$name" "$value" || {
                cc_prompt_validation_error "$name" "$message"
                return 1
            }
            ;;
        *)
            cc_prompt_validation_error "$name" "Unsupported validation rule for $name: $rule"
            return 1
            ;;
    esac
}

cc_prompt_validate_answer_type() {
    local id="$1" name="$2" value="$3" type choices
    type="$(cc_prompt_question_type "$id" "$name")" || return $?

    case "$type" in
        text|textarea) return 0 ;;
        confirm)
            case "$(_cc_prompt_lower "$value")" in
                y|yes|n|no|true|false|1|0) return 0 ;;
                *)
                    _cc_prompt_error "$name must be yes or no."
                    return 1
                    ;;
            esac
            ;;
        select)
            choices="$(cc_prompt_question_choices "$id" "$name")"
            if [ -n "$choices" ] && ! _cc_prompt_value_in_enum "$value" "$choices"; then
                _cc_prompt_error "$name must be one of: $choices"
                return 1
            fi
            ;;
        *)
            _cc_prompt_error "Invalid question type for $name: $type"
            return 1
            ;;
    esac
}

cc_prompt_validate_answer() {
    local id="$1" name="$2" value="${3:-}" required spec row rule argument message

    if ! cc_prompt_question_defined "$id" "$name"; then
        _cc_prompt_error "Unknown prompt question in $id: $name"
        return 1
    fi

    required="$(cc_prompt_question_required "$id" "$name")" || return $?
    spec="$(cc_prompt_question_validation "$id" "$name" 2>/dev/null || true)"

    while IFS= read -r row; do
        rule="$(_cc_prompt_tsv_field "$row" 1)"
        argument="$(_cc_prompt_tsv_field "$row" 2)"
        [ -n "$rule" ] || continue
        case "$(_cc_prompt_lower "$rule")" in
            required) required="yes" ;;
            optional) required="no" ;;
        esac
    done < <(cc_prompt_validation_spec_rows "$spec")

    while IFS= read -r row; do
        rule="$(_cc_prompt_tsv_field "$row" 2)"
        argument="$(_cc_prompt_tsv_field "$row" 3)"
        [ -n "$rule" ] || continue
        case "$(_cc_prompt_lower "$rule")" in
            required) required="yes" ;;
            optional) required="no" ;;
        esac
    done < <(cc_prompt_validation_rows_for "$id" "$name")

    if [ "$required" = "yes" ] && [ -z "$value" ]; then
        _cc_prompt_error "$name is required."
        return 1
    fi

    [ -n "$value" ] || return 0

    cc_prompt_validate_answer_type "$id" "$name" "$value" || return $?

    while IFS= read -r row; do
        rule="$(_cc_prompt_tsv_field "$row" 1)"
        argument="$(_cc_prompt_tsv_field "$row" 2)"
        [ -n "$rule" ] || continue
        case "$(_cc_prompt_lower "$rule")" in
            required|optional) continue ;;
        esac
        cc_prompt_validation_rule_validate "$id" "$name" "$rule" "$argument" || return $?
        cc_prompt_validation_apply_rule "$id" "$name" "$value" "$rule" "$argument" "" || return $?
    done < <(cc_prompt_validation_spec_rows "$spec")

    while IFS= read -r row; do
        rule="$(_cc_prompt_tsv_field "$row" 2)"
        argument="$(_cc_prompt_tsv_field "$row" 3)"
        message="$(_cc_prompt_tsv_field "$row" 4)"
        [ -n "$rule" ] || continue
        case "$(_cc_prompt_lower "$rule")" in
            required|optional) continue ;;
        esac
        cc_prompt_validation_rule_validate "$id" "$name" "$rule" "$argument" || return $?
        cc_prompt_validation_apply_rule "$id" "$name" "$value" "$rule" "$argument" "$message" || return $?
    done < <(cc_prompt_validation_rows_for "$id" "$name")
}

cc_prompt_validate_assignments() {
    local id="$1" name value missing=0
    shift || true

    while IFS= read -r name; do
        [ -n "$name" ] || continue
        value="$(cc_prompt_variable_value_for "$name" "$@" 2>/dev/null || true)"
        cc_prompt_validate_answer "$id" "$name" "$value" || missing=$((missing + 1))
    done < <(cc_prompt_question_names "$id")

    [ "$missing" -eq 0 ]
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

    cc_prompt_validate_assignments "$id" "$@" || return $?

    body="$(cc_prompt_template_body "$id")" || return $?
    printf '%s\n' "$body" | cc_prompt_substitute "$@"
}

cc_prompt_output_format_supported() {
    case "${1:-}" in
        markdown|raw|terminal|clipboard|json) return 0 ;;
        *) return 1 ;;
    esac
}

cc_prompt_output_markdown() {
    cat
}

cc_prompt_output_raw() {
    cat
}

cc_prompt_output_terminal() {
    local id="${1:-prompt}"
    printf 'Prompt Template: %s\n' "$id"
    printf '%s\n\n' "----------------"
    cat
}

cc_prompt_output_clipboard() {
    local rendered
    rendered="$(cat)"
    if printf '%s\n' "$rendered" | cc_prompt_copy_to_clipboard; then
        printf '%s\n' "$rendered"
    else
        _cc_prompt_error "Clipboard output requested, but no clipboard command succeeded."
        return 1
    fi
}

cc_prompt_output_json() {
    local id="${1:-prompt}" rendered
    if ! _cc_json_available; then
        _cc_prompt_error "JSON output requires a compatible configured JSON processor."
        return 1
    fi
    rendered="$(cat)"
    # This is a jq expression, not a shell expression.
    # shellcheck disable=SC2016
    _cc_json_generate \
        '{template: $template, format: "json", content: $content}' \
        --compact-output \
        --arg template "$id" \
        --arg content "$rendered"
}

cc_prompt_format_output() {
    local format="${1:-markdown}" id="${2:-prompt}"

    case "$format" in
        markdown) cc_prompt_output_markdown "$id" ;;
        raw) cc_prompt_output_raw "$id" ;;
        terminal) cc_prompt_output_terminal "$id" ;;
        clipboard) cc_prompt_output_clipboard "$id" ;;
        json) cc_prompt_output_json "$id" ;;
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
    local id="$1" rows row name type required prompt default help validation examples rule argument issues=0

    if ! rows="$(cc_prompt_question_rows "$id")"; then
        return 1
    fi

    while IFS= read -r row; do
        name="$(_cc_prompt_tsv_field "$row" 1)"
        type="$(_cc_prompt_tsv_field "$row" 2)"
        required="$(_cc_prompt_tsv_field "$row" 3)"
        prompt="$(_cc_prompt_tsv_field "$row" 4)"
        default="$(_cc_prompt_tsv_field "$row" 5)"
        help="$(_cc_prompt_tsv_field "$row" 6)"
        validation="$(_cc_prompt_tsv_field "$row" 7)"
        examples="$(_cc_prompt_tsv_field "$row" 8)"
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
        while IFS= read -r row; do
            rule="$(_cc_prompt_tsv_field "$row" 1)"
            argument="$(_cc_prompt_tsv_field "$row" 2)"
            [ -n "$rule" ] || continue
            cc_prompt_validation_rule_validate "$id" "$name" "$rule" "$argument" || issues=$((issues + 1))
        done < <(cc_prompt_validation_spec_rows "$validation")
        if [ -n "$default" ]; then
            cc_prompt_validate_answer "$id" "$name" "$default" || issues=$((issues + 1))
        fi
    done <<< "$rows"

    [ "$issues" -eq 0 ]
}

cc_prompt_validation_section_validate() {
    local id="$1" row name rule argument message issues=0

    while IFS= read -r row; do
        name="$(_cc_prompt_tsv_field "$row" 1)"
        rule="$(_cc_prompt_tsv_field "$row" 2)"
        argument="$(_cc_prompt_tsv_field "$row" 3)"
        message="$(_cc_prompt_tsv_field "$row" 4)"
        [ -n "$name" ] || continue
        if ! cc_prompt_question_defined "$id" "$name"; then
            _cc_prompt_error "Validation rule references unknown question in $id: $name"
            issues=$((issues + 1))
            continue
        fi
        cc_prompt_validation_rule_validate "$id" "$name" "$rule" "$argument" || issues=$((issues + 1))
    done < <(cc_prompt_validation_rows "$id")

    [ "$issues" -eq 0 ]
}

cc_prompt_required_metadata_validate() {
    local id="$1" file field value issues=0

    file="$(cc_prompt_template_path "$id")" || return $?
    while IFS= read -r field; do
        [ -n "$field" ] || continue
        value="$(cc_prompt_metadata_field "$file" "$field")"
        if [ -z "$value" ]; then
            _cc_prompt_error "Missing required metadata in $id: $field"
            issues=$((issues + 1))
        fi
    done < <(cc_prompt_required_metadata_fields)

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

    cc_prompt_required_metadata_validate "$id" || issues=$((issues + 1))

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
    cc_prompt_validation_section_validate "$id" || issues=$((issues + 1))

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

CC_PROMPT_SESSION_TEMPLATE_ID=""
CC_PROMPT_SESSION_TEMPLATE_TITLE=""
CC_PROMPT_SESSION_CURRENT_QUESTION=0
CC_PROMPT_SESSION_CANCELLED=0
declare -a CC_PROMPT_SESSION_NAMES=()
declare -a CC_PROMPT_SESSION_TYPES=()
declare -a CC_PROMPT_SESSION_REQUIRED=()
declare -a CC_PROMPT_SESSION_PROMPTS=()
declare -a CC_PROMPT_SESSION_DEFAULTS=()
declare -a CC_PROMPT_SESSION_HELP=()
declare -a CC_PROMPT_SESSION_VALIDATION=()
declare -a CC_PROMPT_SESSION_EXAMPLES=()
declare -a CC_PROMPT_SESSION_ANSWERS=()

cc_prompt_session_reset() {
    CC_PROMPT_SESSION_TEMPLATE_ID=""
    CC_PROMPT_SESSION_TEMPLATE_TITLE=""
    CC_PROMPT_SESSION_CURRENT_QUESTION=0
    CC_PROMPT_SESSION_CANCELLED=0
    CC_PROMPT_SESSION_NAMES=()
    CC_PROMPT_SESSION_TYPES=()
    CC_PROMPT_SESSION_REQUIRED=()
    CC_PROMPT_SESSION_PROMPTS=()
    CC_PROMPT_SESSION_DEFAULTS=()
    CC_PROMPT_SESSION_HELP=()
    CC_PROMPT_SESSION_VALIDATION=()
    CC_PROMPT_SESSION_EXAMPLES=()
    CC_PROMPT_SESSION_ANSWERS=()
}

cc_prompt_session_start() {
    local id="$1" row name type required prompt default help validation examples

    cc_prompt_session_reset
    cc_prompt_template_path "$id" >/dev/null || return $?

    CC_PROMPT_SESSION_TEMPLATE_ID="$id"
    CC_PROMPT_SESSION_TEMPLATE_TITLE="$(cc_prompt_template_title "$id")"
    CC_PROMPT_SESSION_CURRENT_QUESTION=0
    CC_PROMPT_SESSION_CANCELLED=0

    while IFS= read -r row; do
        name="$(_cc_prompt_tsv_field "$row" 1)"
        type="$(_cc_prompt_tsv_field "$row" 2)"
        required="$(_cc_prompt_tsv_field "$row" 3)"
        prompt="$(_cc_prompt_tsv_field "$row" 4)"
        default="$(_cc_prompt_tsv_field "$row" 5)"
        help="$(_cc_prompt_tsv_field "$row" 6)"
        validation="$(_cc_prompt_tsv_field "$row" 7)"
        examples="$(_cc_prompt_tsv_field "$row" 8)"
        [ -n "$name" ] || continue
        CC_PROMPT_SESSION_NAMES+=("$name")
        CC_PROMPT_SESSION_TYPES+=("$type")
        CC_PROMPT_SESSION_REQUIRED+=("$required")
        CC_PROMPT_SESSION_PROMPTS+=("$prompt")
        CC_PROMPT_SESSION_DEFAULTS+=("$default")
        CC_PROMPT_SESSION_HELP+=("$help")
        CC_PROMPT_SESSION_VALIDATION+=("$validation")
        CC_PROMPT_SESSION_EXAMPLES+=("$examples")
        CC_PROMPT_SESSION_ANSWERS+=("$default")
    done < <(cc_prompt_question_rows "$id")

    if [ "${#CC_PROMPT_SESSION_NAMES[@]}" -eq 0 ]; then
        _cc_prompt_error "No questions defined for prompt template: $id"
        return 1
    fi
}

cc_prompt_session_template() {
    printf '%s\n' "$CC_PROMPT_SESSION_TEMPLATE_ID"
}

cc_prompt_session_template_title() {
    printf '%s\n' "$CC_PROMPT_SESSION_TEMPLATE_TITLE"
}

cc_prompt_session_question_count() {
    printf '%s\n' "${#CC_PROMPT_SESSION_NAMES[@]}"
}

cc_prompt_session_current_question() {
    printf '%s\n' "$CC_PROMPT_SESSION_CURRENT_QUESTION"
}

cc_prompt_session_set_question() {
    local index="$1" count="${#CC_PROMPT_SESSION_NAMES[@]}"

    if ! [[ "$index" =~ ^[0-9]+$ ]]; then
        _cc_prompt_error "Invalid session question index: $index"
        return 2
    fi

    if [ "$index" -lt 0 ] || [ "$index" -gt "$count" ]; then
        _cc_prompt_error "Session question index out of range: $index"
        return 2
    fi

    CC_PROMPT_SESSION_CURRENT_QUESTION="$index"
}

cc_prompt_session_question_field() {
    local index="$1" field="$2"

    if ! [[ "$index" =~ ^[0-9]+$ ]] || [ "$index" -ge "${#CC_PROMPT_SESSION_NAMES[@]}" ]; then
        _cc_prompt_error "Invalid session question index: $index"
        return 2
    fi

    case "$field" in
        name) printf '%s\n' "${CC_PROMPT_SESSION_NAMES[$index]}" ;;
        type) printf '%s\n' "${CC_PROMPT_SESSION_TYPES[$index]}" ;;
        required) printf '%s\n' "${CC_PROMPT_SESSION_REQUIRED[$index]}" ;;
        prompt) printf '%s\n' "${CC_PROMPT_SESSION_PROMPTS[$index]}" ;;
        default) printf '%s\n' "${CC_PROMPT_SESSION_DEFAULTS[$index]}" ;;
        help) printf '%s\n' "${CC_PROMPT_SESSION_HELP[$index]}" ;;
        validation) printf '%s\n' "${CC_PROMPT_SESSION_VALIDATION[$index]}" ;;
        examples) printf '%s\n' "${CC_PROMPT_SESSION_EXAMPLES[$index]}" ;;
        answer) printf '%s\n' "${CC_PROMPT_SESSION_ANSWERS[$index]-}" ;;
        *)
            _cc_prompt_error "Unknown session question field: $field"
            return 2
            ;;
    esac
}

cc_prompt_session_current_question_field() {
    cc_prompt_session_question_field "$CC_PROMPT_SESSION_CURRENT_QUESTION" "$1"
}

cc_prompt_session_answer_get() {
    cc_prompt_session_question_field "$1" answer
}

cc_prompt_session_answer_set() {
    local index="$1" value="${2:-}"

    if ! [[ "$index" =~ ^[0-9]+$ ]] || [ "$index" -ge "${#CC_PROMPT_SESSION_NAMES[@]}" ]; then
        _cc_prompt_error "Invalid session question index: $index"
        return 2
    fi

    CC_PROMPT_SESSION_ANSWERS[index]="$value"
}

cc_prompt_session_current_answer_set() {
    cc_prompt_session_answer_set "$CC_PROMPT_SESSION_CURRENT_QUESTION" "${1:-}"
}

cc_prompt_session_next() {
    local count="${#CC_PROMPT_SESSION_NAMES[@]}"
    if [ "$CC_PROMPT_SESSION_CURRENT_QUESTION" -lt "$count" ]; then
        CC_PROMPT_SESSION_CURRENT_QUESTION=$((CC_PROMPT_SESSION_CURRENT_QUESTION + 1))
        return 0
    fi
    return 1
}

cc_prompt_session_previous() {
    if [ "$CC_PROMPT_SESSION_CURRENT_QUESTION" -gt 0 ]; then
        CC_PROMPT_SESSION_CURRENT_QUESTION=$((CC_PROMPT_SESSION_CURRENT_QUESTION - 1))
        return 0
    fi
    return 1
}

cc_prompt_session_back() {
    cc_prompt_session_previous
}

cc_prompt_session_cancel() {
    CC_PROMPT_SESSION_CANCELLED=1
}

cc_prompt_session_cancelled() {
    [ "$CC_PROMPT_SESSION_CANCELLED" -eq 1 ]
}

cc_prompt_session_complete() {
    [ "$CC_PROMPT_SESSION_CURRENT_QUESTION" -ge "${#CC_PROMPT_SESSION_NAMES[@]}" ]
}

cc_prompt_session_validate_answer() {
    local index="$1" name answer
    name="$(cc_prompt_session_question_field "$index" name)" || return $?
    answer="$(cc_prompt_session_question_field "$index" answer)" || return $?
    cc_prompt_validate_answer "$CC_PROMPT_SESSION_TEMPLATE_ID" "$name" "$answer"
}

cc_prompt_session_validate_current() {
    cc_prompt_session_validate_answer "$CC_PROMPT_SESSION_CURRENT_QUESTION"
}

cc_prompt_session_assignments() {
    local index
    for index in "${!CC_PROMPT_SESSION_NAMES[@]}"; do
        printf '%s=%s\n' "${CC_PROMPT_SESSION_NAMES[$index]}" "${CC_PROMPT_SESSION_ANSWERS[$index]-}"
    done
}

cc_prompt_session_render() {
    local assignment
    local -a vars=()

    while IFS= read -r assignment; do
        vars+=("$assignment")
    done < <(cc_prompt_session_assignments)

    cc_prompt_render "$CC_PROMPT_SESSION_TEMPLATE_ID" "${vars[@]}"
}

cc_prompt_session_render_formatted() {
    local format="${1:-markdown}" rendered
    rendered="$(cc_prompt_session_render)" || return $?
    printf '%s\n' "$rendered" | cc_prompt_format_output "$format" "$CC_PROMPT_SESSION_TEMPLATE_ID"
}

cc_prompt_session_help_text() {
    local index="$1" name help default validation examples choices

    name="$(cc_prompt_session_question_field "$index" name)" || return $?
    help="$(cc_prompt_session_question_field "$index" help)" || return $?
    default="$(cc_prompt_session_question_field "$index" default)" || return $?
    validation="$(cc_prompt_session_question_field "$index" validation)" || return $?
    examples="$(cc_prompt_session_question_field "$index" examples)" || return $?
    choices="$(cc_prompt_question_choices "$CC_PROMPT_SESSION_TEMPLATE_ID" "$name" 2>/dev/null || true)"

    [ -n "$help" ] && printf 'Help: %s\n' "$help"
    [ -n "$default" ] && printf 'Default: %s\n' "$default"
    [ -n "$choices" ] && printf 'Choices: %s\n' "$choices"
    [ -n "$validation" ] && printf 'Validation: %s\n' "$validation"
    [ -n "$examples" ] && printf 'Examples: %s\n' "$examples"
}

cc_prompt_clipboard_available() {
    command -v wl-copy >/dev/null 2>&1 ||
    command -v xclip >/dev/null 2>&1 ||
    command -v xsel >/dev/null 2>&1 ||
    command -v pbcopy >/dev/null 2>&1 ||
    command -v clip.exe >/dev/null 2>&1
}

cc_prompt_clipboard_command() {
    if command -v wl-copy >/dev/null 2>&1; then
        echo "wl-copy"
    elif command -v xclip >/dev/null 2>&1; then
        echo "xclip -selection clipboard"
    elif command -v xsel >/dev/null 2>&1; then
        echo "xsel --clipboard --input"
    elif command -v pbcopy >/dev/null 2>&1; then
        echo "pbcopy"
    elif command -v clip.exe >/dev/null 2>&1; then
        echo "clip.exe"
    else
        return 1
    fi
}

cc_prompt_copy_to_clipboard() {
    if command -v wl-copy >/dev/null 2>&1; then
        wl-copy
    elif command -v xclip >/dev/null 2>&1; then
        xclip -selection clipboard
    elif command -v xsel >/dev/null 2>&1; then
        xsel --clipboard --input
    elif command -v pbcopy >/dev/null 2>&1; then
        pbcopy
    elif command -v clip.exe >/dev/null 2>&1; then
        clip.exe
    else
        return 1
    fi
}

cc_prompt_clipboard_design_note() {
    if cc_prompt_clipboard_available; then
        printf 'Clipboard support available through: %s\n' "$(cc_prompt_clipboard_command)"
    else
        echo "Clipboard support is unavailable on this host."
    fi
}
