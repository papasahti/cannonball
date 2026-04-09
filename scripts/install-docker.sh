#!/usr/bin/env bash
set -euo pipefail

APP_NAME="cannonball"
INSTALL_DIR="${CANNONBALL_INSTALL_DIR:-/opt/cannonball-docker}"
DATA_DIR="${CANNONBALL_DATA_DIR:-/var/lib/cannonball}"
PORT="${CANNONBALL_PORT:-8080}"
PUBLIC_URL="${CANNONBALL_PUBLIC_URL:-http://127.0.0.1:${PORT}}"
APP_TITLE="${CANNONBALL_APP_TITLE:-cannonball}"
APP_USERNAME="${CANNONBALL_APP_USERNAME:-admin}"
APP_ADMIN_DISPLAY_NAME="${CANNONBALL_ADMIN_DISPLAY_NAME:-Docker Admin}"
APP_ADMIN_EMAIL="${CANNONBALL_ADMIN_EMAIL:-admin@example.com}"
APP_PASSWORD="${CANNONBALL_APP_PASSWORD:-}"
REPO_ARCHIVE_URL="${CANNONBALL_REPO_ARCHIVE_URL:-}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

detect_compose() {
  if docker compose version >/dev/null 2>&1; then
    echo "docker compose"
    return
  fi
  if command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
    return
  fi
  echo "Docker Compose is required." >&2
  exit 1
}

generate_password() {
  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 18
}

prepare_source_dir() {
  if [ -f "./docker-compose.yml" ] && [ -f "./Dockerfile" ]; then
    pwd
    return
  fi

  if [ -z "$REPO_ARCHIVE_URL" ]; then
    echo "CANNONBALL_REPO_ARCHIVE_URL is required when the script is started outside the repository." >&2
    echo "Example:" >&2
    echo "  curl -fsSL https://gitlab.example.com/group/cannonball/-/raw/main/scripts/install-docker.sh | \\" >&2
    echo "    CANNONBALL_REPO_ARCHIVE_URL=https://gitlab.example.com/group/cannonball/-/archive/main/cannonball-main.tar.gz bash" >&2
    exit 1
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  echo "Downloading source archive..."
  curl -fsSL "$REPO_ARCHIVE_URL" -o "$tmp_dir/source.tar.gz"
  tar -xzf "$tmp_dir/source.tar.gz" -C "$tmp_dir"

  local extracted_dir
  extracted_dir="$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  if [ -z "$extracted_dir" ] || [ ! -f "$extracted_dir/docker-compose.yml" ]; then
    echo "Failed to unpack a valid cannonball source tree from archive." >&2
    exit 1
  fi

  echo "$extracted_dir"
}

write_env_file() {
  local target_dir="$1"
  local env_file="$target_dir/.env"

  if [ -f "$env_file" ]; then
    echo "Using existing .env in $target_dir"
    return
  fi

  cat >"$env_file" <<EOF
PORT=${PORT}
DATABASE_DRIVER=sqlite
DATABASE_PATH=/data/cannonball.db
APP_WEB_ROOT=/app/web
APP_USERNAME=${APP_USERNAME}
APP_ADMIN_DISPLAY_NAME=${APP_ADMIN_DISPLAY_NAME}
APP_ADMIN_EMAIL=${APP_ADMIN_EMAIL}
APP_PASSWORD=${APP_PASSWORD}
ALLOW_INSECURE_COOKIE=true
SESSION_TTL_HOURS=12
APP_TITLE=${APP_TITLE}
DELIVERY_MODE=mattermost
APP_BASE_URL=${PUBLIC_URL}
AUTH_MODE=local

MATTERMOST_BASE_URL=
MATTERMOST_TOKEN=
MATTERMOST_TEAM_ID=
MATTERMOST_TEAM_NAME=devops
MATTERMOST_CHANNELS=alerts,dev

N8N_BASE_URL=
N8N_WEBHOOK_URL=
N8N_API_KEY=
N8N_WEBHOOK_SECRET=
N8N_INBOUND_SECRET=

SMTP_HOST=
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_FROM_EMAIL=
SMTP_FROM_NAME=cannonball
SMTP_USE_SSL=false

KEYCLOAK_ISSUER_URL=
KEYCLOAK_CLIENT_ID=
KEYCLOAK_CLIENT_SECRET=
KEYCLOAK_SCOPES=openid profile email
KEYCLOAK_ADMIN_ROLE=cannonball-admin
EOF
}

write_compose_override() {
  local target_dir="$1"
  cat >"$target_dir/docker-compose.override.yml" <<EOF
services:
  cannonball:
    volumes:
      - ${DATA_DIR}:/data
EOF
}

install_source() {
  local source_dir="$1"

  mkdir -p "$INSTALL_DIR"
  mkdir -p "$DATA_DIR"

  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete \
      --exclude '.git' \
      --exclude '.dart_tool' \
      --exclude 'build' \
      --exclude '.quickstart-data' \
      "$source_dir"/ "$INSTALL_DIR"/
  else
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    cp -R "$source_dir"/. "$INSTALL_DIR"/
  fi
}

main() {
  require_command docker
  require_command curl

  local compose_cmd
  compose_cmd="$(detect_compose)"

  if [ -z "$APP_PASSWORD" ]; then
    APP_PASSWORD="$(generate_password)"
  fi

  local source_dir
  source_dir="$(prepare_source_dir)"

  echo "Installing $APP_NAME into $INSTALL_DIR"
  install_source "$source_dir"
  write_env_file "$INSTALL_DIR"
  write_compose_override "$INSTALL_DIR"

  cd "$INSTALL_DIR"

  echo "Starting Docker stack..."
  $compose_cmd up -d --build

  echo
  echo "$APP_NAME is up."
  echo "URL: $PUBLIC_URL"
  echo "Admin login: $APP_USERNAME"
  echo "Admin password: $APP_PASSWORD"
  echo
  echo "Project directory: $INSTALL_DIR"
  echo "Data directory: $DATA_DIR"
  echo
  echo "Check status with:"
  echo "  cd $INSTALL_DIR && $compose_cmd ps"
  echo
  echo "Follow logs with:"
  echo "  cd $INSTALL_DIR && $compose_cmd logs -f"
}

main "$@"
