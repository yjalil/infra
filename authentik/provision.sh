#!/bin/sh
set -e

RETRIES=30
until pg_isready -h "$POSTGRES_HOST" -U "$POSTGRES_SUPER_USER" || [ "$RETRIES" -eq 0 ]; do
  echo "Waiting for PostgreSQL... $RETRIES retries left"
  RETRIES=$((RETRIES - 1))
  sleep 2
done
[ "$RETRIES" -eq 0 ] && echo "Postgres not ready, aborting" && exit 1

# Create user idempotently
psql -h "$POSTGRES_HOST" -U "$POSTGRES_SUPER_USER" -d postgres <<SQL
DO \$\$
BEGIN
  CREATE ROLE $POSTGRES_AUTHENTIK_USER WITH LOGIN PASSWORD '$POSTGRES_AUTHENTIK_PASSWORD';
EXCEPTION WHEN duplicate_object THEN
  RAISE NOTICE 'role $POSTGRES_AUTHENTIK_USER already exists, skipping';
END
\$\$;
SQL

# Create database idempotently
psql -h "$POSTGRES_HOST" -U "$POSTGRES_SUPER_USER" -d postgres -tc \
  "SELECT 1 FROM pg_database WHERE datname='$POSTGRES_AUTHENTIK_DB'" \
  | grep -q 1 \
  && echo "database $POSTGRES_AUTHENTIK_DB already exists, skipping" \
  || psql -h "$POSTGRES_HOST" -U "$POSTGRES_SUPER_USER" -d postgres \
     -c "CREATE DATABASE $POSTGRES_AUTHENTIK_DB OWNER $POSTGRES_AUTHENTIK_USER"

echo "Authentik DB provisioning complete"