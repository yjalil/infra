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

# ─── .env ─────────────────────────────────────────────────
section "Validating .env"
[ -f .env ] || error ".env not found. Run ./bootstrap.sh first."

set -a && source .env && set +a

# Check mandatory fields
MISSING=()
[ "${DOMAIN}" = "example.com" ]            && MISSING+=("DOMAIN")
[ "${ACME_EMAIL}" = "admin@example.com" ]  && MISSING+=("ACME_EMAIL")
[ "${SMTP_HOST}" = "mail.example.com" ]    && MISSING+=("SMTP_HOST")
[ "${SMTP_PASSWORD}" = "FILL_ME" ]         && MISSING+=("SMTP_PASSWORD")

if [ ${#MISSING[@]} -gt 0 ]; then
  echo -e "${RED}[✘]${NC} The following required fields are not configured in .env:"
  printf '      - %s\n' "${MISSING[@]}"
  exit 1
fi

info ".env validated"

# ─── Networks ─────────────────────────────────────────────
section "Checking networks"
for network in "$NETWORK_INTERNAL" "$NETWORK_DATA"; do
  docker network inspect "$network" &>/dev/null \
    && info "Network '$network' exists" \
    || error "Network '$network' missing. Run ./bootstrap.sh first."
done

# ─── Registry profile ─────────────────────────────────────
COMPOSE_PROFILES=""
if [ "${REGISTRY_LOCAL:-false}" = "true" ]; then
  section "Registry profile enabled"
  COMPOSE_PROFILES="--profile registry"
  info "Local registry will be started"
fi

# ─── Core services first ──────────────────────────────────
section "Starting core services"
docker compose $COMPOSE_PROFILES up -d postgres redis

info "Waiting for Postgres..."
until docker inspect --format='{{.State.Health.Status}}' "$POSTGRES_HOST" 2>/dev/null | grep -q "healthy"; do
  sleep 2
done
info "Postgres healthy"

info "Waiting for Redis..."
until docker inspect --format='{{.State.Health.Status}}' "$REDIS_HOST" 2>/dev/null | grep -q "healthy"; do
  sleep 2
done
info "Redis healthy"

# ─── Full stack ───────────────────────────────────────────
section "Starting remaining services"
docker compose $COMPOSE_PROFILES up -d

# ─── Summary ──────────────────────────────────────────────
section "Stack status"
docker compose ps

echo -e "\n${GREEN}Deployment complete.${NC}"
echo -e "  Traefik dashboard : https://proxy.${DOMAIN}"
echo -e "  Authentik         : https://sso.${DOMAIN}"
echo -e "  Dozzle            : https://logs.${DOMAIN}"
[ "${REGISTRY_LOCAL:-false}" = "true" ] && echo -e "  Registry          : https://registry.${DOMAIN}"
echo ""