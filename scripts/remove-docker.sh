#!/usr/bin/env bash

set -Eeuo pipefail

if [[ "${EUID}" -eq 0 ]]; then
  INSTALL_DIR="${CANNONBALL_INSTALL_DIR:-/opt/cannonball-docker}"
  DATA_DIR="${CANNONBALL_DATA_DIR:-/var/lib/cannonball}"
  NGINX_DIR="${CANNONBALL_NGINX_DIR:-/opt/nginx-docker}"
else
  INSTALL_DIR="${CANNONBALL_INSTALL_DIR:-${HOME}/cannonball-docker}"
  DATA_DIR="${CANNONBALL_DATA_DIR:-${HOME}/.local/share/cannonball}"
  NGINX_DIR="${CANNONBALL_NGINX_DIR:-${HOME}/nginx-docker}"
fi

IMAGE_NAME="${CANNONBALL_IMAGE_NAME:-cannonball:local}"
REMOVE_IMAGE="${CANNONBALL_REMOVE_IMAGE:-true}"
REMOVE_INSTALL_DIR="${CANNONBALL_REMOVE_INSTALL_DIR:-true}"
REMOVE_DATA_DIR="${CANNONBALL_REMOVE_DATA_DIR:-true}"
REMOVE_NGINX_DIR="${CANNONBALL_REMOVE_NGINX_DIR:-true}"
PRUNE_BUILDER="${CANNONBALL_PRUNE_BUILDER:-false}"
COMPOSE_CMD=""

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

remove_compose_stack() {
  if [[ -d "${INSTALL_DIR}" && -f "${INSTALL_DIR}/docker-compose.yml" ]]; then
    log "Останавливаю docker compose стек в ${INSTALL_DIR}"
    (
      cd "${INSTALL_DIR}"
      ${COMPOSE_CMD} down --remove-orphans --volumes || true
    )
  fi
}

remove_named_containers() {
  local container_ids=""

  container_ids="$(docker ps -aq --filter "name=cannonball" || true)"
  if [[ -n "${container_ids}" ]]; then
    log "Удаляю контейнеры cannonball"
    docker rm -f ${container_ids} >/dev/null 2>&1 || true
  fi
}

remove_named_volumes() {
  local volume_ids=""

  volume_ids="$(docker volume ls -q | grep -E '(^|_)cannonball_data$|(^|_)cannonball_pg_data$|(^|_)cannonball($|_)' || true)"
  if [[ -n "${volume_ids}" ]]; then
    log "Удаляю docker volumes cannonball"
    printf '%s\n' "${volume_ids}" | while IFS= read -r volume_id; do
      [[ -n "${volume_id}" ]] || continue
      docker volume rm -f "${volume_id}" >/dev/null 2>&1 || true
    done
  fi
}

remove_image() {
  if [[ "${REMOVE_IMAGE}" = "true" ]]; then
    log "Удаляю image ${IMAGE_NAME}"
    docker rmi -f "${IMAGE_NAME}" >/dev/null 2>&1 || true
  fi
}

remove_install_dir() {
  if [[ "${REMOVE_INSTALL_DIR}" = "true" && -d "${INSTALL_DIR}" ]]; then
    log "Удаляю каталог установки ${INSTALL_DIR}"
    rm -rf "${INSTALL_DIR}"
  fi
}

remove_data_dir() {
  if [[ "${REMOVE_DATA_DIR}" = "true" && -d "${DATA_DIR}" ]]; then
    log "Удаляю каталог данных ${DATA_DIR}"
    rm -rf "${DATA_DIR}"
  fi
}

remove_nginx_dir() {
  if [[ "${REMOVE_NGINX_DIR}" = "true" && -d "${NGINX_DIR}" ]]; then
    log "Удаляю каталог nginx ${NGINX_DIR}"
    rm -rf "${NGINX_DIR}"
  fi
}

prune_builder() {
  if [[ "${PRUNE_BUILDER}" = "true" ]]; then
    log "Очищаю docker builder cache"
    docker builder prune -af || true
  fi
}

print_summary() {
  cat <<EOF

cannonball удалён.

Каталог установки: ${INSTALL_DIR}
Каталог данных: ${DATA_DIR}
Каталог nginx: ${NGINX_DIR}
Image: ${IMAGE_NAME}

Если нужен чистый reinstall:
  curl -fsSL https://raw.githubusercontent.com/papasahti/cannonball/main/scripts/install-docker-curl.sh | sudo bash
EOF
}

main() {
  require_command docker
  detect_compose
  remove_compose_stack
  remove_named_containers
  remove_named_volumes
  remove_image
  remove_install_dir
  remove_data_dir
  remove_nginx_dir
  prune_builder
  print_summary
}

main "$@"
