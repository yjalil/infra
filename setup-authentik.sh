#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load env
set -a
source "${SCRIPT_DIR}/.env"
set +a

WORKER_CONTAINER="${COMPOSE_PROJECT_NAME}-worker-1"
BLUEPRINT_SRC="${SCRIPT_DIR}/authentik/blueprints/infra-apps.yaml.tpl"
BLUEPRINT_OUT="${SCRIPT_DIR}/authentik/blueprints/infra-apps.yaml"

echo "==> Rendering blueprint..."
envsubst < "${BLUEPRINT_SRC}" > "${BLUEPRINT_OUT}"
echo "    Written: ${BLUEPRINT_OUT}"

echo "==> Waiting for authentik worker to be healthy..."
until docker inspect --format='{{.State.Health.Status}}' "${WORKER_CONTAINER}" 2>/dev/null | grep -q "healthy"; do
  echo "    ... still waiting"
  sleep 5
done
echo "    Worker is healthy."

echo "==> Generating akadmin recovery link..."
RECOVERY_PATH=$(docker exec "${WORKER_CONTAINER}" ak create_recovery_key 10 akadmin 2>&1 | grep -o '/recovery/use-token/[^ ]*')
RECOVERY_LINK="https://${AUTHENTIK_DOMAIN}${RECOVERY_PATH}"

echo ""
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  AUTHENTIK RECOVERY LINK (valid 10 minutes)                  │"
echo "  │                                                              │"
printf "  │  %s\n" "${RECOVERY_LINK}"
echo "  │                                                              │"
echo "  │  Save this — it won't be shown again.                        │"
echo "  └──────────────────────────────────────────────────────────────┘"
echo ""

echo "==> Applying blueprint..."
docker exec "${WORKER_CONTAINER}" ak apply_blueprint /blueprints/custom/infra-apps.yaml

echo ""
echo "Done. Infra apps configured in Authentik:"
echo "  - Traefik Dashboard -> https://${TRAEFIK_DOMAIN}"
echo "  - Server Status     -> https://${DOZZLE_DOMAIN}"
echo ""