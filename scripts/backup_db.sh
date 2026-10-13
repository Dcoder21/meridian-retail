#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
cd "$(dirname "$0")/.."
backup_dir=${BACKUP_DIR:-$PWD/backups}
mkdir -p "$backup_dir"
exec 9>"$backup_dir/.backup.lock"
flock -n 9 || { echo 'Backup already running.' >&2; exit 1; }
file="$backup_dir/meridian-$(date -u +%Y%m%dT%H%M%S)-$$.dump"
trap 'rm -f "$file.tmp"' EXIT
docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$file.tmp"
# Reject empty or unreadable archives before publishing or pruning backups.
docker compose exec -T postgres pg_restore --list < "$file.tmp" > /dev/null
mv "$file.tmp" "$file"
(cd "$backup_dir" && sha256sum "$(basename "$file")") > "$file.sha256"
find "$backup_dir" -maxdepth 1 -type f \( -name 'meridian-*.dump' -o -name 'meridian-*.dump.sha256' \) -mtime +14 -delete
echo "Backup created: $file"
