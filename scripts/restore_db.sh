#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
file=$(realpath "${1:?Usage: restore_db.sh BACKUP TARGET_DATABASE}")
target=${2:?Supply an isolated target database, or explicitly approve production via ALLOW_PRODUCTION_RESTORE=yes}
[[ $target =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo 'Invalid database name.' >&2; exit 1; }
[[ -f $file && -f $file.sha256 ]] || { echo 'Backup and checksum required.' >&2; exit 1; }
(cd "$(dirname "$file")" && sha256sum --check "$(basename "$file").sha256")
docker compose exec -T postgres pg_restore --list < "$file" > /dev/null
production=$(docker compose exec -T postgres sh -c 'printf "%s" "$POSTGRES_DB"')
if [[ $target == "$production" && ${ALLOW_PRODUCTION_RESTORE:-no} != yes ]]; then
  echo 'Production restore requires stopped application services and ALLOW_PRODUCTION_RESTORE=yes.' >&2
  exit 1
fi
docker compose exec -T postgres sh -ec 'dropdb -U "$POSTGRES_USER" --if-exists --force "$1"; createdb -U "$POSTGRES_USER" "$1"' sh "$target"
docker compose exec -T postgres sh -c 'pg_restore -U "$POSTGRES_USER" -d "$1" --no-owner --no-acl --exit-on-error --single-transaction' sh "$target" < "$file"
docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$1" -v ON_ERROR_STOP=1 -c "SELECT count(*) AS products FROM products;"' sh "$target"
echo "Restore complete: $target"
