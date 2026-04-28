# infra

Production-ready self-hosted infrastructure template.

**Stack:** Traefik · Postgres · Redis · Authentik · Dozzle · Postgres Backup · Docker Registry (optional)

---

## First deploy

```bash
git clone https://github.com/yjalil/infra.git
cd infra
./bootstrap.sh
```

Fill in `.env` — see checklist printed by bootstrap. Then:

```bash
./deploy.sh
```

---

## What bootstrap does

- Generates `.env` with all secrets pre-filled
- Creates Docker networks (`internal`, `data`)
- Creates `traefik/data/acme.json` with correct permissions
- Creates backup directory with correct ownership
- Builds the `postgres-backup` image locally

Run once per server. Idempotent — safe to re-run.

---

## What deploy does

- Validates `.env` is filled
- Generates `traefik/data/traefik.yml` from template
- Starts Postgres + Redis first, waits for healthy
- Brings up the full stack

Run on every update: `git pull && ./deploy.sh`

---

## Networks

Two external Docker networks must exist before deploy — bootstrap creates them.

| Network    | Purpose                        |
|------------|--------------------------------|
| `internal` | Traefik ↔ services             |
| `data`     | Services ↔ Postgres, Redis     |

---

## TLS / ACME

Default: HTTP challenge. For DNS challenge (wildcard certs or non-public servers):

```bash
TRAEFIK_ACME_CHALLENGE=dns
TRAEFIK_DNS_PROVIDER=cloudflare   # or: ovh, digitalocean, route53, hetzner
TRAEFIK_DNS_TOKEN=your_api_token
```

`deploy.sh` maps the token to the provider-specific env var automatically.

---

## Backups

Postgres is backed up daily via `prodrigestivill/postgres-backup-local` + rclone.

Configure destination in `.env`:

```bash
BACKUP_PATH=./backup/backups        # local
RCLONE_DEST=s3:mybucket/postgres    # or sftp:path
```

Copy the relevant config from `backup/rclone/` examples and place at `backup/rclone/rclone.conf`.

---

## Adding a new service

1. Create `myservice/docker-compose.yml`
2. Add provisioner sidecar if it needs a Postgres DB (see `authentik/docker-compose.yml`)
3. Add to root `docker-compose.yml` includes
4. Add vars to `.env`

---

## Registry (optional)

Set `REGISTRY_LOCAL=true` in `.env` to spin up a local Docker registry.
Requires `REGISTRY_USER` and `REGISTRY_PASSWORD` — bootstrap generates `htpasswd` automatically.