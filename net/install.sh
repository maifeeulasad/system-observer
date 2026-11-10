#!/usr/bin/env bash
# install.sh — install net-monitor on Ubuntu.
#
# Idempotent. Run as root (sudo).
#
#   sudo ./install.sh
#
# Places:
#   /opt/net          — code (this repo's net/ dir, copied)
#   /etc/net          — config
#   /var/log/net      — logs
#   /etc/systemd/system/net-monitor.service

set -eu
set -o pipefail

SRC_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PREFIX="/opt/net"
CONF_DIR="/etc/net"
LOG_DIR="/var/log/net"
UNIT="/etc/systemd/system/net-monitor.service"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "install: must run as root (try: sudo $0)" >&2
    exit 1
fi

echo "[1/6] apt deps"
# iputils-ping is almost always present; ensure it. ca-certificates for git.
DEBIAN_FRONTEND=noninteractive apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq iputils-ping coreutils findutils gawk

echo "[2/6] copy code -> $PREFIX"
mkdir -p "$PREFIX"
# Overwrite code, keep /etc/net untouched below.
rsync -a --delete \
    --exclude 'logs/' \
    "$SRC_DIR"/ "$PREFIX"/
chmod +x "$PREFIX"/bin/net-monitor "$PREFIX"/bin/net-parse

# Convenience symlinks on PATH.
ln -sf "$PREFIX/bin/net-monitor" /usr/local/sbin/net-monitor
ln -sf "$PREFIX/bin/net-parse"   /usr/local/bin/net-parse

echo "[3/6] seed config -> $CONF_DIR"
mkdir -p "$CONF_DIR"
# Only install examples if the real file doesn't exist. Never overwrite the
# operator's edits on upgrade.
if [[ ! -f "$CONF_DIR/net.conf" ]]; then
    cp "$PREFIX/config/net.conf.example" "$CONF_DIR/net.conf"
    echo "    wrote $CONF_DIR/net.conf (defaults)"
fi
if [[ ! -f "$CONF_DIR/servers.conf" ]]; then
    cp "$PREFIX/config/servers.conf.example" "$CONF_DIR/servers.conf"
    echo "    wrote $CONF_DIR/servers.conf — EDIT THIS before starting the service"
fi
chmod 644 "$CONF_DIR"/*.conf

echo "[4/6] log dir -> $LOG_DIR"
mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

echo "[5/6] systemd unit"
install -m 0644 "$PREFIX/systemd/net-monitor.service" "$UNIT"
systemctl daemon-reload

echo "[6/6] enable"
systemctl enable net-monitor.service >/dev/null

cat <<EOF

installed.

  config:  $CONF_DIR/net.conf
           $CONF_DIR/servers.conf  <-- edit this
  logs:    $LOG_DIR/YYYY-MM-DD/ping-<host>.csv
  service: systemctl status net-monitor

next:
  1) edit $CONF_DIR/servers.conf (one 'name ip' per line)
  2) sudo systemctl start net-monitor
  3) net-parse --date today summary
EOF
