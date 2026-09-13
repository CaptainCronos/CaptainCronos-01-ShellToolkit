#!/usr/bin/env bash
#
# Bounded, read-only storage diagnostic log evidence.  Raw journal syntax is
# confined to cc-services.sh; this library only classifies finite evidence.

if ! declare -F _cc_log_since >/dev/null 2>&1; then
    _cc_storage_logs_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    source "$_cc_storage_logs_dir/cc-services.sh"
    unset _cc_storage_logs_dir
fi

cc_storage_log_since_tsv() {
    [ "$#" -eq 1 ] || return 2
    _cc_log_since "$1" "${CC_STORAGE_LOG_LIMIT:-1000}"
}

# finding: state, code, layer, subject, message, evidence_source, observed_at
cc_storage_log_findings_tsv() {
    [ "$#" -eq 1 ] || return 2
    cc_storage_log_since_tsv "$1" 2>/dev/null | awk '
        function emit(state,code,layer,subject,msg) { print state "\t" code "\t" layer "\t" subject "\t" msg "\tjournal\t" $1 " " $2 }
        { line=$0; subject="host"; if (match(line, /\/(dev\/)?(sd[a-z]+|nvme[0-9]+n[0-9]+|md[0-9]+|dm-[0-9]+)/)) subject=substr(line,RSTART,RLENGTH) }
        /USB disconnect|usb .*disconnect/ { emit("WARN","USB_DISCONNECT","usb",subject,"USB disconnect observed"); next }
        /reset (SuperSpeed |high-speed )?USB device|usb .*reset/ { emit("WARN","USB_RESET","usb",subject,"USB reset observed"); next }
        /UAS.*(timeout|abort)|uas.*(timeout|abort)/ { emit("WARN","USB_UAS_TIMEOUT","usb",subject,"USB UAS timeout or abort observed"); next }
        /(device offline|Device offlined)/ { emit("WARN","DEVICE_OFFLINE","usb",subject,"device offline event observed"); next }
        /blk_update_request|Buffer I\/O error|medium error|I\/O error|I\/O timeout/ { emit("FAIL","BLOCK_IO_ERROR","kernel_io",subject,"kernel block I/O error observed"); next }
        /(EXT4-fs error|XFS.*(error|corruption)|BTRFS.*(error|warning))/ { emit("WARN","FILESYSTEM_ERROR","filesystem",subject,"filesystem error observed"); next }
        /(Remounting filesystem read-only|remount-ro|Read-only file system)/ { emit("FAIL","FILESYSTEM_READONLY","mount",subject,"filesystem remounted or reported read-only"); next }'
}
