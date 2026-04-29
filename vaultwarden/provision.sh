#!/bin/sh
set -e

RETRIES=30
until pg_isready -h "$POSTGRES_HOST" -U "$POSTGRES_SUPER_USER" || [ "$RETRIES" -eq 0 ]; do
  echo "Waiting for PostgreSQL... $RETRIES retries left"
  RETRIES=$((RETRIES - 1))
  sleep 2
done
[ "$RETRIES" -eq 0 ] && echo "Postgres not ready, aborting" && exit 1

psql -h "$POSTGRES_HOST" -U "$POSTGRES_SUPER_USER" -d postgres <<SQL
DO \$\$
BEGIN
  CREATE ROLE $POSTGRES_VAULTWARDEN_USER WITH LOGIN PASSWORD '$POSTGRES_VAULTWARDEN_PASSWORD';
EXCEPTION WHEN duplicate_object THEN
  RAISE NOTICE 'role $POSTGRES_VAULTWARDEN_USER already exists, skipping';
END
\$\$;
SQL

psql -h "$POSTGRES_HOST" -U "$POSTGRES_SUPER_USER" -d postgres -tc \
  "SELECT 1 FROM pg_database WHERE datname='$POSTGRES_VAULTWARDEN_DB'" \
  | grep -q 1 \
  && echo "database $POSTGRES_VAULTWARDEN_DB already exists, skipping" \
  || psql -h "$POSTGRES_HOST" -U "$POSTGRES_SUPER_USER" -d postgres \
     -c "CREATE DATABASE $POSTGRES_VAULTWARDEN_DB OWNER $POSTGRES_VAULTWARDEN_USER"

echo "Vaultwarden DB provisioning complete"
