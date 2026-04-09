#!/usr/bin/env bash

set -Eeuo pipefail

APP_NAME="cannonball"
SCRIPT_PATH="$0"
SCRIPT_DIR=""
REPO_ROOT_FROM_SCRIPT=""

if (set +u; [[ -n "${BASH_SOURCE[0]-}" ]]); then
  SCRIPT_PATH="${BASH_SOURCE[0]}"
fi

if [[ -n "${SCRIPT_PATH}" && "${SCRIPT_PATH}" != "bash" && "${SCRIPT_PATH}" != "-" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
  REPO_ROOT_FROM_SCRIPT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

if [[ "${EUID}" -eq 0 ]]; then
  DEFAULT_INSTALL_DIR="/opt/cannonball-docker"
  DEFAULT_DATA_DIR="/var/lib/cannonball"
else
  DEFAULT_INSTALL_DIR="${HOME}/cannonball-docker"
  DEFAULT_DATA_DIR="${HOME}/.local/share/cannonball"
fi

INSTALL_DIR="${CANNONBALL_INSTALL_DIR:-${DEFAULT_INSTALL_DIR}}"
DATA_DIR="${CANNONBALL_DATA_DIR:-${DEFAULT_DATA_DIR}}"
PORT_VALUE="${CANNONBALL_PORT:-8081}"
PUBLIC_URL="${CANNONBALL_PUBLIC_URL:-http://localhost:${PORT_VALUE}}"
ADMIN_LOGIN="${CANNONBALL_APP_USERNAME:-admin}"
ADMIN_NAME="${CANNONBALL_APP_ADMIN_DISPLAY_NAME:-System Administrator}"
ADMIN_EMAIL="${CANNONBALL_APP_ADMIN_EMAIL:-admin@example.com}"
APP_PASSWORD="${CANNONBALL_APP_PASSWORD:-adminadmin}"
REPO_ARCHIVE_URL="${CANNONBALL_REPO_ARCHIVE_URL:-}"
REPO_URL="${CANNONBALL_REPO_URL:-https://github.com/papasahti/cannonball.git}"
REPO_REF="${CANNONBALL_REPO_REF:-main}"

TMP_DIR=""
SOURCE_DIR=""
COMPOSE_CMD=""

cleanup() {
  if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
}

trap cleanup EXIT

log() {
  printf '[cannonball] %s\n' "$*"
}

fail() {
  printf '[cannonball] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Не найдена команда: $1"
}

detect_compose() {
  if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
    return
  fi

  if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
    return
  fi

  fail "Не найден docker compose или docker-compose"
}

set_env_value() {
  local file="$1"
  local key="$2"
  local value="$3"
  local escaped_value

  escaped_value="$(printf '%s' "${value}" | sed 's/[\/&]/\\&/g')"

  if grep -qE "^${key}=" "${file}"; then
    sed -i.bak "s/^${key}=.*/${key}=${escaped_value}/" "${file}"
  else
    printf '%s=%s\n' "${key}" "${value}" >>"${file}"
  fi

  rm -f "${file}.bak"
}

is_repo_root() {
  local candidate="$1"
  [[ -f "${candidate}/Dockerfile" && -f "${candidate}/docker-compose.yml" && -f "${candidate}/pubspec.yaml" ]]
}

find_repo_root() {
  local base_dir="$1"
  local compose_file=""
  local candidate=""

  if is_repo_root "${base_dir}"; then
    printf '%s\n' "${base_dir}"
    return
  fi

  while IFS= read -r compose_file; do
    candidate="$(dirname "${compose_file}")"
    if is_repo_root "${candidate}"; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done < <(find "${base_dir}" -type f -name 'docker-compose.yml' -print 2>/dev/null)

  return 1
}

normalize_repo_url() {
  local url="$1"

  url="${url%.git}"
  url="${url%/}"
  printf '%s\n' "${url}"
}

build_archive_url() {
  local repo_url

  repo_url="$(normalize_repo_url "$1")"

  case "${repo_url}" in
    https://github.com/*)
      printf '%s/archive/refs/heads/%s.tar.gz\n' "${repo_url}" "${REPO_REF}"
      ;;
    https://gitlab.*|https://*/gitlab/*|https://gitlab.com/*)
      printf '%s/-/archive/%s/%s-%s.tar.gz\n' \
        "${repo_url}" \
        "${REPO_REF}" \
        "$(basename "${repo_url}")" \
        "${REPO_REF}"
      ;;
    *)
      fail "Не умею собирать archive URL для ${repo_url}. Задай CANNONBALL_REPO_ARCHIVE_URL вручную."
      ;;
  esac
}

prepare_source_dir() {
  if is_repo_root "${PWD}"; then
    SOURCE_DIR="${PWD}"
    log "Использую текущий каталог репозитория: ${SOURCE_DIR}"
    return
  fi

  if [[ -n "${REPO_ROOT_FROM_SCRIPT}" ]] && is_repo_root "${REPO_ROOT_FROM_SCRIPT}"; then
    SOURCE_DIR="${REPO_ROOT_FROM_SCRIPT}"
    log "Использую каталог рядом со скриптом: ${SOURCE_DIR}"
    return
  fi

  if [[ -z "${REPO_ARCHIVE_URL}" ]]; then
    REPO_ARCHIVE_URL="$(build_archive_url "${REPO_URL}")"
  fi

  TMP_DIR="$(mktemp -d)"
  log "Скачиваю архив проекта из ${REPO_ARCHIVE_URL}"
  curl -fsSL "${REPO_ARCHIVE_URL}" -o "${TMP_DIR}/cannonball.tar.gz"
  mkdir -p "${TMP_DIR}/src"
  tar -xzf "${TMP_DIR}/cannonball.tar.gz" -C "${TMP_DIR}/src"
  SOURCE_DIR="$(find_repo_root "${TMP_DIR}/src" || true)"
  [[ -n "${SOURCE_DIR}" ]] || fail "В архиве не найден корректный корень репозитория"
  log "Архив распакован во временный каталог"
}

install_source() {
  [[ -n "${SOURCE_DIR}" ]] || fail "SOURCE_DIR не определён"

  log "Готовлю каталог установки: ${INSTALL_DIR}"
  mkdir -p "${INSTALL_DIR}"

  if [[ -d "${INSTALL_DIR}" ]]; then
    find "${INSTALL_DIR}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  fi

  tar \
    --exclude='.git' \
    --exclude='.dart_tool' \
    --exclude='build' \
    --exclude='.DS_Store' \
    -C "${SOURCE_DIR}" -cf - . | tar -C "${INSTALL_DIR}" -xf -
}

prepare_runtime_files() {
  mkdir -p "${DATA_DIR}"
  chmod 0777 "${DATA_DIR}"

  if [[ ! -f "${INSTALL_DIR}/.env" && -f "${INSTALL_DIR}/.env.example" ]]; then
    cp "${INSTALL_DIR}/.env.example" "${INSTALL_DIR}/.env"
  fi

  if [[ ! -f "${INSTALL_DIR}/.env" ]]; then
    cat >"${INSTALL_DIR}/.env" <<EOF
PORT=${PORT_VALUE}
DATABASE_DRIVER=sqlite
DATABASE_PATH=/data/cannonball.db
APP_WEB_ROOT=/app/web
APP_USERNAME=${ADMIN_LOGIN}
APP_ADMIN_DISPLAY_NAME=${ADMIN_NAME}
APP_ADMIN_EMAIL=${ADMIN_EMAIL}
APP_PASSWORD=adminadmin
ALLOW_INSECURE_COOKIE=true
SESSION_TTL_HOURS=12
APP_TITLE=cannonball
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
  fi

  set_env_value "${INSTALL_DIR}/.env" "PORT" "${PORT_VALUE}"
  set_env_value "${INSTALL_DIR}/.env" "APP_USERNAME" "${ADMIN_LOGIN}"
  set_env_value "${INSTALL_DIR}/.env" "APP_ADMIN_DISPLAY_NAME" "${ADMIN_NAME}"
  set_env_value "${INSTALL_DIR}/.env" "APP_ADMIN_EMAIL" "${ADMIN_EMAIL}"
  set_env_value "${INSTALL_DIR}/.env" "APP_PASSWORD" "${APP_PASSWORD}"
  set_env_value "${INSTALL_DIR}/.env" "APP_BASE_URL" "${PUBLIC_URL}"
  set_env_value "${INSTALL_DIR}/.env" "DATABASE_DRIVER" "sqlite"
  set_env_value "${INSTALL_DIR}/.env" "DATABASE_PATH" "/data/cannonball.db"
  set_env_value "${INSTALL_DIR}/.env" "APP_WEB_ROOT" "/app/web"

  cat >"${INSTALL_DIR}/docker-compose.override.yml" <<EOF
services:
  cannonball:
    volumes:
      - ${DATA_DIR}:/data
EOF
}

start_stack() {
  log "Поднимаю Docker-стек..."
  (
    cd "${INSTALL_DIR}"
    ${COMPOSE_CMD} up -d --build
  )
}

print_summary() {
  cat <<EOF

cannonball запущен.

URL: ${PUBLIC_URL}
Логин администратора: ${ADMIN_LOGIN}
Пароль администратора: ${APP_PASSWORD}
Каталог установки: ${INSTALL_DIR}
Каталог данных: ${DATA_DIR}
Репозиторий: ${REPO_URL}
Ветка: ${REPO_REF}

Проверка:
  cd ${INSTALL_DIR} && ${COMPOSE_CMD} ps
  curl -fsSL ${PUBLIC_URL}/health
EOF
}

main() {
  require_command docker
  require_command curl
  require_command tar
  detect_compose
  prepare_source_dir
  install_source
  prepare_runtime_files
  start_stack
  print_summary
}

main "$@"
