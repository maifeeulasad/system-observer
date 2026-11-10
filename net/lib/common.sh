#!/usr/bin/env bash
# common.sh — shared helpers. "Namespace": common_*
#
# Source once from every entrypoint. Idempotent via guard.

[[ -n "${__NET_COMMON_SH_LOADED:-}" ]] && return 0
__NET_COMMON_SH_LOADED=1

set -u
set -o pipefail

# Resolve the net/ root regardless of where we're sourced from.
# Callers should set NET_ROOT; if not, infer from this file's location.
if [[ -z "${NET_ROOT:-}" ]]; then
    NET_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
export NET_ROOT

# ISO-8601 UTC timestamp with millisecond precision.
common_ts_iso() {
    date -u +"%Y-%m-%dT%H:%M:%S.%3NZ"
}

# Epoch seconds (integer).
common_ts_epoch() {
    date -u +"%s"
}

# Today, UTC, as YYYY-MM-DD. Used for log rotation.
common_today() {
    date -u +"%Y-%m-%d"
}

# Short hostname, with underscores for anything odd.
common_hostname() {
    hostname -s 2>/dev/null | tr -c 'A-Za-z0-9_-' '_'
}

# Structured stderr for operator messages (not the ping log).
common_log() {
    local level="$1"; shift
    printf '%s [%s] %s\n' "$(common_ts_iso)" "$level" "$*" >&2
}

common_die() {
    common_log ERROR "$*"
    exit 1
}
