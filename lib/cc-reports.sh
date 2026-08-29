#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-reports.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash find stat date sort readlink rm rmdir awk sed id
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Inventory, classify, plan, and safely prune persistent reports.
# ==============================================================================

# Public result arrays and counters are consumed by commands after library calls.
# shellcheck disable=SC2034

if ! declare -F cc_retention_report_family_catalog >/dev/null 2>&1; then
    _cc_reports_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_reports_lib_dir/cc-retention.sh"
    unset _cc_reports_lib_dir
fi

declare -ag CC_REPORT_ITEM_FAMILY=()
declare -ag CC_REPORT_ITEM_PATH=()
declare -ag CC_REPORT_ITEM_KIND=()
declare -ag CC_REPORT_ITEM_EPOCH=()
declare -ag CC_REPORT_ITEM_BYTES=()
declare -ag CC_REPORT_ITEM_MODE=()
declare -ag CC_REPORT_ITEM_LATEST=()
declare -ag CC_REPORT_ITEM_POLICY=()
declare -ag CC_REPORT_ITEM_STATE=()
declare -ag CC_REPORT_ITEM_SIGNATURE=()
declare -ag CC_REPORT_UNKNOWN_PATHS=()
declare -ag CC_REPORT_PLAN_INDEXES=()
declare -ag CC_REPORT_APPLY_FAILED_PATHS=()
declare -ag CC_REPORT_APPLY_SKIPPED_PATHS=()
declare -Ag CC_REPORT_POLICY_MIN=()
declare -Ag CC_REPORT_POLICY_AGE=()
declare -Ag CC_REPORT_REFERENCED_PATHS=()

CC_REPORT_WARNINGS=0
CC_REPORT_BROKEN_LATEST=0
CC_REPORT_PERMISSION_WARNINGS=0
CC_REPORT_PLAN_BYTES=0
CC_REPORT_APPLY_PLANNED=0
CC_REPORT_APPLY_DELETED=0
CC_REPORT_APPLY_FAILED=0
CC_REPORT_APPLY_SKIPPED=0

_cc_reports_reset() {
    CC_REPORT_ITEM_FAMILY=()
    CC_REPORT_ITEM_PATH=()
    CC_REPORT_ITEM_KIND=()
    CC_REPORT_ITEM_EPOCH=()
    CC_REPORT_ITEM_BYTES=()
    CC_REPORT_ITEM_MODE=()
    CC_REPORT_ITEM_LATEST=()
    CC_REPORT_ITEM_POLICY=()
    CC_REPORT_ITEM_STATE=()
    CC_REPORT_ITEM_SIGNATURE=()
    CC_REPORT_UNKNOWN_PATHS=()
    CC_REPORT_PLAN_INDEXES=()
    CC_REPORT_APPLY_FAILED_PATHS=()
    CC_REPORT_APPLY_SKIPPED_PATHS=()
    CC_REPORT_POLICY_MIN=()
    CC_REPORT_POLICY_AGE=()
    CC_REPORT_REFERENCED_PATHS=()
    CC_REPORT_WARNINGS=0
    CC_REPORT_BROKEN_LATEST=0
    CC_REPORT_PERMISSION_WARNINGS=0
    CC_REPORT_PLAN_BYTES=0
}

_cc_reports_path_beneath() {
    local path="$1" root="$2"
    [ -n "$path" ] && [ -n "$root" ] && [ "$path" != / ] && [ "$root" != / ] || return 1
    [[ "$path" == /* && "$root" == /* ]] || return 1
    case "/$path/" in *'/../'*|*'/./'*) return 1 ;; esac
    [ "$path" != "$root" ] && [[ "$path" == "$root/"* ]]
}

_cc_reports_safe_root() {
    local root="$1" probe
    _cc_retention_location_safe "$root" || return 1
    probe="$root"
    while [ ! -e "$probe" ] && [ "$probe" != / ]; do probe="${probe%/*}"; done
    [ -d "$probe" ] && [ ! -L "$probe" ]
}

_cc_reports_mode_private() {
    local mode="$1"
    [[ "$mode" =~ ^[0-7]{3,4}$ ]] || return 1
    (( (8#$mode & 077) == 0 ))
}

_cc_reports_check_known_directory() {
    local directory="$1" mode uid
    mode="$(stat -c %a -- "$directory" 2>/dev/null || printf unknown)"
    uid="$(stat -c %u -- "$directory" 2>/dev/null || printf unknown)"
    if ! _cc_reports_mode_private "$mode" || [ "$uid" != "$(id -u)" ] || [ ! -r "$directory" ]; then
        CC_REPORT_PERMISSION_WARNINGS=$((CC_REPORT_PERMISSION_WARNINGS + 1))
        CC_REPORT_WARNINGS=$((CC_REPORT_WARNINGS + 1))
    fi
}

_cc_reports_file_signature() {
    stat -c '%d:%i:%s:%Y:%f' -- "$1" 2>/dev/null
}

_cc_reports_directory_data() {
    local directory="$1" family="$2" file base bytes=0 epoch=0 signature entry_signature
    [ -d "$directory" ] && [ ! -L "$directory" ] || return 1
    while IFS= read -r -d '' file; do
        [ -f "$file" ] && [ ! -L "$file" ] || return 1
        base="${file##*/}"
        case "$family:$base" in
            drive-report:metadata.txt|drive-report:summary.txt|drive-report:smartctl-a.txt) ;;
            drive-qualification:README.txt|drive-qualification:QUALIFICATION.txt|drive-qualification:precheck-summary.txt|drive-qualification:short-test-start.txt|drive-qualification:long-test-start.txt|drive-qualification:final-summary.txt) ;;
            *) return 1 ;;
        esac
        entry_signature="$(_cc_reports_file_signature "$file")" || return 1
        signature+="|$base=$entry_signature"
        bytes=$((bytes + $(stat -c %s -- "$file")))
    done < <(find -P "$directory" -mindepth 1 -maxdepth 1 -print0 2>/dev/null | LC_ALL=C sort -z)
    [ -f "$directory/metadata.txt" ] && epoch="$(stat -c %Y -- "$directory/metadata.txt")"
    [ -f "$directory/README.txt" ] && epoch="$(stat -c %Y -- "$directory/README.txt")"
    [ -f "$directory/QUALIFICATION.txt" ] && epoch="$(stat -c %Y -- "$directory/QUALIFICATION.txt")"
    [ "$epoch" -gt 0 ] || return 1
    printf '%s\t%s\t%s\n' "$bytes" "$epoch" "$(_cc_reports_file_signature "$directory")$signature"
}

_cc_reports_add_item() {
    local family="$1" path="$2" kind="$3" epoch="$4" bytes="$5" latest="$6" policy="$7" signature="$8"
    local index mode uid
    index="${#CC_REPORT_ITEM_PATH[@]}"
    mode="$(stat -c %a -- "$path" 2>/dev/null || printf unknown)"
    uid="$(stat -c %u -- "$path" 2>/dev/null || printf unknown)"
    CC_REPORT_ITEM_FAMILY[index]="$family"
    CC_REPORT_ITEM_PATH[index]="$path"
    CC_REPORT_ITEM_KIND[index]="$kind"
    CC_REPORT_ITEM_EPOCH[index]="$epoch"
    CC_REPORT_ITEM_BYTES[index]="$bytes"
    CC_REPORT_ITEM_MODE[index]="$mode"
    CC_REPORT_ITEM_LATEST[index]="$latest"
    CC_REPORT_ITEM_POLICY[index]="$policy"
    CC_REPORT_ITEM_STATE[index]="KEEP"
    CC_REPORT_ITEM_SIGNATURE[index]="$signature"
    if ! _cc_reports_mode_private "$mode" || [ "$uid" != "$(id -u)" ] || [ ! -r "$path" ]; then
        CC_REPORT_PERMISSION_WARNINGS=$((CC_REPORT_PERMISSION_WARNINGS + 1))
        CC_REPORT_WARNINGS=$((CC_REPORT_WARNINGS + 1))
    fi
    if [ "$kind" = directory ]; then
        local child child_mode child_uid
        while IFS= read -r -d '' child; do
            child_mode="$(stat -c %a -- "$child" 2>/dev/null || printf unknown)"
            child_uid="$(stat -c %u -- "$child" 2>/dev/null || printf unknown)"
            if ! _cc_reports_mode_private "$child_mode" || [ "$child_uid" != "$(id -u)" ] || [ ! -r "$child" ]; then
                CC_REPORT_PERMISSION_WARNINGS=$((CC_REPORT_PERMISSION_WARNINGS + 1))
                CC_REPORT_WARNINGS=$((CC_REPORT_WARNINGS + 1))
            fi
        done < <(find -P "$path" -mindepth 1 -maxdepth 1 -type f -print0 2>/dev/null)
    fi
}

_cc_reports_unknown() {
    CC_REPORT_UNKNOWN_PATHS+=("$1")
    CC_REPORT_WARNINGS=$((CC_REPORT_WARNINGS + 1))
}

_cc_reports_scan_monthly() {
    local root="$1" latest_name="$2" entry base epoch bytes signature resolved latest_target=""
    local latest_defect=0 latest_matched=0 report_count=0
    [ -e "$root" ] || return 0
    _cc_reports_safe_root "$root" || { _cc_reports_unknown "$root"; return 0; }
    [ -d "$root" ] && [ ! -L "$root" ] || { _cc_reports_unknown "$root"; return 0; }
    _cc_reports_check_known_directory "$root"
    if [ -L "$root/$latest_name" ]; then
        resolved="$(readlink -f -- "$root/$latest_name" 2>/dev/null || :)"
        if [ -n "$resolved" ] && _cc_reports_path_beneath "$resolved" "$root" && [ -f "$resolved" ] && [ ! -L "$resolved" ]; then
            latest_target="$resolved"
        else
            CC_REPORT_BROKEN_LATEST=$((CC_REPORT_BROKEN_LATEST + 1))
            CC_REPORT_WARNINGS=$((CC_REPORT_WARNINGS + 1))
            latest_defect=1
        fi
    elif [ -e "$root/$latest_name" ]; then
        _cc_reports_unknown "$root/$latest_name"
        CC_REPORT_BROKEN_LATEST=$((CC_REPORT_BROKEN_LATEST + 1))
        latest_defect=1
    fi
    while IFS= read -r -d '' entry; do
        base="${entry##*/}"
        [ "$base" != "$latest_name" ] || continue
        if [[ "$base" =~ ^monthly-health-[0-9]{8}-[0-9]{6}\.log$ ]] && [ -f "$entry" ] && [ ! -L "$entry" ]; then
            epoch="$(stat -c %Y -- "$entry" 2>/dev/null)" || { _cc_reports_unknown "$entry"; continue; }
            bytes="$(stat -c %s -- "$entry" 2>/dev/null)" || { _cc_reports_unknown "$entry"; continue; }
            signature="$(_cc_reports_file_signature "$entry")" || { _cc_reports_unknown "$entry"; continue; }
            report_count=$((report_count + 1))
            if [ "$entry" = "$latest_target" ]; then latest=yes; latest_matched=1; else latest=no; fi
            _cc_reports_add_item monthly-health "$entry" file "$epoch" "$bytes" "$latest" retention "$signature"
        else
            _cc_reports_unknown "$entry"
        fi
    done < <(find -P "$root" -mindepth 1 -maxdepth 1 -print0 2>/dev/null | LC_ALL=C sort -z)
    if [ "$report_count" -gt 0 ] && [ "$latest_matched" -eq 0 ] && [ "$latest_defect" -eq 0 ]; then
        CC_REPORT_BROKEN_LATEST=$((CC_REPORT_BROKEN_LATEST + 1))
        CC_REPORT_WARNINGS=$((CC_REPORT_WARNINGS + 1))
    fi
}

_cc_reports_scan_drive_family() {
    local root="$1" family="$2" policy="$3" entry base data bytes epoch signature title_file expected latest
    [ -e "$root" ] || return 0
    _cc_reports_safe_root "$root" || { _cc_reports_unknown "$root"; return 0; }
    [ -d "$root" ] && [ ! -L "$root" ] || { _cc_reports_unknown "$root"; return 0; }
    _cc_reports_check_known_directory "$root"
    if [ "$family" = drive-report ]; then title_file=metadata.txt; expected='Captain Cronos Drive Report'; else title_file=-; expected='Drive Qualification'; fi
    while IFS= read -r -d '' entry; do
        base="${entry##*/}"
        if [ "$family" = drive-report ] && [ "$base" = qualification ]; then continue; fi
        if [ "$family" = drive-qualification ]; then
            if [ -f "$entry/README.txt" ]; then title_file=README.txt; elif [ -f "$entry/QUALIFICATION.txt" ]; then title_file=QUALIFICATION.txt; else title_file=-; fi
        fi
        if [[ "$base" =~ ^[a-zA-Z0-9._-]+-[0-9]{8}-[0-9]{6}$ ]] && [ -d "$entry" ] && [ ! -L "$entry" ] && [ "$title_file" != - ] && [ -f "$entry/$title_file" ]; then
            if [ "$family" = drive-report ]; then
                [ "$(sed -n '1p' "$entry/$title_file" 2>/dev/null)" = "$expected" ] || { _cc_reports_unknown "$entry"; continue; }
            else
                [[ "$(sed -n '1p' "$entry/$title_file" 2>/dev/null)" == "$expected"* ]] || { _cc_reports_unknown "$entry"; continue; }
            fi
            data="$(_cc_reports_directory_data "$entry" "$family")" || { _cc_reports_unknown "$entry"; continue; }
            IFS=$'\t' read -r bytes epoch signature <<< "$data"
            if [ "$family" = drive-report ] && _cc_reports_drive_referenced "$entry"; then latest=yes; else latest=no; fi
            _cc_reports_add_item "$family" "$entry" directory "$epoch" "$bytes" "$latest" "$policy" "$signature"
        else
            _cc_reports_unknown "$entry"
        fi
    done < <(find -P "$root" -mindepth 1 -maxdepth 1 -print0 2>/dev/null | LC_ALL=C sort -z)
}

_cc_reports_drive_referenced() {
    [ -n "${CC_REPORT_REFERENCED_PATHS[$1]+set}" ]
}

_cc_reports_load_asset_references() {
    local asset value
    [ -d "$(cc_env_asset_dir)/drives" ] || return 0
    while IFS= read -r -d '' asset; do
        value="$(awk -F ': ' '$1 == "last_report" {sub(/^[^:]*:[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; exit}' "$asset" 2>/dev/null || :)"
        [ -n "$value" ] && CC_REPORT_REFERENCED_PATHS["$value"]=1
    done < <(find -P "$(cc_env_asset_dir)/drives" -maxdepth 1 -type f -name '*.yaml' -print0 2>/dev/null)
    return 0
}

_cc_reports_scan_current_log() {
    local family="$1" path="$2" epoch bytes signature
    [ -e "$path" ] || return 0
    if [ -f "$path" ] && [ ! -L "$path" ] && _cc_reports_safe_root "${path%/*}"; then
        _cc_reports_check_known_directory "${path%/*}"
        epoch="$(stat -c %Y -- "$path")" || { _cc_reports_unknown "$path"; return; }
        bytes="$(stat -c %s -- "$path")" || { _cc_reports_unknown "$path"; return; }
        signature="$(_cc_reports_file_signature "$path")" || { _cc_reports_unknown "$path"; return; }
        _cc_reports_add_item "$family" "$path" file "$epoch" "$bytes" yes protected-current "$signature"
    else
        _cc_reports_unknown "$path"
    fi
}

_cc_reports_scan_report_root_unknowns() {
    local root entry base
    root="$(cc_env_report_dir)"
    if [ -L "$root" ] || { [ -e "$root" ] && [ ! -d "$root" ]; }; then
        _cc_reports_unknown "$root"
        return 0
    fi
    [ -d "$root" ] || return 0
    while IFS= read -r -d '' entry; do
        base="${entry##*/}"
        case "$base" in monthly-health|drives) ;; *) _cc_reports_unknown "$entry" ;; esac
    done < <(find -P "$root" -mindepth 1 -maxdepth 1 -print0 2>/dev/null | LC_ALL=C sort -z)
}

cc_reports_inventory() {
    local family _class _producer kind location min_count max_age latest policy
    _cc_reports_reset
    _cc_reports_load_asset_references
    while IFS=$'\t' read -r family _class _producer kind location min_count max_age latest policy; do
        case "$family" in
            monthly-health) _cc_reports_scan_monthly "$location" "$latest" ;;
            drive-report) _cc_reports_scan_drive_family "$location" "$family" "$policy" ;;
            drive-qualification) _cc_reports_scan_drive_family "$location" "$family" "$policy" ;;
            system-update|kernel-cleanup) _cc_reports_scan_current_log "$family" "$location" ;;
        esac
    done < <(cc_retention_report_family_catalog)
    _cc_reports_scan_report_root_unknowns
}

_cc_reports_policy_defaults() {
    local wanted="$1" family class producer kind location min_count max_age latest policy
    while IFS=$'\t' read -r family class producer kind location min_count max_age latest policy; do
        [ "$family" = "$wanted" ] || continue
        min_count="$(cc_retention_report_policy_value "$family" RETENTION_MIN_COUNT "$min_count")"
        max_age="$(cc_retention_report_policy_value "$family" RETENTION_MAX_AGE_DAYS "$max_age")"
        printf '%s\t%s\n' "$min_count" "$max_age"
        return 0
    done < <(cc_retention_report_family_catalog)
    return 1
}

cc_reports_plan() {
    local now="${CC_REPORT_NOW_EPOCH:-}" index other family defaults min_count max_age rank age
    [ -n "$now" ] || now="$(date +%s)"
    [[ "$now" =~ ^[0-9]+$ ]] || return 2
    CC_REPORT_PLAN_INDEXES=()
    CC_REPORT_PLAN_BYTES=0
    for index in "${!CC_REPORT_ITEM_PATH[@]}"; do
        CC_REPORT_ITEM_STATE[index]=KEEP
        [ "${CC_REPORT_ITEM_POLICY[index]}" = retention ] || { CC_REPORT_ITEM_STATE[index]="KEEP protected"; continue; }
        [ "${CC_REPORT_ITEM_LATEST[index]}" = no ] || { CC_REPORT_ITEM_STATE[index]="KEEP latest"; continue; }
        family="${CC_REPORT_ITEM_FAMILY[index]}"
        if [ -z "${CC_REPORT_POLICY_MIN[$family]+set}" ]; then
            defaults="$(_cc_reports_policy_defaults "$family")" || return 1
            IFS=$'\t' read -r min_count max_age <<< "$defaults"
            CC_REPORT_POLICY_MIN[$family]="$min_count"
            CC_REPORT_POLICY_AGE[$family]="$max_age"
        else
            min_count="${CC_REPORT_POLICY_MIN[$family]}"
            max_age="${CC_REPORT_POLICY_AGE[$family]}"
        fi
        rank=1
        for other in "${!CC_REPORT_ITEM_PATH[@]}"; do
            [ "${CC_REPORT_ITEM_FAMILY[other]}" = "$family" ] || continue
            if [ "${CC_REPORT_ITEM_EPOCH[other]}" -gt "${CC_REPORT_ITEM_EPOCH[index]}" ] || \
                { [ "${CC_REPORT_ITEM_EPOCH[other]}" -eq "${CC_REPORT_ITEM_EPOCH[index]}" ] && [[ "${CC_REPORT_ITEM_PATH[other]}" > "${CC_REPORT_ITEM_PATH[index]}" ]]; }; then
                rank=$((rank + 1))
            fi
        done
        age=$(((now - CC_REPORT_ITEM_EPOCH[index]) / 86400))
        [ "$age" -ge 0 ] || age=0
        if [ "$rank" -eq 1 ]; then
            CC_REPORT_ITEM_STATE[index]="KEEP newest"
        elif [ "$rank" -gt "$min_count" ] && [ "$max_age" -gt 0 ] && [ "$age" -gt "$max_age" ]; then
            CC_REPORT_ITEM_STATE[index]="PRUNE age"
            CC_REPORT_PLAN_INDEXES+=("$index")
            CC_REPORT_PLAN_BYTES=$((CC_REPORT_PLAN_BYTES + CC_REPORT_ITEM_BYTES[index]))
        fi
    done
}

_cc_reports_revalidate_item() {
    local index="$1" path family data bytes epoch signature
    path="${CC_REPORT_ITEM_PATH[index]}"
    family="${CC_REPORT_ITEM_FAMILY[index]}"
    case "$family" in
        monthly-health)
            _cc_reports_path_beneath "$path" "$(cc_env_report_dir)/monthly-health" || return 1
            [ -f "$path" ] && [ ! -L "$path" ] || return 1
            [ "$(_cc_reports_file_signature "$path")" = "${CC_REPORT_ITEM_SIGNATURE[index]}" ] || return 1
            if [ -L "$(cc_env_report_dir)/monthly-health/latest.log" ] && \
                [ "$(readlink -f -- "$(cc_env_report_dir)/monthly-health/latest.log" 2>/dev/null || :)" = "$path" ]; then
                return 1
            fi
            ;;
        drive-report)
            _cc_reports_path_beneath "$path" "$(cc_env_report_dir)/drives" || return 1
            [[ "$path" != "$(cc_env_report_dir)/drives/qualification"* ]] || return 1
            data="$(_cc_reports_directory_data "$path" drive-report)" || return 1
            IFS=$'\t' read -r bytes epoch signature <<< "$data"
            [ "$signature" = "${CC_REPORT_ITEM_SIGNATURE[index]}" ]
            ;;
        *) return 1 ;;
    esac
}

_cc_reports_remove_file() { rm -- "$1"; }
_cc_reports_remove_directory() { rmdir -- "$1"; }

_cc_reports_delete_directory() {
    local index="$1" directory="${CC_REPORT_ITEM_PATH[$1]}" expected="${CC_REPORT_ITEM_SIGNATURE[$1]}" file base signature
    while IFS= read -r -d '' file; do
        [ -f "$file" ] && [ ! -L "$file" ] || return 1
        _cc_reports_path_beneath "$file" "$directory" || return 1
        base="${file##*/}"
        signature="$(_cc_reports_file_signature "$file")" || return 1
        case "$expected" in *"|$base=$signature"*) ;; *) return 1 ;; esac
        _cc_reports_remove_file "$file" || return 1
    done < <(find -P "$directory" -mindepth 1 -maxdepth 1 -type f -print0 2>/dev/null | LC_ALL=C sort -z)
    _cc_reports_remove_directory "$directory"
}

cc_reports_apply_plan() {
    local index path
    CC_REPORT_APPLY_PLANNED="${#CC_REPORT_PLAN_INDEXES[@]}"
    CC_REPORT_APPLY_DELETED=0
    CC_REPORT_APPLY_FAILED=0
    CC_REPORT_APPLY_SKIPPED=0
    CC_REPORT_APPLY_FAILED_PATHS=()
    CC_REPORT_APPLY_SKIPPED_PATHS=()
    for index in "${CC_REPORT_PLAN_INDEXES[@]}"; do
        path="${CC_REPORT_ITEM_PATH[index]}"
        if ! _cc_reports_revalidate_item "$index"; then
            CC_REPORT_APPLY_SKIPPED=$((CC_REPORT_APPLY_SKIPPED + 1))
            CC_REPORT_APPLY_SKIPPED_PATHS+=("$path")
            continue
        fi
        if [ "${CC_REPORT_ITEM_KIND[index]}" = file ]; then
            if _cc_reports_remove_file "$path"; then
                CC_REPORT_APPLY_DELETED=$((CC_REPORT_APPLY_DELETED + 1))
            else
                CC_REPORT_APPLY_FAILED=$((CC_REPORT_APPLY_FAILED + 1))
                CC_REPORT_APPLY_FAILED_PATHS+=("$path")
            fi
        elif _cc_reports_delete_directory "$index"; then
            CC_REPORT_APPLY_DELETED=$((CC_REPORT_APPLY_DELETED + 1))
        else
            CC_REPORT_APPLY_FAILED=$((CC_REPORT_APPLY_FAILED + 1))
            CC_REPORT_APPLY_FAILED_PATHS+=("$path")
        fi
    done
    [ "$CC_REPORT_APPLY_FAILED" -eq 0 ] && [ "$CC_REPORT_APPLY_SKIPPED" -eq 0 ]
}
