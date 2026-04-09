#!/usr/bin/env bash

set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
INBOUND_SECRET="${INBOUND_SECRET:-}"
RULE_KEY="${RULE_KEY:-}"
REQUEST_ID="${REQUEST_ID:-smoke-$(date +%s)}"
MESSAGE="${MESSAGE:-Smoke test from n8n inbound}"
CHANNELS="${CHANNELS:-alerts}"

if [[ -z "${INBOUND_SECRET}" ]]; then
  echo "INBOUND_SECRET is required."
  echo "Example:"
  echo "  INBOUND_SECRET=change-me RULE_KEY=incident-critical ./scripts/smoke-inbound-n8n.sh"
  exit 1
fi

payload_direct=$(cat <<JSON
{
  "message": "${MESSAGE}",
  "channels": ["${CHANNELS}"],
  "request_id": "${REQUEST_ID}"
}
JSON
)

payload_rule=$(cat <<JSON
{
  "rule_key": "${RULE_KEY}",
  "message": "${MESSAGE}",
  "request_id": "${REQUEST_ID}"
}
JSON
)

if [[ -n "${RULE_KEY}" ]]; then
  payload="${payload_rule}"
  echo "Running smoke test with rule_key=${RULE_KEY}"
else
  payload="${payload_direct}"
  echo "Running smoke test with direct channels=${CHANNELS}"
fi

curl -sS \
  -X POST "${BASE_URL}/api/incoming/n8n" \
  -H "Authorization: Bearer ${INBOUND_SECRET}" \
  -H "Content-Type: application/json" \
  --data "${payload}"

echo
