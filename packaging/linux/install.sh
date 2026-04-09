#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run install.sh as root." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}"
INSTALL_ROOT="${CANNONBALL_INSTALL_ROOT:-/opt/cannonball}"
CONFIG_ROOT="${CANNONBALL_CONFIG_ROOT:-/etc/cannonball}"
DATA_ROOT="${CANNONBALL_DATA_ROOT:-/var/lib/cannonball}"
SERVICE_PATH="/etc/systemd/system/cannonball.service"
USER_NAME="${CANNONBALL_SYSTEM_USER:-cannonball}"
GROUP_NAME="${CANNONBALL_SYSTEM_GROUP:-cannonball}"

ensure_user() {
  if ! getent group "${GROUP_NAME}" >/dev/null 2>&1; then
    groupadd --system "${GROUP_NAME}"
  fi
  if ! id -u "${USER_NAME}" >/dev/null 2>&1; then
    useradd --system --home "${INSTALL_ROOT}" --gid "${GROUP_NAME}" --shell /usr/sbin/nologin "${USER_NAME}"
  fi
}

install -d -m 0755 "${INSTALL_ROOT}/bin" "${INSTALL_ROOT}/web" "${CONFIG_ROOT}" "${DATA_ROOT}"
ensure_user

install -m 0755 "${ROOT_DIR}/bin/cannonball" "${INSTALL_ROOT}/bin/cannonball"
cp -R "${ROOT_DIR}/web/." "${INSTALL_ROOT}/web/"
install -m 0644 "${ROOT_DIR}/packaging/linux/cannonball.service" "${SERVICE_PATH}"

if [[ ! -f "${CONFIG_ROOT}/cannonball.env" ]]; then
  install -m 0640 "${ROOT_DIR}/packaging/linux/cannonball.env.example" "${CONFIG_ROOT}/cannonball.env"
fi

chown -R "${USER_NAME}:${GROUP_NAME}" "${INSTALL_ROOT}" "${DATA_ROOT}"
chmod 0750 "${DATA_ROOT}"

systemctl daemon-reload
systemctl enable cannonball.service >/dev/null

echo "cannonball installed."
echo "Binary: ${INSTALL_ROOT}/bin/cannonball"
echo "Config: ${CONFIG_ROOT}/cannonball.env"
echo "Data: ${DATA_ROOT}"
echo
echo "Next steps:"
echo "1. Edit ${CONFIG_ROOT}/cannonball.env"
echo "2. Run: systemctl start cannonball"
echo "3. Check: systemctl status cannonball"
