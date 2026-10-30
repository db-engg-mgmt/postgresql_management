# PITR notes (PG12+)

Restoring to a point in time from a base backup + archived WAL.

## Prereqs on the primary

```
wal_level = replica
archive_mode = on
archive_command = 'test ! -f /archive/%f && cp %p /archive/%f'
```

Check it actually works: `replication/archiver.sql`.

## Restore

```bash
systemctl stop postgresql-17
mv /var/lib/pgsql/17/data /var/lib/pgsql/17/data.broken     # don't delete yet
mkdir /var/lib/pgsql/17/data && chmod 700 /var/lib/pgsql/17/data
tar -xf /backup/base/base_20261028_0100/base.tar.zst -C /var/lib/pgsql/17/data   # or .tar.gz
rm -rf /var/lib/pgsql/17/data/pg_wal/*
```

In `postgresql.conf` (or `postgresql.auto.conf`):

```
restore_command = 'cp /archive/%f %p'
recovery_target_time = '2026-10-28 14:32:00-08'
recovery_target_action = 'pause'
```

```bash
touch /var/lib/pgsql/17/data/recovery.signal
chown -R postgres: /var/lib/pgsql/17/data
systemctl start postgresql-17
```

Once it pauses, check the data:

```sql
SELECT pg_is_in_recovery(), pg_last_xact_replay_timestamp();
-- look at the rows you care about
SELECT pg_wal_replay_resume();   -- with action=pause this promotes
```

## Things that bite

- `recovery_target_time` without a timezone uses the server's TimeZone setting.
- The target has to be *after* the end of the base backup.
- If you overshoot, you have to start over from the base backup.
- After promotion the timeline changes; old archived WAL from the original timeline
  is still in the archive, don't clean it out until the new base backup is taken.
- Easier alternative for "someone dropped a table at 14:32": restore to a
  scratch host, `pg_dump -t` the table, load it back into prod.
