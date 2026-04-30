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

section "Connecting to Vaultwarden"
CURRENT_SERVER=$(bw config server 2>/dev/null || echo "")
if [ "$CURRENT_SERVER" != "https://${VAULTWARDEN_DOMAIN}" ]; then
  bw logout &>/dev/null || true
  bw config server "https://${VAULTWARDEN_DOMAIN}"
fi

BW_STATUS=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unauthenticated")
if [ "$BW_STATUS" = "unauthenticated" ]; then
  bw login "$ACME_EMAIL"
fi
export BW_SESSION=$(bw unlock --raw)
bw sync &>/dev/null
info "Connected"

# ─── Helpers ──────────────────────────────────────────────

get_or_create_folder() {
  local name=$1
  local id
  id=$(bw list folders | jq -r --arg n "$name" '.[] | select(.name == $n) | .id')
  if [ -z "$id" ]; then
    id=$(bw get template folder | jq --arg n "$name" '.name = $n' | bw encode | bw create folder | jq -r '.id')
    info "Folder '$name' created"
  fi
  echo "$id"
}

item_exists() {
  local name=$1
  bw list items --search "$name" 2>/dev/null | jq -e --arg n "$name" 'any(.[]; .name == $n)' > /dev/null 2>&1
}

create_login() {
  local name=$1 username=$2 password=$3 folder_id=$4 url=${5:-}
  item_exists "$name" && { warn "$name already exists — skipping"; return; }
  bw get template item | jq \
    --arg n "$name" --arg u "$username" --arg p "$password" --arg f "$folder_id" --arg url "$url" \
    '.name = $n | .type = 1 | .folderId = $f |
     .login = {"username": $u, "password": $p, "uris": (if $url != "" then [{"match": null, "uri": $url}] else [] end)}' | \
    bw encode | bw create item > /dev/null
  info "$name"
}

create_note() {
  local name=$1 notes=$2 folder_id=$3
  item_exists "$name" && { warn "$name already exists — skipping"; return; }
  bw get template item | jq \
    --arg n "$name" --arg notes "$notes" --arg f "$folder_id" \
    '.name = $n | .type = 2 | .folderId = $f | .secureNote = {"type": 0} | .notes = $notes' | \
    bw encode | bw create item > /dev/null
  info "$name"
}

# ─── Create folder ─────────────────────────────────────────
section "Setting up folder"
FOLDER_ID=$(get_or_create_folder "Infrastructure")

# ─── Postgres ──────────────────────────────────────────────
section "Postgres"
create_login "Postgres - Superuser" "$POSTGRES_SUPER_USER" "$POSTGRES_SUPER_PASSWORD" "$FOLDER_ID"
create_login "Postgres - Authentik" "$POSTGRES_AUTHENTIK_USER" "$POSTGRES_AUTHENTIK_PASSWORD" "$FOLDER_ID"
create_login "Postgres - Vaultwarden" "${POSTGRES_VAULTWARDEN_USER}" "${POSTGRES_VAULTWARDEN_PASSWORD}" "$FOLDER_ID"

# ─── Redis ─────────────────────────────────────────────────
section "Redis"
create_login "Redis" "default" "$REDIS_PASSWORD" "$FOLDER_ID"

# ─── Authentik ─────────────────────────────────────────────
section "Authentik"
create_login "Authentik - Admin" "akadmin" "" "$FOLDER_ID" "https://${AUTHENTIK_DOMAIN}"
create_note  "Authentik - Secret Key" "$AUTHENTIK_SECRET_KEY" "$FOLDER_ID"

# ─── Vaultwarden ───────────────────────────────────────────
section "Vaultwarden"
create_note "Vaultwarden - Admin Token" "$VAULTWARDEN_ADMIN_TOKEN" "$FOLDER_ID"

# ─── Registry ──────────────────────────────────────────────
section "Registry"
create_login "Docker Registry" "$REGISTRY_USER" "$REGISTRY_PASSWORD" "$FOLDER_ID" "https://${REGISTRY_DOMAIN}"

# ─── SMTP ──────────────────────────────────────────────────
section "SMTP"
create_login "SMTP" "$SMTP_USERNAME" "$SMTP_PASSWORD" "$FOLDER_ID"

# ─── Done ──────────────────────────────────────────────────
echo ""
info "Vault populated. Open https://${VAULTWARDEN_DOMAIN} to view."
