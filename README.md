# postgresql_management

SQL and shell scripts I keep on hand for PostgreSQL administration and
troubleshooting: what's running, what's blocked, why vacuum isn't keeping up,
replication lag, bloat, index cleanup, upgrades, backups.

Written for and tested on PostgreSQL 13 - 17. Most of it works on 12. A few
scripts branch on version (`\if` on `server_version_num`) where catalogs changed,
e.g. `pg_stat_checkpointer` in 17.

## Layout

| dir | what's in it |
|---|---|
| `monitoring/` | sessions, long queries, wait events, connections, cache hit, per-db overview |
| `locks/` | blocking tree, lock detail, DDL lock queue, kill templates |
| `performance/` | pg_stat_statements top queries, seq scans, stale stats, pg_stat_io, EXPLAIN template |
| `indexes/` | unused, duplicate / overlapping, invalid, FK columns without an index, usage |
| `bloat/` | catalog-based table bloat estimate, exact check with pgstattuple |
| `vacuum/` | XID wraparound, what's holding back xmin, autovacuum queue, vacuum progress |
| `replication/` | primary / standby status, slots, logical replication, WAL archiver |
| `wal/` | checkpoint stats, WAL generation rate |
| `admin/` | sizes, partitions, sequences near limit, changed settings, extensions, temp files |
| `security/` | role audit, password hash types, hba rules, table privileges |
| `maintenance/` | reindex bloated btrees, freeze oldest tables (cron-able) |
| `upgrade/` | pre-upgrade checks, pg_upgrade runbook |
| `backup/` | pg_dump of all dbs, pg_basebackup wrapper, PITR notes |
| `bin/` | `pg_health_check.sh` - runs the main checks and writes a report file |

## Usage

Everything is plain psql. Run with `-X` so your own `.psqlrc` doesn't get in the way:

```bash
psql -X -d appdb -f monitoring/activity.sql
psql -X -d appdb -v mins=15 -f monitoring/long_running.sql
psql -X -d appdb -v tbl=public.orders -f bloat/pgstattuple_check.sql
```

Some scripts take psql variables (`-v name=value`), the header comment of each file says which.

In an incident I usually go:

1. `monitoring/wait_events.sql` with `\watch 2`
2. `locks/blocking_tree.sql` if there's any `Lock:` waits
3. `monitoring/long_running.sql`
4. `performance/top_queries.sql`

For "tables keep growing / vacuum isn't helping": `vacuum/xmin_horizon.sql` first,
then `vacuum/vacuum_queue.sql` and `bloat/table_bloat_estimate.sql`.

Full report to attach to a ticket:

```bash
./bin/pg_health_check.sh -d appdb -h db01 -U dba -o /tmp
```

`psqlrc.example` has shortcuts (`:act`, `:locks`, `:waits` ...) so you don't have to
remember paths.

## Permissions

Read-only scripts work fine as a member of `pg_monitor`:

```sql
CREATE ROLE dba_monitor LOGIN;
GRANT pg_monitor TO dba_monitor;
```

`security/roles_audit.sql` reads `pg_authid` and needs superuser.
Scripts under `maintenance/` change things, read them first.

## Extensions used

- `pg_stat_statements` - `performance/top_queries.sql`, needs `shared_preload_libraries`
- `pgstattuple` - `bloat/pgstattuple_check.sql`, `maintenance/reindex_bloated.sh`
- `pg_buffercache` - optional query in `monitoring/cache_hit.sql`

## Credits / further reading

A lot of the ideas here came from reading other people's work over the years:

- [pgexperts/pgx_scripts](https://github.com/pgexperts/pgx_scripts)
- [NikolayS/postgres_dba](https://github.com/NikolayS/postgres_dba)
- [ioguix/pgsql-bloat-estimation](https://github.com/ioguix/pgsql-bloat-estimation)
- [dataegret/pg-utils](https://github.com/dataegret/pg-utils)
- [br8dba.com PostgreSQL DBA scripts](https://www.br8dba.com/postgresql-dba-scripts/)
- The PostgreSQL docs chapters on monitoring and routine maintenance

## Disclaimer

Test on non-prod first. The kill / reindex / vacuum scripts default to dry-run or are
commented out, keep it that way until you've looked at the output.

MIT licensed.
