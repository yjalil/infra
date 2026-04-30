#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${GREEN}[✔]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✘]${NC} $1"; exit 1; }
section() { echo -e "\n${BLUE}──────────────────────────────────────${NC}\n${BLUE}$1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BW_BOOTSTRAP_ITEM="nexus-bootstrap"
BW_RCLONE_ITEM="nexus-rclone-conf"

# ─── Prerequisites ────────────────────────────────────────
section "Checking prerequisites"
command -v bw  &>/dev/null || error "Bitwarden CLI (bw) is not installed."
command -v jq  &>/dev/null || error "jq is not installed."
info "Prerequisites OK"

# ─── BW session ───────────────────────────────────────────
section "Bitwarden authentication"
if [ -z "${BW_SESSION:-}" ]; then
  CURRENT_SERVER=$(bw config server 2>/dev/null || echo "")
  if [ "$CURRENT_SERVER" != "https://vault.bitwarden.eu" ]; then
    bw logout &>/dev/null || true
    bw config server https://vault.bitwarden.eu
  fi

  # Non-interactive path: API key + master password (used by Terraform remote-exec)
  if [ -n "${BW_CLIENTID:-}" ] && [ -n "${BW_CLIENTSECRET:-}" ] && [ -n "${BW_PASSWORD:-}" ]; then
    bw login --apikey 2>/dev/null || true
    export BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)
    info "Authenticated via API key"
  else
    # Interactive fallback for local use
    BW_STATUS=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unauthenticated")
    if [ "$BW_STATUS" = "unauthenticated" ]; then
      bw login
      info "Logged in"
    fi
    export BW_SESSION=$(bw unlock --raw)
  fi
fi

bw sync &>/dev/null
info "Vault synced"

# ─── Pull .env ────────────────────────────────────────────
section "Pulling secrets from Bitwarden"
if [ -f "${SCRIPT_DIR}/.env" ]; then
  warn ".env already exists — skipping (delete it to re-pull)"
else
  NOTES=$(bw list items 2>/dev/null | jq -r --arg name "$BW_BOOTSTRAP_ITEM" '.[] | select(.name == $name) | .notes')
  [ -z "$NOTES" ] && error "Item '${BW_BOOTSTRAP_ITEM}' not found or has no notes in Bitwarden."
  cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
  while IFS= read -r line || [ -n "$line" ]; do
    [[ "$line" =~ ^[[:space:]]*# || -z "${line// }" ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    if grep -q "^${key}=" "${SCRIPT_DIR}/.env"; then
      sed -i "s|^${key}=.*|${key}=${value}|" "${SCRIPT_DIR}/.env"
    else
      echo "${key}=${value}" >> "${SCRIPT_DIR}/.env"
    fi
  done <<< "$NOTES"
  # DOMAIN can be injected by the caller (e.g. Terraform per-env) to override the note
  if [ -n "${DOMAIN:-}" ]; then
    sed -i "s|^DOMAIN=.*|DOMAIN=${DOMAIN}|" "${SCRIPT_DIR}/.env"
    info "DOMAIN overridden to ${DOMAIN}"
  fi
  DOMAIN=$(grep '^DOMAIN=' "${SCRIPT_DIR}/.env" | cut -d= -f2 | tr -d '"'"'")
  export DOMAIN
  envsubst '${DOMAIN}' < "${SCRIPT_DIR}/.env" > "${SCRIPT_DIR}/.env.tmp" && mv "${SCRIPT_DIR}/.env.tmp" "${SCRIPT_DIR}/.env"
  info ".env written from '${BW_BOOTSTRAP_ITEM}'"
fi

# ─── Pull rclone config ───────────────────────────────────
section "Pulling rclone config from Bitwarden"
RCLONE_CONF="${SCRIPT_DIR}/backup/rclone/rclone.conf"
if [ -f "$RCLONE_CONF" ]; then
  warn "rclone.conf already exists — skipping (delete it to re-pull)"
else
  mkdir -p "$(dirname "$RCLONE_CONF")"
  RCLONE_NOTES=$(bw list items 2>/dev/null | jq -r --arg name "$BW_RCLONE_ITEM" '.[] | select(.name == $name) | .notes')
  [ -z "$RCLONE_NOTES" ] && error "Item '${BW_RCLONE_ITEM}' not found or has no notes in Bitwarden."
  echo "$RCLONE_NOTES" > "$RCLONE_CONF"
  info "rclone.conf written from '${BW_RCLONE_ITEM}'"
fi

# ─── Run bootstrap ────────────────────────────────────────
section "Running bootstrap"
bash "${SCRIPT_DIR}/bootstrap.sh"
