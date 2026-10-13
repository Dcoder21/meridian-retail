# Database backup and recovery

server_setup.sh installs a cron entry for ubuntu at 02:00 host time daily.
The default Ubuntu host uses UTC, so this is 03:00 Africa/Lagos. Confirm with
timedatectl before relying on the schedule. Backups use PostgreSQL 16's
pg_dump inside the running database container and custom archive format.
The snapshot is transactionally consistent for all tables.

backup_db.sh locks out overlapping runs, writes a temporary archive, checks
its archive index, atomically renames it, and writes a portable SHA-256
checksum. A restrictive umask protects customer data. Completed backups and
checksums older than 14 days are removed only after a new archive succeeds.
Cron output is rotated weekly. Archive-index validation alone does not prove
recoverability; a restore rehearsal is mandatory.

Run on EC2 after seeded products exist:

```bash
cd /opt/meridian
bash scripts/backup_db.sh
backup=$(find backups -maxdepth 1 -name '*.dump' | sort | tail -1)
bash scripts/verify_restore.sh "$backup" | tee restore-evidence.txt
```

The rehearsal restores into a uniquely named isolated database, records a
full product row and count, deletes that row, restores again, and checks that
the exact row and count return. A trap removes the rehearsal database.
Production data is unaffected. Save the PASS output, timestamp, commit,
archive checksum, and backup log as D9 evidence. The CI workflow also runs
this test; a CI result is distinct from a manual rehearsal on EC2.

For a real recovery, stop writers, preserve a fresh backup if possible, then:

```bash
docker compose stop auth-service catalog-service orders-service
ALLOW_PRODUCTION_RESTORE=yes bash scripts/restore_db.sh backups/CHOSEN.dump meridian_db
docker compose up -d --wait
python scripts/smoke_test.py https://YOUR-SHOP.duckdns.org
```

Use the actual database name if changed. restore_db.sh verifies the checksum
and archive before replacing the target database. Replacement is destructive.
Production replacement requires the explicit environment flag. Failed restore
transactions leave an empty recreated database; keep writers stopped and
resolve the error before restarting them.

Daily backups give a target recovery point of up to 24 hours, but a failed
cron job increases that interval. Recovery time is unmeasured until a live
rehearsal. These backups share the EC2 disk with PostgreSQL; they do not
protect against instance or disk loss. An off-host encrypted copy and failure
alerting are required for a stronger production disaster-recovery guarantee.
