#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_CMD=""
APP_URL="${CANNONBALL_SMOKE_URL:-http://127.0.0.1:8081}"

log() {
  printf '[cannonball-smoke] %s\n' "$*"
}

fail() {
  printf '[cannonball-smoke] ERROR: %s\n' "$*" >&2
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

main() {
  require_command docker
  require_command curl
  detect_compose

  cd "${ROOT_DIR}"

  log "Пересобираю и поднимаю стек"
  ${COMPOSE_CMD} up -d --build

  log "Жду health endpoint ${APP_URL}/health"
  for _ in $(seq 1 40); do
    if curl -fsSL "${APP_URL}/health" >/dev/null 2>&1; then
      log "Приложение отвечает"
      curl -fsSL "${APP_URL}/health"
      echo
      exit 0
    fi
    sleep 2
  done

  log "Healthcheck не поднялся, показываю логи"
  ${COMPOSE_CMD} ps || true
  ${COMPOSE_CMD} logs --tail=200 || true
  fail "Приложение не вышло в healthy state"
}

main "$@"
