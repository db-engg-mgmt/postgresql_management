-- top_queries.sql
-- Heaviest statements from pg_stat_statements (PG13+ column names).
--
-- setup (needs restart for the preload):
--   shared_preload_libraries = 'pg_stat_statements'
--   pg_stat_statements.track = all
--   CREATE EXTENSION pg_stat_statements;
--
-- psql -X -v n=30 -f performance/top_queries.sql

\if :{?n}
\else
  \set n 20
\endif

\echo '=== by total time (where the server actually spends its time)'
SELECT
    queryid,
    calls,
    round(total_exec_time::numeric / 1000, 1)                        AS total_s,
    round(mean_exec_time::numeric, 2)                                AS mean_ms,
    round(stddev_exec_time::numeric, 2)                              AS stddev_ms,
    round((100 * total_exec_time / sum(total_exec_time) OVER ())::numeric, 1) AS pct,
    rows,
    round(100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0), 1) AS hit_pct,
    left(regexp_replace(query, '\s+', ' ', 'g'), 100)                AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT :n;

\echo '=== slowest per call (min 10 calls)'
SELECT queryid, calls,
       round(mean_exec_time::numeric, 1) AS mean_ms,
       round(max_exec_time::numeric, 1)  AS max_ms,
       left(regexp_replace(query, '\s+', ' ', 'g'), 100) AS query
FROM pg_stat_statements
WHERE calls >= 10
ORDER BY mean_exec_time DESC
LIMIT :n;

\echo '=== most physical reads'
SELECT queryid, calls, shared_blks_read,
       pg_size_pretty(shared_blks_read * current_setting('block_size')::bigint) AS read_vol,
       left(regexp_replace(query, '\s+', ' ', 'g'), 100) AS query
FROM pg_stat_statements
ORDER BY shared_blks_read DESC
LIMIT :n;

\echo '=== spilling to temp (work_mem too small for these)'
SELECT queryid, calls, temp_blks_written,
       pg_size_pretty(temp_blks_written * current_setting('block_size')::bigint) AS temp_vol,
       left(regexp_replace(query, '\s+', ' ', 'g'), 100) AS query
FROM pg_stat_statements
WHERE temp_blks_written > 0
ORDER BY temp_blks_written DESC
LIMIT :n;

\echo '=== WAL heavy statements'
SELECT queryid, calls, pg_size_pretty(wal_bytes) AS wal, wal_fpi,
       left(regexp_replace(query, '\s+', ' ', 'g'), 100) AS query
FROM pg_stat_statements
ORDER BY wal_bytes DESC
LIMIT :n;

-- reset after a tuning round:  SELECT pg_stat_statements_reset();
