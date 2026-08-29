#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-retention.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash find stat date awk
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Classify and account for toolkit-owned persistent resources.
# ==============================================================================

if ! declare -F cc_env_home >/dev/null 2>&1; then
    _cc_retention_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_retention_lib_dir/cc-environment.sh"
    unset _cc_retention_lib_dir
fi

CC_RETENTION_COUNT=0
CC_RETENTION_BYTES=0
CC_RETENTION_OLDEST="-"
CC_RETENTION_NEWEST="-"
CC_RETENTION_OLDEST_EPOCH=0
CC_RETENTION_NEWEST_EPOCH=0
CC_RETENTION_WARNINGS=0
CC_RETENTION_SYMLINKS=0

cc_retention_class_description() {
    case "$1" in
        authoritative-state) echo "Required toolkit configuration or inventory state." ;;
        user-curated-state) echo "User-visible data managed or indexed by the toolkit." ;;
        historical-record) echo "Operational reports or logs retained for comparison and audit." ;;
        regenerable-cache) echo "Derived data that may be reproduced, but has no cleanup policy yet." ;;
        recovery-artifact) echo "Rollback material whose minimum recovery generations are undefined." ;;
        user-export) echo "Explicit transport or archival output owned by the operator." ;;
        unknown-external) echo "Legacy, unclassified, or externally located data with unproven ownership." ;;
        *) return 2 ;;
    esac
}

# Authoritative report-family metadata shared by producers, persistent-resource
# inventory, and the report lifecycle. Fields: family, resource class, producer,
# unit kind, location, minimum retained count, maximum age in days, latest name,
# and cleanup policy. A maximum age of zero disables age-based pruning.
cc_retention_report_family_catalog() {
    local report_dir log_dir
    report_dir="$(cc_env_report_dir)"
    log_dir="$(cc_env_log_dir)"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        monthly-health report-history 'cc monthly-health --file' file \
        "$report_dir/monthly-health" 24 1095 latest.log retention
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        drive-report report-history 'cc drive-report' directory \
        "$report_dir/drives" 10 365 - retention
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        drive-qualification asset 'cc drive-qualify' directory \
        "$report_dir/drives/qualification" 0 0 - protected
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        system-update report-history 'cc system-update --apply' file \
        "$log_dir/system-update.log" 1 0 - protected-current
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        kernel-cleanup report-history 'cc kernel cleanup --apply' file \
        "$log_dir/kernel-cleanup.log" 1 0 - protected-current
}

cc_retention_report_policy_value() {
    local family="$1" field="$2" default="$3" key value
    key="${family//-/_}_${field}"
    key="${key^^}"
    if declare -F cc_config_get >/dev/null 2>&1; then
        value="$(cc_config_get "$key" "$default")"
    else
        value="$default"
    fi
    [[ "$value" =~ ^[0-9]+$ ]] || value="$default"
    printf '%s\n' "$value"
}

_cc_retention_location_safe() {
    local path="$1" remainder component probe
    [ -n "$path" ] && [ "$path" != / ] && [[ "$path" == /* ]] || return 1
    remainder="${path#/}"
    while :; do
        component="${remainder%%/*}"
        [ "$component" != .. ] || return 1
        [ "$remainder" != "$component" ] || break
        remainder="${remainder#*/}"
    done
    probe="$path"
    while [ "$probe" != / ]; do
        [ ! -L "$probe" ] || return 1
        probe="${probe%/*}"
        [ -n "$probe" ] || probe=/
    done
}

# Fields: id, subsystem, class, location, scan, policy, cleanup, ownership.
cc_retention_catalog() {
    local cc_home host_home report_dir asset_dir log_dir plugin_dir cache_dir
    cc_home="$(cc_env_home)"
    host_home="$(cc_env_host_home)"
    report_dir="$(cc_env_report_dir)"
    asset_dir="$(cc_env_asset_dir)"
    log_dir="$(cc_env_log_dir)"
    plugin_dir="$(cc_env_plugin_dir)"
    cache_dir="$(cc_env_cache_dir)"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        toolkit-config configuration authoritative-state "$cc_home/config" file retain never exact-file
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        host-config configuration authoritative-state "$host_home/config" file retain never exact-file
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        monthly-health monthly-health historical-record "$report_dir/monthly-health" monthly retain disabled canonical-root
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        drive-reports storage historical-record "$report_dir/drives" tree retain disabled canonical-root
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        asset-records assets authoritative-state "$asset_dir" asset-records retain never canonical-root
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        asset-history assets user-curated-state "$asset_dir/.history" tree retain never canonical-root
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        installer-backups installer recovery-artifact "$(cc_env_backup_dir)" tree retain disabled canonical-root
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        repository-bundles repositories user-export "$(cc_env_bundle_dir)" tree user-managed never canonical-root
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        system-update-log system-update historical-record "$log_dir/system-update.log" file retain disabled exact-file
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        kernel-cleanup-log kernel historical-record "$log_dir/kernel-cleanup.log" file retain disabled exact-file
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        monthly-health-service monthly-health-timer authoritative-state \
        "$HOME/.config/systemd/user/captaincronos-monthly-health.service" file retain command-owned exact-file
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        monthly-health-timer monthly-health-timer authoritative-state \
        "$HOME/.config/systemd/user/captaincronos-monthly-health.timer" file retain command-owned exact-file
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        host-plugins plugins user-curated-state "$plugin_dir" tree user-managed never canonical-root
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        reserved-cache cache regenerable-cache "$cache_dir" tree retain disabled reserved-root
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        legacy-reports legacy unknown-external "$cc_home/reports" tree retain never legacy-root
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        legacy-assets legacy unknown-external "$cc_home/assets" tree retain never legacy-root
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        legacy-update-log legacy unknown-external "$HOME/upgrade.log" file retain never legacy-exact
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        legacy-kernel-log legacy unknown-external "$HOME/kernel-cleanup.log" file retain never legacy-exact
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        helpme-backups helpme-refresh recovery-artifact "$HOME" helpme-backups retain disabled deterministic-name
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        unclassified-home unclassified unknown-external "$cc_home" unclassified-home retain never unproven
}

# Fields: creator, nature, regenerable, user-visible, recovery impact.
cc_retention_metadata() {
    case "$1" in
        toolkit-config) printf '%s\t%s\t%s\t%s\t%s\n' 'cc config' authoritative no yes operational ;;
        host-config) printf '%s\t%s\t%s\t%s\t%s\n' 'cc init' authoritative no yes operational ;;
        monthly-health) printf '%s\t%s\t%s\t%s\t%s\n' 'cc monthly-health' historical no yes none ;;
        drive-reports) printf '%s\t%s\t%s\t%s\t%s\n' 'cc drive-report/drive-qualify' historical no yes none ;;
        asset-records) printf '%s\t%s\t%s\t%s\t%s\n' 'cc asset/drive workflows' authoritative no yes data-loss ;;
        asset-history) printf '%s\t%s\t%s\t%s\t%s\n' 'cc asset/drive workflows' curated no yes data-loss ;;
        installer-backups) printf '%s\t%s\t%s\t%s\t%s\n' 'install/install.sh' recovery no yes removes-recovery ;;
        repository-bundles) printf '%s\t%s\t%s\t%s\t%s\n' 'cc repos backup' export unknown yes user-owned ;;
        system-update-log) printf '%s\t%s\t%s\t%s\t%s\n' 'cc system-update --apply' historical no yes none ;;
        kernel-cleanup-log) printf '%s\t%s\t%s\t%s\t%s\n' 'cc kernel cleanup --apply' historical no yes none ;;
        monthly-health-service|monthly-health-timer)
            printf '%s\t%s\t%s\t%s\t%s\n' 'cc monthly-health-timer install-standalone' authoritative yes yes integration
            ;;
        host-plugins) printf '%s\t%s\t%s\t%s\t%s\n' 'cc init/operator' curated no yes data-loss ;;
        reserved-cache) printf '%s\t%s\t%s\t%s\t%s\n' 'cc init (root only)' derived yes no none ;;
        legacy-reports|legacy-assets|legacy-update-log|legacy-kernel-log)
            printf '%s\t%s\t%s\t%s\t%s\n' 'legacy toolkit versions' unknown unknown yes unknown
            ;;
        helpme-backups) printf '%s\t%s\t%s\t%s\t%s\n' 'cc helpme-refresh --apply' recovery no yes removes-recovery ;;
        unclassified-home) printf '%s\t%s\t%s\t%s\t%s\n' unknown unknown unknown unknown unknown ;;
        *) return 2 ;;
    esac
}

_cc_retention_consider_file() {
    local file="$1" bytes epoch day
    [ -f "$file" ] && [ ! -L "$file" ] || return 0
    [ -r "$file" ] || CC_RETENTION_WARNINGS=$((CC_RETENTION_WARNINGS + 1))
    bytes="$(stat -c %s -- "$file" 2>/dev/null)" || {
        CC_RETENTION_WARNINGS=$((CC_RETENTION_WARNINGS + 1))
        return 0
    }
    epoch="$(stat -c %Y -- "$file" 2>/dev/null)" || {
        CC_RETENTION_WARNINGS=$((CC_RETENTION_WARNINGS + 1))
        return 0
    }
    day="$(date -d "@$epoch" +%F 2>/dev/null || printf unknown)"
    CC_RETENTION_COUNT=$((CC_RETENTION_COUNT + 1))
    CC_RETENTION_BYTES=$((CC_RETENTION_BYTES + bytes))
    if [ "$CC_RETENTION_OLDEST_EPOCH" -eq 0 ] || [ "$epoch" -lt "$CC_RETENTION_OLDEST_EPOCH" ]; then
        CC_RETENTION_OLDEST="$day"
        CC_RETENTION_OLDEST_EPOCH="$epoch"
    fi
    if [ "$CC_RETENTION_NEWEST_EPOCH" -eq 0 ] || [ "$epoch" -gt "$CC_RETENTION_NEWEST_EPOCH" ]; then
        CC_RETENTION_NEWEST="$day"
        CC_RETENTION_NEWEST_EPOCH="$epoch"
    fi
}

_cc_retention_tree() {
    local root="$1" max_depth="$2" file
    [ -e "$root" ] || [ -L "$root" ] || return 0
    if [ -L "$root" ]; then
        CC_RETENTION_SYMLINKS=$((CC_RETENTION_SYMLINKS + 1))
        return 0
    fi
    if [ -f "$root" ]; then
        _cc_retention_consider_file "$root"
        return 0
    fi
    [ -d "$root" ] || return 0
    [ -r "$root" ] || {
        CC_RETENTION_WARNINGS=$((CC_RETENTION_WARNINGS + 1))
        return 0
    }
    while IFS= read -r -d '' file; do
        _cc_retention_consider_file "$file"
    done < <(find -P "$root" -xdev -maxdepth "$max_depth" -type f -print0 2>/dev/null)
    while IFS= read -r -d '' file; do
        CC_RETENTION_SYMLINKS=$((CC_RETENTION_SYMLINKS + 1))
    done < <(find -P "$root" -xdev -maxdepth "$max_depth" -type l -print0 2>/dev/null)
}

_cc_retention_unclassified_home() {
    local root="$1" entry base
    [ -d "$root" ] && [ ! -L "$root" ] || return 0
    while IFS= read -r -d '' entry; do
        base="${entry##*/}"
        case "$base" in
            config|hosts|reports|assets|backups|repo-bundles) continue ;;
        esac
        _cc_retention_tree "$entry" 6
    done < <(find -P "$root" -xdev -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
}

cc_retention_scan() {
    local location="$1" scan="$2" file
    CC_RETENTION_COUNT=0
    CC_RETENTION_BYTES=0
    CC_RETENTION_OLDEST="-"
    CC_RETENTION_NEWEST="-"
    CC_RETENTION_OLDEST_EPOCH=0
    CC_RETENTION_NEWEST_EPOCH=0
    CC_RETENTION_WARNINGS=0
    CC_RETENTION_SYMLINKS=0

    if ! _cc_retention_location_safe "$location"; then
        CC_RETENTION_WARNINGS=1
        [ ! -L "$location" ] || CC_RETENTION_SYMLINKS=1
        return 0
    fi

    case "$scan" in
        file) _cc_retention_consider_file "$location" ;;
        monthly)
            [ -d "$location" ] && [ ! -L "$location" ] || {
                [ ! -L "$location" ] || CC_RETENTION_SYMLINKS=1
                return 0
            }
            while IFS= read -r -d '' file; do
                _cc_retention_consider_file "$file"
            done < <(find -P "$location" -xdev -maxdepth 1 -type f -name 'monthly-health-*.log' -print0 2>/dev/null)
            while IFS= read -r -d '' file; do
                CC_RETENTION_SYMLINKS=$((CC_RETENTION_SYMLINKS + 1))
            done < <(find -P "$location" -xdev -maxdepth 1 -type l -print0 2>/dev/null)
            ;;
        tree) _cc_retention_tree "$location" 8 ;;
        asset-records)
            [ -d "$location" ] && [ ! -L "$location" ] || return 0
            while IFS= read -r -d '' file; do
                _cc_retention_consider_file "$file"
            done < <(find -P "$location" -xdev -maxdepth 2 -type f -name '*.yaml' -print0 2>/dev/null)
            ;;
        helpme-backups)
            [ -d "$location" ] && [ ! -L "$location" ] || return 0
            while IFS= read -r -d '' file; do
                _cc_retention_consider_file "$file"
            done < <(find -P "$location" -xdev -maxdepth 1 -type f -name '.bash_functions.pre-helpme-refresh.*.bak' -print0 2>/dev/null)
            ;;
        unclassified-home) _cc_retention_unclassified_home "$location" ;;
        *) return 2 ;;
    esac
}

cc_retention_human_bytes() {
    awk -v bytes="$1" 'BEGIN {
        split("B KiB MiB GiB TiB", unit, " "); value=bytes; unit_index=1;
        while (value >= 1024 && unit_index < 5) { value /= 1024; unit_index++ }
        if (unit_index == 1) printf "%d %s", value, unit[unit_index];
        else printf "%.1f %s", value, unit[unit_index]
    }'
}

cc_retention_inventory_tsv() {
    local id subsystem class location scan policy cleanup ownership metadata
    local creator nature regenerable user_visible recovery
    printf 'resource\tsubsystem\tclass\tlocation\tcount\tbytes\toldest\tnewest\tpolicy\tcleanup\townership\tcreator\tnature\tregenerable\tuser_visible\trecovery_impact\twarnings\tsymlinks\n'
    while IFS=$'\t' read -r id subsystem class location scan policy cleanup ownership; do
        cc_retention_scan "$location" "$scan"
        metadata="$(cc_retention_metadata "$id")"
        IFS=$'\t' read -r creator nature regenerable user_visible recovery <<< "$metadata"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$id" "$subsystem" "$class" "$location" "$CC_RETENTION_COUNT" "$CC_RETENTION_BYTES" \
            "$CC_RETENTION_OLDEST" "$CC_RETENTION_NEWEST" "$policy" "$cleanup" "$ownership" \
            "$creator" "$nature" "$regenerable" "$user_visible" "$recovery" \
            "$CC_RETENTION_WARNINGS" "$CC_RETENTION_SYMLINKS"
    done < <(cc_retention_catalog)
}
