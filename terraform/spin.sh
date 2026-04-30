#!/usr/bin/env bash
# Unlock local Bitwarden, inject terraform secrets as env vars, run terraform.
# Usage: ./spin.sh [terraform args]
#   e.g. ./spin.sh workspace new nexus
#        ./spin.sh apply
#        ./spin.sh destroy
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BW_ITEM="nexus-bootstrap"

# ─── Bitwarden unlock ─────────────────────────────────────
if [ -z "${BW_SESSION:-}" ]; then
  CURRENT_SERVER=$(bw config server 2>/dev/null || echo "")
  if [ "$CURRENT_SERVER" != "https://vault.bitwarden.eu" ]; then
    bw logout &>/dev/null || true
    bw config server https://vault.bitwarden.eu
  fi
  export BW_SESSION=$(bw unlock --raw)
fi

bw sync &>/dev/null

# ─── Pull secrets into TF_VAR env vars ───────────────────
NOTES=$(bw get item "$BW_ITEM" | jq -r '.notes')
[ -z "$NOTES" ] && { echo "✗ Item '${BW_ITEM}' not found or has no notes"; exit 1; }

while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^[[:space:]]*# || -z "${line// }" ]] && continue
  key="${line%%=*}"
  value="${line#*=}"
  export "TF_VAR_${key,,}=${value}"
done <<< "$NOTES"

# bw_password has no default — terraform will prompt for it
# or: export TF_VAR_bw_password=$(get_field "bw_password")  # only if you store it in BW

# ─── Run terraform ────────────────────────────────────────
cd "${SCRIPT_DIR}/envs/test"
terraform "$@"
