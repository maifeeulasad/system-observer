#!/usr/bin/env bash
# pinger.sh — runs one ping probe and parses the result. Namespace: pinger_*
#
# Uses iputils-ping (default on Ubuntu). Does NOT require root.

[[ -n "${__NET_PINGER_SH_LOADED:-}" ]] && return 0
__NET_PINGER_SH_LOADED=1

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# pinger_probe <addr> <count> <timeout_s>
# Prints: "<status> <rtt_ms> <ttl> <loss_pct>"
# Fields that cannot be determined are printed as empty tokens (quoted "" in
# the output to keep field count stable).
pinger_probe() {
    local addr="$1" count="$2" timeout="$3"
    local out rc status rtt ttl loss

    # -n: no DNS on response. -q: quiet, summary only. -W: per-reply timeout.
    out="$(ping -n -q -c "$count" -W "$timeout" -- "$addr" 2>&1)"
    rc=$?

    rtt=""
    ttl=""
    loss=""
    status="error"

    # Pull "X% packet loss" from the summary line.
    if [[ "$out" =~ ([0-9]+)%\ packet\ loss ]]; then
        loss="${BASH_REMATCH[1]}"
    fi

    # Pull avg RTT: "rtt min/avg/max/mdev = 0.123/0.456/0.789/0.100 ms"
    if [[ "$out" =~ =\ [0-9.]+/([0-9.]+)/ ]]; then
        rtt="${BASH_REMATCH[1]}"
    fi

    if (( rc == 0 )) && [[ -n "$loss" && "$loss" != "100" ]]; then
        status="ok"
    elif [[ "$out" == *"Destination Host Unreachable"* \
         || "$out" == *"Network is unreachable"* \
         || "$out" == *"Name or service not known"* ]]; then
        status="unreachable"
    elif [[ "$loss" == "100" ]]; then
        status="timeout"
    else
        status="error"
    fi

    # ttl is per-reply; with -q we don't get it. Leave empty — intentional, see
    # LOG_FORMAT.md. (Dropping -q to parse per-reply ttl costs CPU for little
    # gain; the summary is what matters.)

    printf '%s %s %s %s\n' "$status" "$rtt" "$ttl" "$loss"
}
