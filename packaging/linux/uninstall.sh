#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run uninstall.sh as root." >&2
  exit 1
fi

INSTALL_ROOT="${CANNONBALL_INSTALL_ROOT:-/opt/cannonball}"
CONFIG_ROOT="${CANNONBALL_CONFIG_ROOT:-/etc/cannonball}"
DATA_ROOT="${CANNONBALL_DATA_ROOT:-/var/lib/cannonball}"
SERVICE_PATH="/etc/systemd/system/cannonball.service"

systemctl disable --now cannonball.service >/dev/null 2>&1 || true
rm -f "${SERVICE_PATH}"
systemctl daemon-reload

rm -rf "${INSTALL_ROOT}"

echo "cannonball binaries removed."
echo "Config left in place: ${CONFIG_ROOT}"
echo "Data left in place: ${DATA_ROOT}"
echo "Remove them manually if you want a full cleanup."
