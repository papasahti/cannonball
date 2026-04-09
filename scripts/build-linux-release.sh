#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_ROOT="${ROOT_DIR}/build/linux-release"
PACKAGE_NAME="cannonball-linux-x64"
PACKAGE_DIR="${RELEASE_ROOT}/${PACKAGE_NAME}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

require_command dart
require_command tar

rm -rf "${PACKAGE_DIR}"
mkdir -p "${PACKAGE_DIR}/bin" "${PACKAGE_DIR}/web" "${PACKAGE_DIR}/packaging/linux"

echo "Resolving dependencies"
(cd "${ROOT_DIR}" && dart pub get)

echo "Building Linux binary"
(cd "${ROOT_DIR}" && dart compile exe bin/server.dart -o "${PACKAGE_DIR}/bin/cannonball")

echo "Copying runtime assets"
cp -R "${ROOT_DIR}/web/." "${PACKAGE_DIR}/web/"
cp "${ROOT_DIR}/packaging/linux/cannonball.service" "${PACKAGE_DIR}/packaging/linux/"
cp "${ROOT_DIR}/packaging/linux/cannonball.env.example" "${PACKAGE_DIR}/packaging/linux/"
cp "${ROOT_DIR}/packaging/linux/install.sh" "${PACKAGE_DIR}/"
cp "${ROOT_DIR}/packaging/linux/uninstall.sh" "${PACKAGE_DIR}/"
cp "${ROOT_DIR}/README.md" "${PACKAGE_DIR}/"
chmod +x "${PACKAGE_DIR}/install.sh" "${PACKAGE_DIR}/uninstall.sh" "${PACKAGE_DIR}/bin/cannonball"

echo "Creating archive"
(cd "${RELEASE_ROOT}" && tar -czf "${PACKAGE_NAME}.tar.gz" "${PACKAGE_NAME}")

echo
echo "Linux release bundle created:"
echo "  ${RELEASE_ROOT}/${PACKAGE_NAME}.tar.gz"
