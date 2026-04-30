#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="$1"
IP="$2"
CPANEL_HOST="$3"
CPANEL_USER="$4"
CPANEL_TOKEN="$5"
DOMAIN="$6"

AUTH="Authorization: cpanel ${CPANEL_USER}:${CPANEL_TOKEN}"
BASE_URL="https://${CPANEL_HOST}:2083/json-api/cpanel"

add_record() {
  local name="$1"
  local response
  response=$(curl -sf \
    -H "$AUTH" \
    --data-urlencode "cpanel_jsonapi_module=ZoneEdit" \
    --data-urlencode "cpanel_jsonapi_func=add_zone_record" \
    --data-urlencode "cpanel_jsonapi_version=2" \
    --data-urlencode "domain=${DOMAIN}" \
    --data-urlencode "name=${name}" \
    --data-urlencode "type=A" \
    --data-urlencode "address=${IP}" \
    --data-urlencode "ttl=300" \
    "${BASE_URL}")

  if echo "$response" | jq -e '.cpanelresult.event.result == 1' > /dev/null 2>&1; then
    echo "✓ Added A: ${name} → ${IP}"
  else
    echo "✗ Failed to add A: ${name}"
    echo "$response" | jq . 2>/dev/null || echo "$response"
    exit 1
  fi
}

add_record "${ENV_NAME}"
add_record "*.${ENV_NAME}"
