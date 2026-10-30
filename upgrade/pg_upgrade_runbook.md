# pg_upgrade runbook

Notes I follow for an in-place major upgrade with `pg_upgrade --link` on RHEL/Rocky
with PGDG packages. Paths below are for 16 -> 17, adjust as needed. Debian/Ubuntu
users: `pg_upgradecluster` wraps most of this.

## Before the window

1. Run `upgrade/pre_upgrade_checks.sql` in every database. Fix anything it flags.
2. Install new binaries **and every extension** for the new version
   (`postgresql17-server`, `postgresql17-contrib`, `pg_repack_17`, `postgis34_17`, ...).
3. Read the release notes "Migration to version X" section for every major you skip.
4. Do a full rehearsal on a restored copy. Time it.
5. Confirm you have a good backup you've actually restored from recently.

## Init the new cluster

Match encoding, locale and checksums of the old one:

```bash
/usr/pgsql-16/bin/pg_controldata /var/lib/pgsql/16/data | grep -E "checksum|LC_|Database block"
psql -XAtc "select datcollate, datctype, pg_encoding_to_char(encoding) from pg_database where datname='template1'"

sudo -iu postgres /usr/pgsql-17/bin/initdb -D /var/lib/pgsql/17/data \
    --encoding=UTF8 --locale=en_US.UTF-8 --data-checksums
```

Copy over postgresql.conf / pg_hba.conf changes by hand. Don't copy the files
wholesale - parameters get renamed and removed between majors.

## Dry run

```bash
sudo -iu postgres
cd /tmp
/usr/pgsql-17/bin/pg_upgrade \
  -b /usr/pgsql-16/bin -B /usr/pgsql-17/bin \
  -d /var/lib/pgsql/16/data -D /var/lib/pgsql/17/data \
  --link --check --jobs=4
```

`--check` can run against the live old cluster. Re-run until it says
`*Clusters are compatible*`.

## The window

```bash
# stop app traffic / pgbouncer PAUSE
systemctl stop postgresql-16

/usr/pgsql-17/bin/pg_upgrade \
  -b /usr/pgsql-16/bin -B /usr/pgsql-17/bin \
  -d /var/lib/pgsql/16/data -D /var/lib/pgsql/17/data \
  --link --jobs=4

systemctl start postgresql-17
```

With `--link` the old cluster is unusable once the new one has started. If you
need a way back, use `--clone` (XFS reflink / APFS) or plain copy mode, or take
a filesystem snapshot first.

## After

```bash
# stats are not carried over before PG18 - planner is blind until this finishes
/usr/pgsql-17/bin/vacuumdb --all --analyze-in-stages --jobs=4

# pg_upgrade writes these out if needed
./update_extensions.sql   # psql -f
./delete_old_cluster.sh   # only after you're sure
```

Then:
- `ALTER EXTENSION ... UPDATE` for anything `admin/extensions.sql` flags
- re-point replicas: either rsync-based upgrade of standbys (see docs, "Upgrade Streaming
  Replication and Log-Shipping standby servers") or rebuild them with pg_basebackup
- take a fresh base backup; old backups can't be used for PITR into the new version
- check `performance/top_queries.sql` the next morning for plan regressions

## Alternatives

- **dump/restore**: `pg_dump -Fd -j 8` + `pg_restore -j 8`. Simple, slow for big DBs.
- **logical replication**: set up new-version cluster as subscriber, cut over with
  near-zero downtime. Watch for: sequences aren't replicated (sync them at cutover),
  DDL isn't replicated, tables need a PK or replica identity.
