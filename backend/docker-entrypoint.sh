#!/bin/sh
set -e

# Idempotent: applies only pending migrations.
npx prisma migrate deploy

# Demo data is opt-in (SEED_ON_START=true). The seed only touches the demo
# accounts, but a failure here must not keep the API from starting.
if [ "$SEED_ON_START" = "true" ]; then
  echo "SEED_ON_START=true: seeding demo data..."
  node dist/seed.js || echo "WARN: seed failed; starting the API anyway"
fi

exec node dist/main.js
