#!/usr/bin/env bash
# Mandatory manual rehearsal: copy production, delete a row in the copy, restore, compare.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
file=${1:?Usage: verify_restore.sh BACKUP}
target="meridian_restore_test_$$"
sql() {
  docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$1" -At -v ON_ERROR_STOP=1 -c "$2"' sh "$target" "$1"
}
cleanup() { docker compose exec -T postgres sh -c 'dropdb -U "$POSTGRES_USER" --if-exists --force "$1"' sh "$target"; }
trap cleanup EXIT
bash scripts/restore_db.sh "$file" "$target"
before=$(sql 'SELECT count(*) FROM products;')
[[ $before -gt 0 ]] || { echo 'No seeded rows; cannot prove recovery.' >&2; exit 1; }
row=$(sql 'SELECT row_to_json(p)::text FROM products p ORDER BY id LIMIT 1;')
sql 'DELETE FROM products WHERE id = (SELECT min(id) FROM products);'
after_delete=$(sql 'SELECT count(*) FROM products;')
[[ $after_delete -eq $((before - 1)) ]]
bash scripts/restore_db.sh "$file" "$target"
after_restore=$(sql 'SELECT count(*) FROM products;')
restored_row=$(sql 'SELECT row_to_json(p)::text FROM products p ORDER BY id LIMIT 1;')
[[ $before == "$after_restore" && $row == "$restored_row" ]]
echo "PASS: row recovered exactly; before=$before deleted=$after_delete restored=$after_restore"
