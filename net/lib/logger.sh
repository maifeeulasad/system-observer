#!/usr/bin/env bash
# logger.sh — writes ping samples as CSV. Namespace: logger_*
#
# File layout:
#   $LOG_DIR/YYYY-MM-DD/ping-<source>.csv
#
# CSV columns (see docs/LOG_FORMAT.md):
#   ts_iso,ts_epoch,source,target_name,target_addr,status,rtt_ms,ttl,loss_pct
#
# status is one of: ok, timeout, unreachable, error
# Missing numeric fields are written as empty (consumer: treat as NaN/null).

[[ -n "${__NET_LOGGER_SH_LOADED:-}" ]] && return 0
__NET_LOGGER_SH_LOADED=1

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

LOGGER_CSV_HEADER='ts_iso,ts_epoch,source,target_name,target_addr,status,rtt_ms,ttl,loss_pct'

# logger_path <log_dir> <source_name>  -> echoes current day's file path
logger_path() {
    local log_dir="$1" source_name="$2"
    local day; day="$(common_today)"
    printf '%s/%s/ping-%s.csv' "$log_dir" "$day" "$source_name"
}

# logger_ensure <log_dir> <source_name>
# Creates the daily dir and writes the CSV header if the file is new.
logger_ensure() {
    local log_dir="$1" source_name="$2"
    local file; file="$(logger_path "$log_dir" "$source_name")"
    local dir; dir="$(dirname "$file")"
    mkdir -p "$dir"
    if [[ ! -s "$file" ]]; then
        printf '%s\n' "$LOGGER_CSV_HEADER" >"$file"
    fi
    printf '%s' "$file"
}

# logger_write <file> <source> <target_name> <target_addr> <status> <rtt_ms> <ttl> <loss_pct>
# Appends one CSV row. Caller is responsible for field sanity (no commas/newlines).
logger_write() {
    local file="$1" source="$2" tname="$3" taddr="$4"
    local status="$5" rtt="$6" ttl="$7" loss="$8"
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$(common_ts_iso)" "$(common_ts_epoch)" \
        "$source" "$tname" "$taddr" \
        "$status" "$rtt" "$ttl" "$loss" \
        >>"$file"
}

# logger_rotate <log_dir> <retention_days>
# Deletes day-directories older than retention_days. retention_days=0 disables.
logger_rotate() {
    local log_dir="$1" retention="$2"
    [[ "$retention" -gt 0 ]] || return 0
    [[ -d "$log_dir" ]] || return 0
    find "$log_dir" -mindepth 1 -maxdepth 1 -type d -mtime "+$retention" \
        -exec rm -rf {} + 2>/dev/null || true
}
