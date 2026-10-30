-- db_overview.sql
-- One-screen health summary per database: size, cache hit, commits/rollbacks,
-- deadlocks, temp spill, conflicts on standby.
-- Counters are cumulative since stats_reset, so compare two runs if you need rates.

SELECT
    version();

SELECT
    pg_postmaster_start_time()                          AS started,
    date_trunc('second', now() - pg_postmaster_start_time()) AS uptime,
    pg_is_in_recovery()                                 AS is_standby,
    current_setting('data_directory')                   AS data_dir;

SELECT
    d.datname,
    pg_size_pretty(pg_database_size(d.datname))          AS size,
    s.numbackends                                        AS conns,
    round(100.0 * s.blks_hit / nullif(s.blks_hit + s.blks_read, 0), 2) AS cache_hit_pct,
    s.xact_commit,
    s.xact_rollback,
    round(100.0 * s.xact_rollback / nullif(s.xact_commit + s.xact_rollback, 0), 2) AS rollback_pct,
    s.deadlocks,
    s.conflicts,
    s.temp_files,
    pg_size_pretty(s.temp_bytes)                         AS temp_written,
    age(d.datfrozenxid)                                  AS xid_age,
    s.stats_reset
FROM pg_database d
JOIN pg_stat_database s ON s.datid = d.oid
WHERE d.datallowconn
ORDER BY pg_database_size(d.datname) DESC;
