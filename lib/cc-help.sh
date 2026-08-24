#!/usr/bin/env bash
# Shared contextual help, discovery, and dispatcher contract validation.

cc_help_context_usage() {
    local context="$1" command_name="${1%%/*}" subcommand row usage
    if [ "$context" = "$command_name" ]; then
        row="$(cc_contract_command_row "$command_name")"
        IFS='|' read -r _ _ usage _ _ <<< "$row"
        printf '%s\n' "$usage"
        return
    fi
    subcommand="${context#*/}"
    row="$(cc_contract_subcommands | awk -F '|' -v target="$context" '$4 == target { print; exit }')"
    IFS='|' read -r _ _ _ _ <<< "$row"
    printf 'cc %s %s [switches]\n' "$command_name" "$subcommand"
}

cc_help_context_description() {
    local context="$1" command_name="${1%%/*}" row description
    if [ "$context" = "$command_name" ]; then
        row="$(cc_contract_command_row "$command_name")"
        IFS='|' read -r _ _ _ description _ <<< "$row"
    else
        row="$(cc_contract_subcommands | awk -F '|' -v target="$context" '$4 == target { print; exit }')"
        IFS='|' read -r _ _ description _ <<< "$row"
    fi
    printf '%s\n' "$description"
}

cc_help_switch_rows() {
    local context="$1" command_name="${1%%/*}" delegated=""
    case "$context" in
        storage/inventory) delegated=drive-inventory ;;
        storage/drives) delegated=drives ;;
        storage/smart) delegated=drive-smart ;;
        storage/test) delegated=drive-test ;;
        storage/report) delegated=drive-report ;;
        storage/qualify) delegated=drive-qualify ;;
        storage/burnin) delegated=drive-burnin ;;
        storage/workbench) delegated=workbench ;;
    esac
    cc_contract_switches | awk -F '|' -v context="$context" -v delegated="$delegated" \
        '$1 == context || $1 == delegated'
}

cc_help_render_switches() {
    local context="$1" command_name="${1%%/*}" label arity description row
    local max_label=0 width count=0
    local -a labels=() descriptions=()

    while IFS='|' read -r _ label arity description; do
        [ -n "$label" ] || continue
        labels+=("$label")
        descriptions+=("$description")
        [ "${#label}" -le "$max_label" ] || max_label=${#label}
        count=$((count + 1))
    done < <(cc_help_switch_rows "$context")
    labels+=("--help, -h")
    descriptions+=("Show contextual command help.")
    if [ "$context" = "$command_name" ]; then
        labels+=("--version")
        descriptions+=("Show toolkit version information.")
    fi
    [ 10 -le "$max_label" ] || max_label=10
    width=$((max_label + 8))

    printf 'Command: cc %s' "$command_name"
    [ "$context" = "$command_name" ] || printf ' %s' "${context#*/}"
    printf '\n\nUsage:\n  '
    cc_help_context_usage "$context"
    printf '\n'
    cc_help_context_description "$context"
    printf '\nSwitches:\n'
    if [ "$count" -eq 0 ]; then
        printf '  No command-specific switches.\n'
    fi
    local index
    for index in "${!labels[@]}"; do
        printf '  '
        cc_dotted_line "${labels[$index]}" "${descriptions[$index]}" "$width"
    done

    if [ "$context" = "$command_name" ] && cc_contract_subcommands | awk -F '|' -v command_name="$command_name" '$1 == command_name { found=1 } END { exit !found }'; then
        local subcommand sub_description target max_sub=0
        local -a subcommands=() sub_descriptions=()
        while IFS='|' read -r _ subcommand sub_description target; do
            subcommands+=("$subcommand")
            sub_descriptions+=("$sub_description")
            [ "${#subcommand}" -le "$max_sub" ] || max_sub=${#subcommand}
        done < <(cc_contract_subcommands | awk -F '|' -v command_name="$command_name" '$1 == command_name')
        printf '\nSubcommands:\n'
        width=$((max_sub + 8))
        for index in "${!subcommands[@]}"; do
            printf '  '
            cc_dotted_line "${subcommands[$index]}" "${sub_descriptions[$index]}" "$width"
        done
        printf '\nDiscovery:\n  cc %s <subcommand> switches\n' "$command_name"
    fi
}

cc_help_resolve_context() {
    local command_name="$1"
    shift
    local token row target arity index=0
    local -a args=("$@")
    while [ "$index" -lt "${#args[@]}" ]; do
        token="${args[$index]}"
        if [[ "$token" == -* ]]; then
            arity="$(cc_help_switch_match "$command_name" "$token" 2>/dev/null || true)"
            if [ "$arity" = 1 ] && [[ "$token" != *=* ]]; then index=$((index + 1)); fi
            index=$((index + 1))
            continue
        fi
        row="$(cc_contract_subcommand_row "$command_name" "$token")"
        if [ -n "$row" ]; then
            IFS='|' read -r _ _ _ target <<< "$row"
            printf '%s\n' "$target"
            return
        fi
        break
    done
    printf '%s\n' "$command_name"
}

cc_help_switch_match() {
    local context="$1" token="$2" row labels arity label switch_name
    while IFS='|' read -r _ labels arity _; do
        IFS=',' read -r -a _cc_labels <<< "$labels"
        for label in "${_cc_labels[@]}"; do
            label="${label# }"
            switch_name="${label%% *}"
            if [ "$token" = "$switch_name" ] || \
                { [ "$context" = repos ] && [ "$switch_name" = --message ] && [[ "$token" == --message=* ]]; }; then
                printf '%s\n' "$arity"
                return 0
            fi
        done
    done < <(cc_help_switch_rows "$context")
    if [ "$context" != "${context%%/*}" ]; then
        while IFS='|' read -r _ labels arity _; do
            IFS=',' read -r -a _cc_labels <<< "$labels"
            for label in "${_cc_labels[@]}"; do
                label="${label# }"
                switch_name="${label%% *}"
                if [ "$token" = "$switch_name" ] || \
                    { [ "${context%%/*}" = repos ] && [ "$switch_name" = --message ] && [[ "$token" == --message=* ]]; }; then
                    printf '%s\n' "$arity"
                    return 0
                fi
            done
        done < <(cc_help_switch_rows "${context%%/*}")
    fi
    case "$token" in
        --help|-h) printf '0\n'; return 0 ;;
        --version) [ "$context" = "${context%%/*}" ] && { printf '0\n'; return 0; } ;;
    esac
    return 1
}

cc_help_context_error() {
    local context="$1"
    shift
    cc_error "$*"
    printf '\n' >&2
    cc_help_render_switches "$context" >&2
    return 2
}

cc_help_dispatch_preflight() {
    local command_name="$1"
    shift
    local context row class usage description positional token arity index=0 subrow target
    local -a args=("$@")
    context="$(cc_help_resolve_context "$command_name" "$@")"
    row="$(cc_contract_command_row "$command_name")"
    IFS='|' read -r _ class usage description positional <<< "$row"

    # Namespace discovery and unknown-subcommand diagnostics use the first
    # positional token after skipping recognized option values.
    if [[ "$class" == namespace* ]] && [ "$positional" = namespace ]; then
        index=0
        while [ "$index" -lt "${#args[@]}" ]; do
            token="${args[$index]}"
            if [[ "$token" == -* ]]; then
                arity="$(cc_help_switch_match "$context" "$token" 2>/dev/null || true)"
                if [ "$arity" = 1 ] && [[ "$token" != *=* ]]; then index=$((index + 1)); fi
            elif [ "$token" != switches ]; then
                subrow="$(cc_contract_subcommand_row "$command_name" "$token")"
                if [ -z "$subrow" ]; then
                    cc_help_context_error "$command_name" "Unknown subcommand: $token"
                    return 2
                fi
                break
            fi
            index=$((index + 1))
        done
    fi

    index=0
    while [ "$index" -lt "${#args[@]}" ]; do
        token="${args[$index]}"
        if [[ "$token" == -* ]]; then
            arity="$(cc_help_switch_match "$context" "$token" 2>/dev/null || true)"
            if [ -z "$arity" ]; then
                cc_help_context_error "$context" "Unknown switch: $token"
                return 2
            fi
            if [ "$arity" -eq 1 ] && [[ "$token" != *=* ]]; then
                if [ $((index + 1)) -ge "${#args[@]}" ] || [[ "${args[$((index + 1))]}" == -* ]]; then
                    cc_help_context_error "$context" "Missing value for switch: $token"
                    return 2
                fi
                index=$((index + 1))
            elif [ "$arity" -eq 1 ] && [[ "$token" == *= ]]; then
                cc_help_context_error "$context" "Missing value for switch: ${token%%=*}"
                return 2
            fi
        fi
        index=$((index + 1))
    done

    # Flat commands declared without positional operands reject stray values.
    # Namespace subcommands retain their command-owned operand validation except
    # for the explicitly argument-free diagnostic contexts below.
    if [ "$positional" = none ] || [[ "$context" =~ ^(env/(summary|path|shell|host|doctor)|kernel/(status|list|running|platform|artifacts|health|deps)|docs/(build|inventory|reference|changelog|lint|check))$ ]]; then
        index=0
        while [ "$index" -lt "${#args[@]}" ]; do
            token="${args[$index]}"
            case "$token" in
                -*)
                    arity="$(cc_help_switch_match "$context" "$token" 2>/dev/null || true)"
                    if [ "$arity" = 1 ] && [[ "$token" != *=* ]]; then index=$((index + 1)); fi
                    ;;
                "${context#*/}") ;;
                *)
                    cc_help_context_error "$context" "Unknown positional argument: $token"
                    return 2
                    ;;
            esac
            index=$((index + 1))
        done
    fi
}
