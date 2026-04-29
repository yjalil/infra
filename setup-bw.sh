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
  [ -z "${BW_CLIENTID:-}" ]     && error "BW_CLIENTID is not set. Export it before running this script."
  [ -z "${BW_CLIENTSECRET:-}" ] && error "BW_CLIENTSECRET is not set. Export it before running this script."

  BW_STATUS=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unauthenticated")

  if [ "$BW_STATUS" = "unauthenticated" ]; then
    bw login --apikey
    info "Logged in via API key"
  fi

  export BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw 2>/dev/null || bw unlock --raw)
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
  echo "$NOTES" > "${SCRIPT_DIR}/.env"
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
