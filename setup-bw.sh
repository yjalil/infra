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
command -v bw &>/dev/null || error "Bitwarden CLI (bw) is not installed."
info "Prerequisites OK"

# ─── BW session ───────────────────────────────────────────
section "Bitwarden authentication"
if [ -z "${BW_SESSION:-}" ]; then
  echo "No BW_SESSION found. Logging in..."
  BW_STATUS=$(bw status 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])" 2>/dev/null || echo "unauthenticated")

  if [ "$BW_STATUS" = "unauthenticated" ]; then
    bw login
  fi

  export BW_SESSION=$(bw unlock --raw)
fi

bw sync &>/dev/null
info "Vault synced"

# ─── Pull .env ────────────────────────────────────────────
section "Pulling secrets from Bitwarden"
if [ -f "${SCRIPT_DIR}/.env" ]; then
  warn ".env already exists — skipping (delete it to re-pull)"
else
  NOTES=$(bw list items 2>/dev/null | python3 -c "
import sys, json
items = json.load(sys.stdin)
item = next((i for i in items if i.get('name') == '${BW_BOOTSTRAP_ITEM}'), None)
if not item:
    sys.exit(1)
print(item.get('notes', ''))
")
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
  RCLONE_NOTES=$(bw list items 2>/dev/null | python3 -c "
import sys, json
items = json.load(sys.stdin)
item = next((i for i in items if i.get('name') == '${BW_RCLONE_ITEM}'), None)
if not item:
    sys.exit(1)
print(item.get('notes', ''))
")
  [ -z "$RCLONE_NOTES" ] && error "Item '${BW_RCLONE_ITEM}' not found or has no notes in Bitwarden."
  echo "$RCLONE_NOTES" > "$RCLONE_CONF"
  info "rclone.conf written from '${BW_RCLONE_ITEM}'"
fi

# ─── Run bootstrap ────────────────────────────────────────
section "Running bootstrap"
bash "${SCRIPT_DIR}/bootstrap.sh"
