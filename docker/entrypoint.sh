#!/bin/sh
set -eu

if [ "${CANNONBALL_PRINT_BOOTSTRAP_CREDENTIALS:-false}" = "true" ]; then
  echo "========================================"
  echo "cannonball quick start"
  echo "Admin login: ${APP_USERNAME:-admin}"
  echo "Admin password: ${APP_PASSWORD:-adminadmin}"
  echo "Open URL: ${CANNONBALL_PUBLIC_URL:-http://127.0.0.1:${PORT:-8080}}"
  echo "========================================"
fi

exec /app/cannonball
