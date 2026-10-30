-- stale_stats.sql
-- Tables where a lot has changed since the last analyze. Bad row estimates
-- are behind a big chunk of "the plan suddenly changed" tickets.

SELECT
    schemaname || '.' || relname   AS tbl,
    n_live_tup,
    n_mod_since_analyze,
    round(100.0 * n_mod_since_analyze / nullif(n_live_tup, 0), 1) AS pct_changed,
    greatest(last_analyze, last_autoanalyze) AS last_analyzed,
    n_ins_since_vacuum                 -- PG13+
FROM pg_stat_user_tables
WHERE n_live_tup > 10000
ORDER BY n_mod_since_analyze DESC
LIMIT 25;

-- never analyzed at all
SELECT schemaname || '.' || relname AS tbl, n_live_tup
FROM pg_stat_user_tables
WHERE last_analyze IS NULL AND last_autoanalyze IS NULL
ORDER BY n_live_tup DESC;

-- columns using a non default statistics target
SELECT attrelid::regclass AS tbl, attname, attstattarget
FROM pg_attribute
WHERE attstattarget > 0
  AND attrelid IN (SELECT relid FROM pg_stat_user_tables);

-- fix:  ANALYZE VERBOSE schema.table;
-- skewed column:  ALTER TABLE t ALTER COLUMN c SET STATISTICS 1000; ANALYZE t;
