#!/bin/sh
set -eu

BACKUP_DIR="${POSTGRES_BACKUP_DIR:-/backups}"
BACKUP_INTERVAL="${POSTGRES_BACKUP_INTERVAL_SECONDS:-86400}"
BACKUP_KEEP_DAYS="${POSTGRES_BACKUP_KEEP_DAYS:-7}"

: "${POSTGRES_DB:?POSTGRES_DB is required}"
: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"

mkdir -p "${BACKUP_DIR}"

while true; do
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  backup_file="${BACKUP_DIR}/${POSTGRES_DB}-${ts}.dump"

  PGPASSWORD="${POSTGRES_PASSWORD}" pg_dump \
    -h postgres \
    -U "${POSTGRES_USER}" \
    -d "${POSTGRES_DB}" \
    -Fc \
    -f "${backup_file}"

  find "${BACKUP_DIR}" -type f -name '*.dump' -mtime +"${BACKUP_KEEP_DAYS}" -delete
  sleep "${BACKUP_INTERVAL}"
done
