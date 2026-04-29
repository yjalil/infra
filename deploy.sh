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

wait_healthy() {
  local service=$1
  local retries=30
  info "Waiting for $service..."
  until docker compose ps --format json "$service" 2>/dev/null | grep -q '"Health":"healthy"'; do
    retries=$((retries - 1))
    [ $retries -eq 0 ] && error "$service did not become healthy in time"
    sleep 3
  done
  info "$service healthy"
}

# ─── .env ─────────────────────────────────────────────────
section "Validating .env"
[ -f .env ] || error ".env not found. Run ./bootstrap.sh first."

while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^[[:space:]]*# || -z "${line// }" ]] && continue
  key="${line%%=*}"
  value="${line#*=}"
  value="${value#\"}" && value="${value%\"}"
  value="${value#\'}" && value="${value%\'}"
  export "$key=$value"
done < .env

MISSING=()
[ "${DOMAIN}" = "example.com" ]             && MISSING+=("DOMAIN")
[ "${ACME_EMAIL}" = "admin@example.com" ]   && MISSING+=("ACME_EMAIL")
[ "${SMTP_HOST}" = "mail.example.com" ]     && MISSING+=("SMTP_HOST")
[ "${SMTP_PASSWORD}" = "FILL_ME" ]          && MISSING+=("SMTP_PASSWORD")
[ "${VAULTWARDEN_ADMIN_TOKEN}" = "changeme" ] && MISSING+=("VAULTWARDEN_ADMIN_TOKEN")

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

# ─── Traefik static config ────────────────────────────────
section "Generating Traefik config"
mkdir -p traefik/data traefik/data/dynamic

ACME_CHALLENGE="${TRAEFIK_ACME_CHALLENGE:-http}"
if [ "$ACME_CHALLENGE" = "dns" ]; then
  [ -z "${TRAEFIK_DNS_PROVIDER:-}" ] && error "TRAEFIK_DNS_PROVIDER is required for DNS challenge"
  [ -z "${TRAEFIK_DNS_TOKEN:-}" ]    && error "TRAEFIK_DNS_TOKEN is required for DNS challenge"

  case "$TRAEFIK_DNS_PROVIDER" in
    cloudflare)   export CF_DNS_API_TOKEN="${TRAEFIK_DNS_TOKEN}" ;;
    ovh)          export OVH_APPLICATION_SECRET="${TRAEFIK_DNS_TOKEN}" ;;
    digitalocean) export DO_AUTH_TOKEN="${TRAEFIK_DNS_TOKEN}" ;;
    route53)      export AWS_SECRET_ACCESS_KEY="${TRAEFIK_DNS_TOKEN}" ;;
    hetzner)      export HETZNER_API_KEY="${TRAEFIK_DNS_TOKEN}" ;;
    *) error "Unsupported DNS provider: ${TRAEFIK_DNS_PROVIDER}. Add it to deploy.sh." ;;
  esac

  TEMPLATE="traefik/templates/traefik.dns.yml.tpl"
  info "Using DNS challenge (provider: ${TRAEFIK_DNS_PROVIDER})"
else
  TEMPLATE="traefik/templates/traefik.http.yml.tpl"
  info "Using HTTP challenge"
fi

envsubst < "$TEMPLATE" > traefik/data/traefik.yml
info "traefik.yml generated"

envsubst < "traefik/templates/authentik.yml.tpl" > traefik/data/dynamic/authentik.yml
info "authentik middleware generated"

# ─── Registry profile ─────────────────────────────────────
COMPOSE_PROFILES=""
if [ "${REGISTRY_LOCAL:-false}" = "true" ]; then
  COMPOSE_PROFILES="--profile registry"
  info "Registry profile enabled"
fi

# ─── Core services first ──────────────────────────────────
section "Starting core services"
docker compose $COMPOSE_PROFILES up -d postgres redis

wait_healthy postgres
wait_healthy redis

# ─── Full stack ───────────────────────────────────────────
section "Starting remaining services"
docker compose $COMPOSE_PROFILES up -d

# ─── Summary ──────────────────────────────────────────────
section "Stack status"
docker compose ps

echo -e "\n${GREEN}Deployment complete.${NC}"
echo -e "  Traefik      : https://proxy.${DOMAIN}"
echo -e "  Authentik    : https://sso.${DOMAIN}"
echo -e "  Vaultwarden  : https://vault.${DOMAIN}"
echo -e "  Dozzle       : https://logs.${DOMAIN}"
[ "${REGISTRY_LOCAL:-false}" = "true" ] && echo -e "  Registry     : https://registry.${DOMAIN}"
echo ""