#!/usr/bin/env bash
# config.sh — loads net.conf and servers.conf. Namespace: config_*
#
# After config_load:
#   $CFG_INTERVAL, $CFG_PING_COUNT, $CFG_PING_TIMEOUT, $CFG_LOG_DIR,
#   $CFG_LOG_RETENTION_DAYS, $CFG_SOURCE_NAME, $CFG_PING_SELF
#   CFG_TARGET_NAMES[]  — parallel arrays
#   CFG_TARGET_ADDRS[]

[[ -n "${__NET_CONFIG_SH_LOADED:-}" ]] && return 0
__NET_CONFIG_SH_LOADED=1

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Defaults — overridden by net.conf.
CFG_INTERVAL=10
CFG_PING_COUNT=1
CFG_PING_TIMEOUT=2
CFG_LOG_DIR=/var/log/net
CFG_LOG_RETENTION_DAYS=30
CFG_SOURCE_NAME=""
CFG_PING_SELF=1

CFG_TARGET_NAMES=()
CFG_TARGET_ADDRS=()

# config_load <net.conf-path> <servers.conf-path>
config_load() {
    local net_conf="$1"
    local servers_conf="$2"

    [[ -r "$net_conf" ]] || common_die "config: cannot read $net_conf"
    [[ -r "$servers_conf" ]] || common_die "config: cannot read $servers_conf"

    # net.conf is sourced; it's KEY=VALUE only, no commands expected.
    # Variables land as INTERVAL, PING_COUNT, ... then we copy them into CFG_*.
    # shellcheck disable=SC1090
    source "$net_conf"

    CFG_INTERVAL="${INTERVAL:-$CFG_INTERVAL}"
    CFG_PING_COUNT="${PING_COUNT:-$CFG_PING_COUNT}"
    CFG_PING_TIMEOUT="${PING_TIMEOUT:-$CFG_PING_TIMEOUT}"
    CFG_LOG_DIR="${LOG_DIR:-$CFG_LOG_DIR}"
    CFG_LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-$CFG_LOG_RETENTION_DAYS}"
    CFG_PING_SELF="${PING_SELF:-$CFG_PING_SELF}"
    CFG_SOURCE_NAME="${SOURCE_NAME:-$(common_hostname)}"

    config__load_servers "$servers_conf"
}

config__load_servers() {
    local file="$1" name addr line
    CFG_TARGET_NAMES=()
    CFG_TARGET_ADDRS=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        [[ -z "$line" ]] && continue
        read -r name addr _ <<<"$line"
        [[ -z "$name" || -z "$addr" ]] && continue
        CFG_TARGET_NAMES+=("$name")
        CFG_TARGET_ADDRS+=("$addr")
    done <"$file"

    (( ${#CFG_TARGET_NAMES[@]} > 0 )) \
        || common_die "config: no targets found in $file"
}
