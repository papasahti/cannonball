#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${CANNONBALL_IMAGE_NAME:-cannonball:quickstart}"
CONTAINER_NAME="${CANNONBALL_CONTAINER_NAME:-cannonball-quickstart}"
POSTGRES_CONTAINER_NAME="${CANNONBALL_POSTGRES_CONTAINER_NAME:-cannonball-quickstart-postgres}"
NETWORK_NAME="${CANNONBALL_NETWORK_NAME:-cannonball-quickstart}"
HOST_PORT="${CANNONBALL_PORT:-8081}"
DATA_DIR="${CANNONBALL_DATA_DIR:-$ROOT_DIR/.quickstart-data}"
POSTGRES_DATA_DIR="${CANNONBALL_POSTGRES_DATA_DIR:-$DATA_DIR/postgres}"
APP_TITLE="${CANNONBALL_APP_TITLE:-cannonball}"
APP_USERNAME="${CANNONBALL_APP_USERNAME:-admin}"
APP_ADMIN_DISPLAY_NAME="${CANNONBALL_ADMIN_DISPLAY_NAME:-Quick Start Admin}"
PUBLIC_URL="${CANNONBALL_PUBLIC_URL:-http://127.0.0.1:${HOST_PORT}}"
POSTGRES_DB="${CANNONBALL_POSTGRES_DB:-cannonball}"
POSTGRES_USER="${CANNONBALL_POSTGRES_USER:-cannonball}"
POSTGRES_PASSWORD="${CANNONBALL_POSTGRES_PASSWORD:-cannonball}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

require_command docker

mkdir -p "$DATA_DIR"
mkdir -p "$POSTGRES_DATA_DIR"
chmod 0777 "$POSTGRES_DATA_DIR"

if docker ps -a --format '{{.Names}}' | grep -Fx "$CONTAINER_NAME" >/dev/null 2>&1; then
  echo "Removing existing container $CONTAINER_NAME"
  docker rm -f "$CONTAINER_NAME" >/dev/null
fi

if docker ps -a --format '{{.Names}}' | grep -Fx "$POSTGRES_CONTAINER_NAME" >/dev/null 2>&1; then
  echo "Removing existing container $POSTGRES_CONTAINER_NAME"
  docker rm -f "$POSTGRES_CONTAINER_NAME" >/dev/null
fi

if ! docker network ls --format '{{.Name}}' | grep -Fx "$NETWORK_NAME" >/dev/null 2>&1; then
  docker network create "$NETWORK_NAME" >/dev/null
fi

APP_PASSWORD="${CANNONBALL_APP_PASSWORD:-adminadmin}"

echo "Building Docker image $IMAGE_NAME"
docker build -t "$IMAGE_NAME" "$ROOT_DIR"

echo "Starting PostgreSQL container $POSTGRES_CONTAINER_NAME"
docker run -d \
  --name "$POSTGRES_CONTAINER_NAME" \
  --network "$NETWORK_NAME" \
  -v "${POSTGRES_DATA_DIR}:/var/lib/postgresql/data" \
  -e POSTGRES_DB="$POSTGRES_DB" \
  -e POSTGRES_USER="$POSTGRES_USER" \
  -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  postgres:17-alpine >/dev/null

echo "Waiting for PostgreSQL to accept connections"
for _ in $(seq 1 30); do
  if docker exec "$POSTGRES_CONTAINER_NAME" pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

echo "Starting container $CONTAINER_NAME on port $HOST_PORT"
docker run -d \
  --name "$CONTAINER_NAME" \
  --network "$NETWORK_NAME" \
  -p "${HOST_PORT}:8080" \
  -e PORT=8080 \
  -e DATABASE_DRIVER=postgres \
  -e DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_CONTAINER_NAME}:5432/${POSTGRES_DB}" \
  -e APP_TITLE="$APP_TITLE" \
  -e APP_USERNAME="$APP_USERNAME" \
  -e APP_ADMIN_DISPLAY_NAME="$APP_ADMIN_DISPLAY_NAME" \
  -e APP_PASSWORD="$APP_PASSWORD" \
  -e APP_FORCE_BOOTSTRAP_PASSWORD_SYNC=true \
  -e AUTH_DEBUG_LOGGING=true \
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
echo "  docker rm -f $CONTAINER_NAME $POSTGRES_CONTAINER_NAME"
echo
echo "Recent container logs:"
docker logs "$CONTAINER_NAME"
