# infra

Production-ready self-hosted infrastructure template.

**Stack:** Traefik · Postgres · Redis · Authentik · Vaultwarden · Dozzle · Postgres Backup · Docker Registry (optional)

---

## First deploy

### Option A — from Bitwarden (recommended for nexus/mother VPS)

Requires `bw` CLI installed and a Bitwarden account with `nexus-bootstrap` and `nexus-rclone-conf` notes in the `devops` collection.

```bash
git clone https://github.com/yjalil/infra.git
cd infra
./setup-bw.sh
./deploy.sh
./setup-authentik.sh
```

`setup-bw.sh` pulls secrets from Bitwarden, writes `.env` and `backup/rclone/rclone.conf`, then runs `bootstrap.sh` automatically.

### Option B — manual

```bash
git clone https://github.com/yjalil/infra.git
cd infra
./bootstrap.sh
```

Fill in `.env` — see checklist printed by bootstrap. Then:

```bash
./deploy.sh
./setup-authentik.sh
```

---

## What each script does

| Script | Run | Purpose |
|--------|-----|---------|
| `setup-bw.sh` | Once | Pull secrets from Bitwarden → write `.env` + `rclone.conf` → run bootstrap |
| `bootstrap.sh` | Once | Generate `.env`, create Docker networks, create `acme.json`, build backup image |
| `deploy.sh` | Every update | Validate `.env`, generate Traefik config, start the full stack |
| `setup-authentik.sh` | Once | Configure Authentik apps (Traefik, Dozzle, Vaultwarden) via blueprint |

---

## Networks

Two external Docker networks must exist before deploy — bootstrap creates them.

| Network    | Purpose                    |
|------------|----------------------------|
| `internal` | Traefik ↔ services         |
| `data`     | Services ↔ Postgres, Redis |

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
RCLONE_DEST=gdrive:Backups/nexus    # Google Drive
RCLONE_DEST=s3:mybucket/postgres    # S3-compatible
RCLONE_DEST=sftp:path               # SFTP
```

Copy the relevant config from `backup/rclone/` examples and place at `backup/rclone/rclone.conf`.

---

## Adding a new service

1. Create `myservice/docker-compose.yml`
2. Add provisioner sidecar if it needs a Postgres DB (see `authentik/docker-compose.yml`)
3. Add to root `docker-compose.yml` includes
4. Add vars to `.env.example`

---

## Registry (optional)

Set `REGISTRY_LOCAL=true` in `.env` to spin up a local Docker registry.
Requires `REGISTRY_USER` and `REGISTRY_PASSWORD` — bootstrap generates `htpasswd` automatically.
