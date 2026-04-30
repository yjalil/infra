#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="$1"
CPANEL_HOST="$2"
CPANEL_USER="$3"
CPANEL_TOKEN="$4"
DOMAIN="$5"

AUTH="Authorization: cpanel ${CPANEL_USER}:${CPANEL_TOKEN}"
BASE_URL="https://${CPANEL_HOST}:2083/json-api/cpanel"

# Fetch the full zone
ZONE=$(curl -sf \
  -H "$AUTH" \
  -G \
  --data-urlencode "cpanel_jsonapi_module=ZoneEdit" \
  --data-urlencode "cpanel_jsonapi_func=fetchzone" \
  --data-urlencode "cpanel_jsonapi_version=2" \
  --data-urlencode "domain=${DOMAIN}" \
  "${BASE_URL}")

# Extract line numbers for records matching this env, sorted in reverse
# (must delete highest line number first so lower line numbers stay valid)
LINES=$(echo "$ZONE" | jq -r \
  --arg root "${ENV_NAME}.${DOMAIN}." \
  --arg wild "*.${ENV_NAME}.${DOMAIN}." \
  '
    [ .cpanelresult.data[0].record // [] |
      .[] | select(.name == $root or .name == $wild) | .line
    ] | sort | reverse | .[]
  ')

if [ -z "$LINES" ]; then
  echo "No DNS records found for ${ENV_NAME}.${DOMAIN} — nothing to delete"
  exit 0
fi

while IFS= read -r line_num; do
  response=$(curl -sf \
    -H "$AUTH" \
    --data-urlencode "cpanel_jsonapi_module=ZoneEdit" \
    --data-urlencode "cpanel_jsonapi_func=remove_zone_record" \
    --data-urlencode "cpanel_jsonapi_version=2" \
    --data-urlencode "domain=${DOMAIN}" \
    --data-urlencode "line=${line_num}" \
    "${BASE_URL}")

  if echo "$response" | jq -e '.cpanelresult.event.result == 1' > /dev/null 2>&1; then
    echo "✓ Removed DNS record at line ${line_num}"
  else
    echo "⚠ Could not remove record at line ${line_num} (may already be gone)"
  fi
done <<< "$LINES"
