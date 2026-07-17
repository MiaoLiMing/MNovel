#!/usr/bin/env bash
set -euo pipefail

deploy_dir="${MNOVEL_DEPLOY_DIR:-/opt/mnovel/app/deploy}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_name="mnovel-${timestamp}.db"

cd "$deploy_dir"
docker compose exec -T api \
  python -m app.db.backup /app/data/mnovel.db "/app/backup/${backup_name}" \
  </dev/null

find /opt/mnovel/backup -maxdepth 1 -type f -name 'mnovel-*.db' -mtime +7 -delete
echo "/opt/mnovel/backup/${backup_name}"
