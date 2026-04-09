#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${CANNONBALL_IMAGE_NAME:-cannonball:quickstart}"
CONTAINER_NAME="${CANNONBALL_CONTAINER_NAME:-cannonball-quickstart}"
HOST_PORT="${CANNONBALL_PORT:-8081}"
DATA_DIR="${CANNONBALL_DATA_DIR:-$ROOT_DIR/.quickstart-data}"
APP_TITLE="${CANNONBALL_APP_TITLE:-cannonball}"
APP_USERNAME="${CANNONBALL_APP_USERNAME:-admin}"
APP_ADMIN_DISPLAY_NAME="${CANNONBALL_ADMIN_DISPLAY_NAME:-Quick Start Admin}"
PUBLIC_URL="${CANNONBALL_PUBLIC_URL:-http://127.0.0.1:${HOST_PORT}}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

generate_password() {
  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 18
}

require_command docker

mkdir -p "$DATA_DIR"

if docker ps -a --format '{{.Names}}' | grep -Fx "$CONTAINER_NAME" >/dev/null 2>&1; then
  echo "Removing existing container $CONTAINER_NAME"
  docker rm -f "$CONTAINER_NAME" >/dev/null
fi

APP_PASSWORD="${CANNONBALL_APP_PASSWORD:-$(generate_password)}"

echo "Building Docker image $IMAGE_NAME"
docker build -t "$IMAGE_NAME" "$ROOT_DIR"

echo "Starting container $CONTAINER_NAME on port $HOST_PORT"
docker run -d \
  --name "$CONTAINER_NAME" \
  -p "${HOST_PORT}:8080" \
  -v "${DATA_DIR}:/data" \
  -e PORT=8080 \
  -e DATABASE_PATH=/data/cannonball.db \
  -e APP_TITLE="$APP_TITLE" \
  -e APP_USERNAME="$APP_USERNAME" \
  -e APP_ADMIN_DISPLAY_NAME="$APP_ADMIN_DISPLAY_NAME" \
  -e APP_PASSWORD="$APP_PASSWORD" \
  -e APP_FORCE_BOOTSTRAP_PASSWORD_SYNC=true \
  -e ALLOW_INSECURE_COOKIE=true \
  -e CANNONBALL_PRINT_BOOTSTRAP_CREDENTIALS=true \
  -e CANNONBALL_PUBLIC_URL="$PUBLIC_URL" \
  "$IMAGE_NAME" >/dev/null

echo
echo "Container is up."
echo "URL: $PUBLIC_URL"
echo "Admin login: $APP_USERNAME"
echo "Admin password: $APP_PASSWORD"
echo
echo "Follow logs with:"
echo "  docker logs -f $CONTAINER_NAME"
echo
echo "Stop and remove with:"
echo "  docker rm -f $CONTAINER_NAME"
echo
echo "Recent container logs:"
docker logs "$CONTAINER_NAME"
