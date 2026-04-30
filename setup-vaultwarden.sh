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

section "Checking if ${ACME_EMAIL} already exists"
USERS=$(curl -s -b "$COOKIE_JAR" "${VW_URL}/admin/users/overview")
USER_EXISTS=false
echo "$USERS" | grep -qi "${ACME_EMAIL}" && USER_EXISTS=true

if [ "$USER_EXISTS" = "false" ]; then
  section "Enabling signups temporarily"
  curl -s -b "$COOKIE_JAR" \
    -X POST "${VW_URL}/admin/config" \
    -H "Content-Type: application/json" \
    -d '{"signups_allowed": true}' > /dev/null
  info "Signups enabled"

  echo ""
  echo -e "  ${YELLOW}Register your account now at:${NC}"
  echo -e "  ${BLUE}${VW_URL}/#/register${NC}"
  echo ""
  read -r -p "Press Enter once you have registered..."

  section "Disabling signups"
  curl -s -b "$COOKIE_JAR" \
    -X POST "${VW_URL}/admin/config" \
    -H "Content-Type: application/json" \
    -d '{"signups_allowed": false}' > /dev/null
  info "Signups disabled"
else
  warn "${ACME_EMAIL} already has an account — skipping registration"
fi


rm -f "$COOKIE_JAR"
info "Vaultwarden setup complete"
