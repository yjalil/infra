#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${GREEN}[✔]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✘]${NC} $1"; exit 1; }
section() { echo -e "\n${BLUE}──────────────────────────────────────${NC}\n${BLUE}$1${NC}"; }

# Load env
while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^[[:space:]]*# || -z "${line// }" ]] && continue
  key="${line%%=*}"
  value="${line#*=}"
  value="${value#\"}" && value="${value%\"}"
  value="${value#\'}" && value="${value%\'}"
  export "$key=$value"
done < "${SCRIPT_DIR}/.env"

section "Vaultwarden setup"

VW_URL="https://${VAULTWARDEN_DOMAIN}"
COOKIE_JAR=$(mktemp)

section "Authenticating with admin panel"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -c "$COOKIE_JAR" \
  -X POST "${VW_URL}/admin/" \
  -F "token=${VAULTWARDEN_ADMIN_TOKEN}")

[ "$HTTP_STATUS" != "200" ] && error "Admin login failed (HTTP ${HTTP_STATUS}). Check VAULTWARDEN_ADMIN_TOKEN."
info "Admin authenticated"

section "Inviting ${ACME_EMAIL}"
RESPONSE=$(curl -s -w "\n%{http_code}" -b "$COOKIE_JAR" \
  -X POST "${VW_URL}/admin/invite" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"${ACME_EMAIL}\"}")

HTTP_STATUS=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)

if [ "$HTTP_STATUS" = "200" ]; then
  info "Invite sent to ${ACME_EMAIL}"
  echo ""
  echo -e "  Check your email and complete registration at:"
  echo -e "  ${BLUE}${VW_URL}${NC}"
elif echo "$BODY" | grep -qi "already exists\|already been taken"; then
  warn "${ACME_EMAIL} already has an account"
else
  error "Invite failed (HTTP ${HTTP_STATUS}): ${BODY}"
fi

rm -f "$COOKIE_JAR"
