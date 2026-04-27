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
command -v docker &>/dev/null    || error "Docker is not installed."
docker compose version &>/dev/null || error "Docker Compose plugin is not installed."
command -v openssl &>/dev/null   || error "openssl is not installed."
info "Prerequisites OK"

# ─── .env ─────────────────────────────────────────────────
section "Generating .env"
if [ -f .env ]; then
  warn ".env already exists — skipping generation"
else
  cp .env.example .env

  # Generate all secrets
  sed -i "s|POSTGRES_SUPER_PASSWORD=changeme|POSTGRES_SUPER_PASSWORD=$(generate_secret)|" .env
  sed -i "s|POSTGRES_AUTHENTIK_PASSWORD=changeme|POSTGRES_AUTHENTIK_PASSWORD=$(generate_secret)|" .env
  sed -i "s|REDIS_PASSWORD=changeme|REDIS_PASSWORD=$(generate_secret)|" .env
  sed -i "s|AUTHENTIK_SECRET_KEY=changeme_min_50_chars|AUTHENTIK_SECRET_KEY=$(generate_secret)|" .env
  sed -i "s|SMTP_PASSWORD=changeme|SMTP_PASSWORD=FILL_ME|" .env

  info ".env generated with secrets"
fi

# ─── Networks ─────────────────────────────────────────────
section "Creating Docker networks"
source <(grep -E '^NETWORK_' .env)
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
mkdir -p traefik/data
if [ ! -f traefik/data/acme.json ]; then
  touch traefik/data/acme.json
  chmod 600 traefik/data/acme.json
  info "acme.json created"
else
  chmod 600 traefik/data/acme.json
  warn "acme.json already exists"
fi

# ─── Backup directory ─────────────────────────────────────
section "Backup setup"
source <(grep -E '^BACKUP_PATH' .env)
mkdir -p "$BACKUP_PATH"
chown -R 999:999 "$BACKUP_PATH"
info "Backup directory ready at $BACKUP_PATH"

# ─── Build custom images ──────────────────────────────────
section "Building custom images"
source <(grep -E '^POSTGRES_BACKUP_IMAGE' .env)
docker build -t "${POSTGRES_BACKUP_IMAGE}:${POSTGRES_BACKUP_IMAGE_TAG}" ./backup
info "postgres-backup image built"

# ─── Checklist ────────────────────────────────────────────
echo -e "\n${GREEN}Bootstrap complete.${NC}\n"
echo -e "Before running ${YELLOW}./deploy.sh${NC}, make sure to fill in ${YELLOW}.env${NC}:\n"
echo -e "  ${RED}[ ]${NC} DOMAIN"
echo -e "  ${RED}[ ]${NC} ACME_EMAIL"
echo -e "  ${RED}[ ]${NC} SMTP_HOST, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD"
echo -e "  ${RED}[ ]${NC} BACKUP_PATH          (if not local)"
echo -e "  ${RED}[ ]${NC} RCLONE_DEST          (if using remote backup)"
echo -e "  ${RED}[ ]${NC} backup/rclone/rclone.conf (copy from destinations/ example)\n"