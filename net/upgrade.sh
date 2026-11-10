#!/usr/bin/env bash
# upgrade.sh — pull latest code and reinstall. Keeps config and logs.
#
#   sudo ./upgrade.sh                 # git pull then reinstall
#   sudo ./upgrade.sh --no-pull       # reinstall from current working tree
#
# Run from inside a git clone of the repo. The service is restarted at the
# end if it was running.

set -eu
set -o pipefail

SRC_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DO_PULL=1
[[ "${1:-}" == "--no-pull" ]] && DO_PULL=0

if [[ "$(id -u)" -ne 0 ]]; then
    echo "upgrade: must run as root" >&2; exit 1
fi

if (( DO_PULL )); then
    echo "[upgrade] git pull in $(dirname "$SRC_DIR")"
    git -C "$(dirname "$SRC_DIR")" pull --ff-only
fi

was_active=0
systemctl is-active --quiet net-monitor && was_active=1

"$SRC_DIR/install.sh"

if (( was_active )); then
    echo "[upgrade] restarting net-monitor"
    systemctl restart net-monitor
else
    echo "[upgrade] service was not running; not starting."
fi
