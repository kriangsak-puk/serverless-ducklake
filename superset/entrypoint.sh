#!/usr/bin/env bash
# First-boot bootstrap: Superset keeps no state in the container itself (all metadata
# lives in RDS via SUPERSET_DB_* / superset_config.py), so it's safe to run this on every
# task start — `db upgrade` and `init` are idempotent, and admin creation is best-effort.
set -euo pipefail

superset db upgrade

superset fab create-admin \
  --username admin \
  --firstname Admin \
  --lastname User \
  --email admin@example.com \
  --password "${SUPERSET_ADMIN_PASSWORD:-admin}" || true

superset init

exec gunicorn \
  --bind "0.0.0.0:8088" \
  --workers 2 \
  --timeout 120 \
  "superset.app:create_app()"
