#!/usr/bin/env bash
# uninstall.sh — remove net-monitor. Keeps config and logs by default.
#
#   sudo ./uninstall.sh            # keep /etc/net and /var/log/net
#   sudo ./uninstall.sh --purge    # also remove them

set -eu
set -o pipefail

PURGE=0
[[ "${1:-}" == "--purge" ]] && PURGE=1

if [[ "$(id -u)" -ne 0 ]]; then
    echo "uninstall: must run as root" >&2; exit 1
fi

systemctl disable --now net-monitor.service 2>/dev/null || true
rm -f /etc/systemd/system/net-monitor.service
systemctl daemon-reload

rm -f /usr/local/sbin/net-monitor /usr/local/bin/net-parse
rm -rf /opt/net

if (( PURGE )); then
    rm -rf /etc/net /var/log/net
    echo "purged config and logs."
else
    echo "kept /etc/net and /var/log/net (use --purge to remove)."
fi
