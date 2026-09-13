#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-storage.sh
# Version     : reads VERSION
# Category    : Storage
# Requires    : bash lsblk awk find smartctl grep paste
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Shared storage device discovery, SMART, and workflow helpers.
# ==============================================================================

cc_storage_version() {
    if command -v cc_version >/dev/null 2>&1; then
        cc_version
    elif [ -f "${PROJECT_ROOT:-}/VERSION" ]; then
        cat "${PROJECT_ROOT:-}/VERSION"
    else
        echo "unknown"
    fi
}

cc_storage_loaded() {
    command -v cc_storage_device_exists >/dev/null 2>&1 && \
    command -v cc_storage_require_device >/dev/null 2>&1 && \
    command -v cc_storage_inventory_output >/dev/null 2>&1
}

cc_storage_dependencies() {
    echo "bash lsblk awk find smartctl grep paste"
}

cc_storage_device_exists() {
    local device="$1"
    [ -n "$device" ] && [ -e "$device" ]
}

cc_storage_require_device() {
    local device="$1"
    if ! cc_storage_device_exists "$device"; then
        cc_error "Device not found: $device"
        return 1
    fi
}

cc_storage_require_smartctl() {
    if ! command -v smartctl >/dev/null 2>&1; then
        cc_error "smartctl not found. Install smartmontools."
        return 127
    fi
}

cc_storage_run_smartctl() {
    if sudo -n true 2>/dev/null; then
        sudo smartctl "$@"
    else
        smartctl "$@"
    fi
}

cc_storage_device_basename() {
    basename "$1" | tr '/' '_'
}

cc_storage_report_root() {
    if [ -n "${CC_REPORT_DIR:-}" ]; then
        echo "$CC_REPORT_DIR/drives"
    elif command -v cc_config_get >/dev/null 2>&1; then
        echo "$(cc_config_get REPORT_DIR "$HOME/.captaincronos/reports")/drives"
    else
        echo "$HOME/.captaincronos/reports/drives"
    fi
}

cc_storage_report_dir_for_device() {
    local device="$1" stamp safe_name
    stamp="$(date +%Y%m%d-%H%M%S)"
    safe_name="$(cc_storage_device_basename "$device")"
    echo "$(cc_storage_report_root)/${safe_name}-${stamp}"
}

cc_storage_mounts_for_device() {
    local device="$1"
    lsblk -nr -o MOUNTPOINT "$device" 2>/dev/null | grep -v '^$' | paste -sd ',' - 2>/dev/null || true
}

cc_storage_lsblk_value() {
    local device="$1" column="$2" value
    value="$(lsblk -dnro "$column" "$device" 2>/dev/null | head -n 1)"
    printf '%b' "$value" | tr '\t\r\n' '   '
}

cc_storage_smart_text_for_device() {
    local device="$1"
    if command -v smartctl >/dev/null 2>&1; then
        sudo smartctl -a "$device" 2>/dev/null || smartctl -a "$device" 2>/dev/null || true
    fi
}

cc_storage_inventory_rows() {
    local name type dev model serial size tran smart_text health hours temp mounts
    lsblk -dn -o NAME,TYPE 2>/dev/null | while read -r name type; do
        [ "$type" = "disk" ] || continue
        cc_smart_device_candidate "$name" || continue
        dev="/dev/$name"
        model="$(cc_storage_lsblk_value "$dev" MODEL)"
        serial="$(cc_storage_lsblk_value "$dev" SERIAL)"
        size="$(cc_storage_lsblk_value "$dev" SIZE)"
        tran="$(cc_storage_lsblk_value "$dev" TRAN)"
        smart_text="$(cc_storage_smart_text_for_device "$dev")"
        health="$(cc_smart_field_first "$smart_text" 'SMART overall-health self-assessment test result|SMART Health Status')"
        hours="$(printf '%s\n' "$smart_text" | cc_smart_power_on_hours)"
        temp="$(cc_smart_attr_raw "$smart_text" 'Temperature_Celsius|Airflow_Temperature_Cel')"
        [ -n "$temp" ] || temp="$(cc_smart_nvme_metric "$smart_text" 'Temperature')"
        mounts="$(cc_storage_mounts_for_device "$dev")"
        [ -n "$health" ] || health="unknown"
        [ "$hours" != "--" ] || hours="unknown"
        [ -n "$temp" ] || temp="unknown"
        [ -n "$mounts" ] || mounts="-"
        [ -n "$tran" ] || tran="-"
        [ -n "$model" ] || model="unknown"
        [ -n "$serial" ] || serial="unknown"
        [ -n "$size" ] || size="unknown"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$dev" "$model" "$serial" "$size" "$tran" "$health" "$hours" "$mounts"
    done
}

cc_storage_inventory_table() {
    printf '%-12s %-22s %-20s %-8s %-8s %-10s %-10s %s\n' "Device" "Model" "Serial" "Size" "Tran" "SMART" "Hours" "Mounts"
    printf '%-12s %-22s %-20s %-8s %-8s %-10s %-10s %s\n' "------" "-----" "------" "----" "----" "-----" "-----" "------"
    cc_storage_inventory_rows | while IFS=$'\t' read -r dev model serial size tran health hours mounts; do
        printf '%-12s %-22s %-20s %-8s %-8s %-10s %-10s %s\n' "$dev" "$model" "$serial" "$size" "$tran" "$health" "$hours" "$mounts"
    done
}

cc_storage_inventory_csv() {
    local dev model serial size tran health hours mounts
    echo "device,model,serial,size,transport,smart,hours,mounts"
    cc_storage_inventory_rows | while IFS=$'\t' read -r dev model serial size tran health hours mounts; do
        dev="${dev//\"/\"\"}"
        model="${model//\"/\"\"}"
        serial="${serial//\"/\"\"}"
        size="${size//\"/\"\"}"
        tran="${tran//\"/\"\"}"
        health="${health//\"/\"\"}"
        hours="${hours//\"/\"\"}"
        mounts="${mounts//\"/\"\"}"
        printf '"%s","%s","%s","%s","%s","%s","%s","%s"\n' "$dev" "$model" "$serial" "$size" "$tran" "$health" "$hours" "$mounts"
    done
}

cc_storage_inventory_markdown() {
    echo "| Device | Model | Serial | Size | Transport | SMART | Hours | Mounts |"
    echo "|---|---|---|---|---|---|---|---|"
    cc_storage_inventory_rows | while IFS=$'\t' read -r dev model serial size tran health hours mounts; do
        echo "| $dev | $model | $serial | $size | $tran | $health | $hours | $mounts |"
    done
}

cc_storage_inventory_output() {
    local format="${1:-table}"
    case "$format" in
        table) cc_storage_inventory_table ;;
        csv) cc_storage_inventory_csv ;;
        markdown) cc_storage_inventory_markdown ;;
        *) cc_error "Unknown inventory format: $format"; return 2 ;;
    esac
}

cc_storage_test_status() {
    local device="$1" out
    cc_storage_require_smartctl || return $?
    cc_storage_require_device "$device" || return $?
    out="$(cc_storage_run_smartctl -a "$device" 2>/dev/null || true)"
    printf '%-12s %s\n' "Device:" "$device"
    echo
    printf '%s\n' "$out" | awk '
        /Self-test execution status/ {print; getline; if ($0 ~ /%/) print; next}
        /Self-test routine in progress/ {print; next}
        /No self-tests have been logged/ {print; next}
        /SMART Self-test log/ {show=1; print; next}
        show && /^#/ {print; count++; if (count >= 5) exit}
    '
}

cc_storage_test_start() {
    local device="$1" kind="$2" out estimate
    cc_storage_require_smartctl || return $?
    cc_storage_require_device "$device" || return $?
    cc_log "Starting SMART $kind self-test on $device"
    out="$(cc_storage_run_smartctl -t "$kind" "$device" 2>&1 || true)"
    printf '%s\n' "$out"
    estimate="$(printf '%s\n' "$out" | grep -Ei 'Please wait|completion|after' || true)"
    echo
    if [ -n "$estimate" ]; then
        printf '%-12s %s\n' "Estimate:" "$estimate"
    fi
    printf '%-12s %s\n' "Check:" "cc drive-test status $device"
}

# -----------------------------------------------------------------------------
# Component 3 verification API.  These records are intentionally separate from
# the legacy lifecycle helpers above: they are local, passive, and never sudo.
# Stable TSV schemas:
# device path,stable_id,by_path,kernel_name,parent,type,model,serial,wwn,
# size_bytes,logical_sector_bytes,transport,removable,read_only,state
# mount target,source,filesystem,device_id,options,read_only,size_bytes,
# used_bytes,available_bytes,usage_percent,state
# redundancy kind,name,member_id,role,member_state,redundancy_level,state
# zfs_pool name,health,scan_state,capacity_percent,readonly,state
# zfs_dataset name,pool,mounted,mountpoint,used_bytes,available_bytes,readonly,state
# finding state,code,layer,subject,message,evidence_source,observed_at

_cc_storage_platform() { uname -s 2>/dev/null || printf '%s\n' unknown; }
_cc_storage_command() { command -v "$1" >/dev/null 2>&1; }
_cc_storage_linux_supported() { [ "$(_cc_storage_platform)" = Linux ]; }

_cc_storage_linux_devices_raw() {
    local program="${CC_STORAGE_LSBLK_PROGRAM:-lsblk}"
    "$program" -b -P -o PATH,NAME,KNAME,PKNAME,TYPE,MODEL,SERIAL,WWN,SIZE,LOG-SEC,TRAN,RM,RO 2>/dev/null
}

_cc_storage_unescape_lsblk() {
    printf '%s' "$1" | sed -e 's/\\x20/ /g' -e 's/\\x22/"/g' -e 's/\\x5c/\\/g'
}

_cc_storage_pair_value() {
    [ "$#" -eq 2 ] || return 2
    printf '%s\n' "$1" | sed -n "s/.*\\(^\\|[[:space:]]\\)$2=\"\\([^\"]*\\)\".*/\\2/p"
}

_cc_storage_stable_link() {
    [ "$#" -eq 2 ] || return 2
    local directory="$1" device="$2" link target
    [ -d "$directory" ] || return 0
    for link in "$directory"/*; do
        [ -L "$link" ] || continue
        target="$(readlink -f -- "$link" 2>/dev/null || true)"
        [ "$target" = "$device" ] || continue
        printf '%s\n' "$link"
        return 0
    done
}

_cc_storage_linux_devices_tsv() {
    local line path name kname parent type model serial wwn size sector tran rm ro stable bypath state
    while IFS= read -r line; do
        path="$(_cc_storage_pair_value "$line" PATH)"; name="$(_cc_storage_pair_value "$line" NAME)"; kname="$(_cc_storage_pair_value "$line" KNAME)"
        parent="$(_cc_storage_pair_value "$line" PKNAME)"; type="$(_cc_storage_pair_value "$line" TYPE)"; model="$(_cc_storage_pair_value "$line" MODEL)"
        serial="$(_cc_storage_pair_value "$line" SERIAL)"; wwn="$(_cc_storage_pair_value "$line" WWN)"; size="$(_cc_storage_pair_value "$line" SIZE)"
        sector="$(_cc_storage_pair_value "$line" LOG-SEC)"; tran="$(_cc_storage_pair_value "$line" TRAN)"; rm="$(_cc_storage_pair_value "$line" RM)"; ro="$(_cc_storage_pair_value "$line" RO)"
        path="$(_cc_storage_unescape_lsblk "$path")"; model="$(_cc_storage_unescape_lsblk "$model")"; serial="$(_cc_storage_unescape_lsblk "$serial")"
        [ -n "$path" ] || continue
        case "$type:$kname" in loop:*|disk:zram*|disk:ram*) state=pseudo;; *) state=observed;; esac
        stable="$(_cc_storage_stable_link "${CC_STORAGE_BY_ID_DIR:-/dev/disk/by-id}" "$path")"
        bypath="$(_cc_storage_stable_link "${CC_STORAGE_BY_PATH_DIR:-/dev/disk/by-path}" "$path")"
        [ -n "$stable" ] || stable="${wwn:-$path}"
        [ -n "$parent" ] && parent="/dev/$parent"
        name="${name:-unknown}"; kname="${kname:-unknown}"; parent="${parent:-unknown}"; type="${type:-unknown}"
        model="${model:-unknown}"; serial="${serial:-unknown}"; wwn="${wwn:-unknown}"; size="${size:-unknown}"
        sector="${sector:-unknown}"; tran="${tran:-unknown}"; rm="${rm:-unknown}"; ro="${ro:-unknown}"; bypath="${bypath:-unknown}"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$path" "$stable" "$bypath" "$kname" "$parent" "$type" "$model" "$serial" "$wwn" \
            "${size:-unknown}" "${sector:-unknown}" "${tran:-unknown}" "${rm:-unknown}" "${ro:-unknown}" "$state"
    done < <(_cc_storage_linux_devices_raw)
}

cc_storage_devices_tsv() {
    if _cc_storage_linux_supported; then _cc_storage_linux_devices_tsv
    else printf 'unknown\tunknown\tunknown\tunknown\tunknown\tunknown\tunknown\tunknown\tunknown\tunknown\tunknown\tunknown\tunknown\tunknown\tunsupported\n'; fi
}

_cc_storage_linux_mounts_raw() {
    local program="${CC_STORAGE_FINDMNT_PROGRAM:-findmnt}"
    "$program" -n -b -P -o TARGET,SOURCE,FSTYPE,OPTIONS,SIZE,USED,AVAIL,USE% 2>/dev/null
}

_cc_storage_mount_device_id() {
    local source="$1" path stable _
    case "$source" in /dev/*) ;; *) printf '%s\n' "$source"; return;; esac
    stable="$(_cc_storage_stable_link "${CC_STORAGE_BY_ID_DIR:-/dev/disk/by-id}" "$source")"
    printf '%s\n' "${stable:-$source}"
}

_cc_storage_linux_mounts_tsv() {
    local line target source filesystem options size used available percent ro state device_id
    while IFS= read -r line; do
        target="$(_cc_storage_pair_value "$line" TARGET)"; source="$(_cc_storage_pair_value "$line" SOURCE)"; filesystem="$(_cc_storage_pair_value "$line" FSTYPE)"; options="$(_cc_storage_pair_value "$line" OPTIONS)"
        size="$(_cc_storage_pair_value "$line" SIZE)"; used="$(_cc_storage_pair_value "$line" USED)"; available="$(_cc_storage_pair_value "$line" AVAIL)"; percent="$(_cc_storage_pair_value "$line" USE%)"
        [ -n "$target" ] || continue
        source="${source:-unknown}"; filesystem="${filesystem:-unknown}"; options="${options:-unknown}"
        size="${size:-unknown}"; used="${used:-unknown}"; available="${available:-unknown}"; percent="${percent:-unknown}"
        ro=0; case ",$options," in *,ro,*) ro=1;; esac
        state=mounted
        case "$filesystem" in
            proc|sysfs|tmpfs|devtmpfs|devpts|cgroup*|mqueue|overlay|squashfs|securityfs|pstore|bpf|debugfs|tracefs|configfs|fusectl|fuse.*|autofs|nsfs|efivarfs|binfmt_misc)
                state=pseudo
                ;;
        esac
        [ "$ro" = 1 ] && [ "$state" != pseudo ] && state="readonly"
        percent="${percent%%%}"; device_id="$(_cc_storage_mount_device_id "$source")"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$target" "$source" "$filesystem" "$device_id" "$options" "$ro" "${size:-unknown}" "${used:-unknown}" "${available:-unknown}" "${percent:-unknown}" "$state"
    done < <(_cc_storage_linux_mounts_raw)
}

cc_storage_mounts_tsv() {
    if _cc_storage_linux_supported && _cc_storage_command "${CC_STORAGE_FINDMNT_PROGRAM:-findmnt}"; then _cc_storage_linux_mounts_tsv
    else printf 'unknown\tunknown\tunknown\tunknown\tunknown\tunknown\tunknown\tunknown\tunknown\tunknown\tunsupported\n'; fi
}

_cc_storage_mdstat_path() { printf '%s\n' "${CC_STORAGE_MDSTAT_PATH:-/proc/mdstat}"; }
# Array-level records preserve unavailable member identity as unknown rather
# than inventing a disk relationship from incomplete mdstat evidence.
cc_storage_redundancy_tsv() {
    local path line name level state activity block
    _cc_storage_linux_supported || { printf 'mdraid\tunknown\tunknown\tunknown\tunknown\tunknown\tunsupported\n'; return; }
    path="$(_cc_storage_mdstat_path)"
    [ -r "$path" ] || { printf 'mdraid\tunknown\tunknown\tunknown\tunknown\tunknown\tunknown\n'; return; }
    while IFS= read -r line; do
        [[ "$line" =~ ^md[0-9]+[[:space:]] ]] || continue
        name="${line%% *}"; level="$(printf '%s\n' "$line" | awk '{for(i=1;i<=NF;i++) if($i ~ /^raid/) {print $i; exit}}')"
        state=healthy
        block="$(awk -v array="$name" '$1==array {seen=1} seen {print} seen && /^$/ {exit}' "$path")"
        if [[ "$block" == *"[_"* || "$block" == *"_]"* ]]; then state=degraded; fi
        printf 'mdraid\t%s\tunknown\tarray\t%s\t%s\t%s\n' "$name" "$state" "${level:-unknown}" "$state"
    done < "$path"
    activity="$(grep -E 'recovery|resync|reshape' "$path" 2>/dev/null || true)"
    if [ -n "$activity" ]; then printf 'mdraid\tactive\tunknown\tarray\trecovering\tunknown\trecovering\n'; fi
}

_cc_storage_zpool_program() { printf '%s\n' "${CC_STORAGE_ZPOOL_PROGRAM:-zpool}"; }
_cc_storage_zfs_program() { printf '%s\n' "${CC_STORAGE_ZFS_PROGRAM:-zfs}"; }
cc_storage_zfs_pools_tsv() {
    local zpool name health capacity state scan output
    zpool="$(_cc_storage_zpool_program)"
    if ! _cc_storage_linux_supported; then printf 'unknown\tunknown\tunknown\tunknown\tunknown\tunsupported\n'; return; fi
    if ! _cc_storage_command "$zpool"; then printf 'unknown\tunknown\tunknown\tunknown\tunknown\tunsupported\n'; return; fi
    output="$("$zpool" list -H -o name,health,capacity 2>/dev/null)" || { printf 'unknown\tunknown\tunknown\tunknown\tunknown\trestricted\n'; return; }
    printf '%s\n' "$output" | while IFS=$'\t' read -r name health capacity; do
        state=PASS; case "$health" in ONLINE) ;; DEGRADED) state=WARN;; FAULTED|UNAVAIL|OFFLINE) state=FAIL;; *) state=unknown;; esac
        scan="$($zpool status "$name" 2>/dev/null | awk '/scan:/{sub(/^[[:space:]]*scan:[[:space:]]*/,""); print; exit}')"
        printf '%s\t%s\t%s\t%s\tunknown\t%s\n' "$name" "$health" "${scan:-unknown}" "${capacity%%%}" "$state"
    done
}

cc_storage_zfs_datasets_tsv() {
    local zfs name available used mounted mountpoint readonly_state pool state output
    zfs="$(_cc_storage_zfs_program)"
    if ! _cc_storage_linux_supported || ! _cc_storage_command "$zfs"; then printf 'unknown\tunknown\tunknown\tunknown\tunknown\tunknown\tunknown\tunsupported\n'; return; fi
    output="$("$zfs" list -H -p -o name,available,used,mounted,mountpoint,readonly -t filesystem 2>/dev/null)" || { printf 'unknown\tunknown\tunknown\tunknown\tunknown\tunknown\tunknown\trestricted\n'; return; }
    printf '%s\n' "$output" | while IFS=$'\t' read -r name available used mounted mountpoint readonly_state; do
        pool="${name%%/*}"; state="mounted"; [ "$readonly_state" = on ] && state="readonly"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$pool" "$mounted" "$mountpoint" "$used" "$available" "$readonly_state" "$state"
    done
}

cc_storage_snapshot_reset() { CC_STORAGE_SNAPSHOT_READY=0; CC_STORAGE_DEVICES=""; CC_STORAGE_MOUNTS=""; CC_STORAGE_REDUNDANCY=""; CC_STORAGE_ZFS_POOLS=""; CC_STORAGE_ZFS_DATASETS=""; }
cc_storage_snapshot() {
    [ "${CC_STORAGE_SNAPSHOT_READY:-0}" -eq 1 ] && return 0
    CC_STORAGE_DEVICES="$(cc_storage_devices_tsv 2>/dev/null || true)"
    CC_STORAGE_MOUNTS="$(cc_storage_mounts_tsv 2>/dev/null || true)"
    CC_STORAGE_REDUNDANCY="$(cc_storage_redundancy_tsv 2>/dev/null || true)"
    CC_STORAGE_ZFS_POOLS="$(cc_storage_zfs_pools_tsv 2>/dev/null || true)"
    CC_STORAGE_ZFS_DATASETS="$(cc_storage_zfs_datasets_tsv 2>/dev/null || true)"
    export CC_STORAGE_DEVICES CC_STORAGE_MOUNTS CC_STORAGE_REDUNDANCY CC_STORAGE_ZFS_POOLS CC_STORAGE_ZFS_DATASETS
    CC_STORAGE_SNAPSHOT_READY=1
}

cc_storage_local_findings_tsv() {
    cc_storage_snapshot
    local now
    now="$(date -Iseconds 2>/dev/null || date)"
    while IFS=$'\t' read -r target _ _ _ _ ro _ _ _ percent state; do
        [ -n "$target" ] || continue
        [ "$state" = pseudo ] && continue
        [ "$ro" = 1 ] && printf 'FAIL\tFILESYSTEM_READONLY\tmount\t%s\tmount is read-only\tfindmnt\t%s\n' "$target" "$now"
        [[ "$percent" =~ ^[0-9]+$ ]] && [ "$percent" -ge "${CC_STORAGE_CAPACITY_WARN_PERCENT:-90}" ] && printf 'WARN\tCAPACITY_PRESSURE\tmount\t%s\tfilesystem usage is %s%%\tfindmnt\t%s\n' "$target" "$percent" "$now"
    done <<<"$CC_STORAGE_MOUNTS"
    while IFS=$'\t' read -r kind name _ _ _ _ state; do
        [ "$kind" = mdraid ] || continue
        [ "$state" = degraded ] && printf 'WARN\tMDRAID_DEGRADED\tredundancy\t%s\tmdraid array is degraded\t/proc/mdstat\t%s\n' "$name" "$now"
        [ "$state" = recovering ] && printf 'WARN\tMDRAID_RECOVERING\tredundancy\t%s\tmdraid recovery or resync observed\t/proc/mdstat\t%s\n' "$name" "$now"
    done <<<"$CC_STORAGE_REDUNDANCY"
    while IFS=$'\t' read -r name health scan _ readonly state; do
        case "$health" in DEGRADED) printf 'WARN\tZFS_POOL_DEGRADED\tzfs\t%s\tZFS pool is degraded\tzpool\t%s\n' "$name" "$now";; FAULTED|UNAVAIL|OFFLINE) printf 'FAIL\tZFS_POOL_FAULTED\tzfs\t%s\tZFS pool is unavailable or faulted\tzpool\t%s\n' "$name" "$now";; esac
        [ "$readonly" = on ] && printf 'WARN\tZFS_READONLY\tzfs\t%s\tZFS pool is read-only\tzpool\t%s\n' "$name" "$now"
        [[ "$scan" == *"with 0 errors"* || "$scan" = unknown ]] || [ -z "$scan" ] || printf 'WARN\tZFS_SCRUB_ERRORS\tzfs\t%s\tZFS scan requires review\tzpool\t%s\n' "$name" "$now"
    done <<<"$CC_STORAGE_ZFS_POOLS"
}

cc_storage_smart_findings_tsv() {
    local path stable _ access _ _ health _ _ _ _ state now
    now="$(date -Iseconds 2>/dev/null || date)"
    cc_storage_snapshot
    while IFS=$'\t' read -r path stable _ _ _ type _ _ _ _ _ _ _ _ observed; do
        [ "$type" = disk ] || continue
        [ "$observed" = observed ] || continue
        IFS=$'\t' read -r _ access _ _ health _ _ _ _ _ state < <(cc_smart_record_tsv "$stable" "$path")
        [ "$access" = restricted ] && printf 'WARN\tSMART_ACCESS_RESTRICTED\tmedia\t%s\tSMART requires privileges or is inaccessible\tsmartctl\t%s\n' "$stable" "$now"
        case "$health" in *FAIL*|*BAD*) printf 'FAIL\tSMART_HEALTH_FAILED\tmedia\t%s\tSMART health reports failure\tsmartctl\t%s\n' "$stable" "$now";; esac
    done <<<"$CC_STORAGE_DEVICES"
}
