#!/usr/bin/env bash

set -Eeuo pipefail

APP_NAME="cannonball"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT_FROM_SCRIPT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ "${EUID}" -eq 0 ]]; then
  DEFAULT_INSTALL_DIR="/opt/cannonball-docker"
  DEFAULT_DATA_DIR="/var/lib/cannonball"
else
  DEFAULT_INSTALL_DIR="${HOME}/cannonball-docker"
  DEFAULT_DATA_DIR="${HOME}/.local/share/cannonball"
fi

INSTALL_DIR="${CANNONBALL_INSTALL_DIR:-${DEFAULT_INSTALL_DIR}}"
DATA_DIR="${CANNONBALL_DATA_DIR:-${DEFAULT_DATA_DIR}}"
PUBLIC_URL="${CANNONBALL_PUBLIC_URL:-http://localhost:${CANNONBALL_PORT:-8080}}"
PORT_VALUE="${CANNONBALL_PORT:-8080}"
ADMIN_LOGIN="${CANNONBALL_APP_USERNAME:-admin}"
ADMIN_NAME="${CANNONBALL_APP_ADMIN_DISPLAY_NAME:-System Administrator}"
ADMIN_EMAIL="${CANNONBALL_APP_ADMIN_EMAIL:-admin@example.com}"
APP_PASSWORD="${CANNONBALL_APP_PASSWORD:-}"
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

generate_password() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 24 | tr -d '\n'
    return
  fi

  tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24
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
  [[ -f "${candidate}/Dockerfile" && -f "${candidate}/docker-compose.yml" && -f "${candidate}/.env.example" ]]
}

find_repo_root() {
  local base_dir="$1"
  local found_root=""

  if is_repo_root "${base_dir}"; then
    printf '%s\n' "${base_dir}"
    return
  fi

  found_root="$(find "${base_dir}" -type f -name 'docker-compose.yml' -print 2>/dev/null | while read -r compose_file; do
    local candidate
    candidate="$(dirname "${compose_file}")"
    if is_repo_root "${candidate}"; then
      printf '%s\n' "${candidate}"
      break
    fi
  done)"

  if [[ -n "${found_root}" ]]; then
    printf '%s\n' "${found_root}"
    return
  fi

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

  if is_repo_root "${REPO_ROOT_FROM_SCRIPT}"; then
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

  if [[ ! -f "${INSTALL_DIR}/.env" ]]; then
    cp "${INSTALL_DIR}/.env.example" "${INSTALL_DIR}/.env"
  fi

  if [[ -z "${APP_PASSWORD}" ]]; then
    APP_PASSWORD="$(generate_password)"
    log "Сгенерирован пароль администратора"
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
