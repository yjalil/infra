#!/bin/bash
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

generate_secret() {
  openssl rand -base64 48 | tr -d "=+/" | cut -c1-50
}

# ─── Prerequisites ────────────────────────────────────────
section "Checking prerequisites"
command -v docker    &>/dev/null || error "Docker is not installed."
command -v openssl   &>/dev/null || error "openssl is not installed."
command -v envsubst  &>/dev/null || error "envsubst is not installed (apt install gettext)."
docker compose version &>/dev/null || error "Docker Compose plugin is not installed."
info "Prerequisites OK"

# ─── .env ─────────────────────────────────────────────────
section "Generating .env"
if [ -f .env ]; then
  warn ".env already exists — skipping generation"
else
  cp .env.example .env
  sed -i "s|POSTGRES_SUPER_PASSWORD=changeme|POSTGRES_SUPER_PASSWORD=$(generate_secret)|" .env
  sed -i "s|POSTGRES_AUTHENTIK_PASSWORD=changeme|POSTGRES_AUTHENTIK_PASSWORD=$(generate_secret)|" .env
  sed -i "s|POSTGRES_VAULTWARDEN_PASSWORD=changeme|POSTGRES_VAULTWARDEN_PASSWORD=$(generate_secret)|" .env
  sed -i "s|REDIS_PASSWORD=changeme|REDIS_PASSWORD=$(generate_secret)|" .env
  sed -i "s|AUTHENTIK_SECRET_KEY=changeme_min_50_chars|AUTHENTIK_SECRET_KEY=$(generate_secret)|" .env
  sed -i "s|SMTP_PASSWORD=changeme|SMTP_PASSWORD=FILL_ME|" .env
  info ".env generated with secrets"
fi

# Source .env for the rest of the script
while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^[[:space:]]*# || -z "${line// }" ]] && continue
  key="${line%%=*}"
  value="${line#*=}"
  value="${value#\"}" && value="${value%\"}"
  value="${value#\'}" && value="${value%\'}"
  export "$key=$value"
done < .env

# ─── Networks ─────────────────────────────────────────────
section "Creating Docker networks"
for network in "$NETWORK_INTERNAL" "$NETWORK_DATA"; do
  if docker network inspect "$network" &>/dev/null; then
    warn "Network '$network' already exists"
  else
    docker network create "$network"
    info "Network '$network' created"
  fi
done

# ─── Traefik ──────────────────────────────────────────────
section "Traefik setup"
mkdir -p traefik/data traefik/data/dynamic

if [ ! -f traefik/data/acme.json ]; then
  touch traefik/data/acme.json
  info "acme.json created"
else
  warn "acme.json already exists"
fi
chmod 600 traefik/data/acme.json

# ─── Registry ─────────────────────────────────────────────
if [ "${REGISTRY_LOCAL:-false}" = "true" ]; then
  section "Registry setup"
  command -v htpasswd &>/dev/null || error "htpasswd is not installed (apt install apache2-utils)."
  mkdir -p registry/auth registry/data

  if [ ! -f registry/auth/htpasswd ]; then
    [ -z "${REGISTRY_USER:-}" ]     && error "REGISTRY_USER is required when REGISTRY_LOCAL=true"
    [ -z "${REGISTRY_PASSWORD:-}" ] && error "REGISTRY_PASSWORD is required when REGISTRY_LOCAL=true"
    htpasswd -Bbn "$REGISTRY_USER" "$REGISTRY_PASSWORD" > registry/auth/htpasswd
    info "htpasswd generated for user: $REGISTRY_USER"
  else
    warn "registry/auth/htpasswd already exists — skipping"
  fi
fi

# ─── Backup directory ─────────────────────────────────────
section "Backup setup"
mkdir -p backup/backups
info "Backup directory ready at backup/backups"

# ─── Build custom images ──────────────────────────────────
section "Building custom images"
docker build -t "${POSTGRES_BACKUP_IMAGE}:${POSTGRES_BACKUP_IMAGE_TAG}" ./backup
info "postgres-backup image built locally"

# ─── Checklist ────────────────────────────────────────────
MISSING=()
[ "${DOMAIN:-example.com}" = "example.com" ]             && MISSING+=("DOMAIN")
[ "${ACME_EMAIL:-admin@example.com}" = "admin@example.com" ] && MISSING+=("ACME_EMAIL")
[ "${SMTP_PASSWORD:-changeme}" = "changeme" ]             && MISSING+=("SMTP_PASSWORD")
[ "${VAULTWARDEN_ADMIN_TOKEN:-changeme}" = "changeme" ]   && MISSING+=("VAULTWARDEN_ADMIN_TOKEN")
[ -z "${RCLONE_DEST:-}" ]                                 && MISSING+=("RCLONE_DEST (if using remote backup)")
[ "${REGISTRY_LOCAL:-false}" = "true" ] && [ "${REGISTRY_PASSWORD:-changeme}" = "changeme" ] && MISSING+=("REGISTRY_USER / REGISTRY_PASSWORD")

echo -e "\n${GREEN}Bootstrap complete.${NC}\n"
if [ ${#MISSING[@]} -eq 0 ]; then
  info "All required values are set — ready to run ./deploy.sh"
else
  echo -e "Before running ${YELLOW}./deploy.sh${NC}, fill in:\n"
  for item in "${MISSING[@]}"; do
    echo -e "  ${RED}[ ]${NC} $item"
  done
  echo ""
fi