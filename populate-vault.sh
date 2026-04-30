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

section "Generating vault import file"

FOLDER_ID="00000000-0000-0000-0000-000000000001"
EXPORT_FILE=$(mktemp /tmp/vault-import-XXXXXX.json)

jq -n \
  --arg folder_id "$FOLDER_ID" \
  --arg pg_super_user "$POSTGRES_SUPER_USER" \
  --arg pg_super_pass "$POSTGRES_SUPER_PASSWORD" \
  --arg pg_ak_user "$POSTGRES_AUTHENTIK_USER" \
  --arg pg_ak_pass "$POSTGRES_AUTHENTIK_PASSWORD" \
  --arg pg_vw_user "$POSTGRES_VAULTWARDEN_USER" \
  --arg pg_vw_pass "$POSTGRES_VAULTWARDEN_PASSWORD" \
  --arg redis_pass "$REDIS_PASSWORD" \
  --arg ak_domain "https://${AUTHENTIK_DOMAIN}" \
  --arg ak_secret "$AUTHENTIK_SECRET_KEY" \
  --arg vw_admin_token "$VAULTWARDEN_ADMIN_TOKEN_PLAIN" \
  --arg vw_domain "https://${VAULTWARDEN_DOMAIN}" \
  --arg reg_user "$REGISTRY_USER" \
  --arg reg_pass "$REGISTRY_PASSWORD" \
  --arg reg_url "https://${REGISTRY_DOMAIN}" \
  --arg smtp_user "$SMTP_USERNAME" \
  --arg smtp_pass "$SMTP_PASSWORD" \
  --arg smtp_host "$SMTP_HOST" \
'{
  "encrypted": false,
  "folders": [{"id": $folder_id, "name": "Infrastructure"}],
  "items": [
    {
      "type": 1, "name": "Postgres - Superuser", "folderId": $folder_id,
      "login": {"username": $pg_super_user, "password": $pg_super_pass, "uris": []}
    },
    {
      "type": 1, "name": "Postgres - Authentik", "folderId": $folder_id,
      "login": {"username": $pg_ak_user, "password": $pg_ak_pass, "uris": []}
    },
    {
      "type": 1, "name": "Postgres - Vaultwarden", "folderId": $folder_id,
      "login": {"username": $pg_vw_user, "password": $pg_vw_pass, "uris": []}
    },
    {
      "type": 1, "name": "Redis", "folderId": $folder_id,
      "login": {"username": "default", "password": $redis_pass, "uris": []}
    },
    {
      "type": 1, "name": "Authentik - Admin", "folderId": $folder_id,
      "login": {"username": "akadmin", "password": "", "uris": [{"uri": $ak_domain}]}
    },
    {
      "type": 2, "name": "Authentik - Secret Key", "folderId": $folder_id,
      "secureNote": {"type": 0}, "notes": $ak_secret
    },
    {
      "type": 2, "name": "Vaultwarden - Admin Token", "folderId": $folder_id,
      "secureNote": {"type": 0}, "notes": $vw_admin_token
    },
    {
      "type": 1, "name": "Docker Registry", "folderId": $folder_id,
      "login": {"username": $reg_user, "password": $reg_pass, "uris": [{"uri": $reg_url}]}
    },
    {
      "type": 1, "name": "SMTP", "folderId": $folder_id,
      "notes": $smtp_host,
      "login": {"username": $smtp_user, "password": $smtp_pass, "uris": []}
    }
  ]
}' > "$EXPORT_FILE"

info "Export file generated: $EXPORT_FILE"

echo ""
echo -e "  ${YELLOW}Import this file into Vaultwarden:${NC}"
echo -e "  1. Open ${BLUE}${vw_domain:-https://${VAULTWARDEN_DOMAIN}}${NC}"
echo -e "  2. Go to ${YELLOW}Tools → Import Data${NC}"
echo -e "  3. Format: ${YELLOW}Bitwarden (json)${NC}"
echo -e "  4. Upload: ${YELLOW}${EXPORT_FILE}${NC}"
echo ""
read -r -p "Press Enter once imported to delete the file..."

rm -f "$EXPORT_FILE"
info "Export file deleted"
