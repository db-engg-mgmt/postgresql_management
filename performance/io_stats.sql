-- io_stats.sql
-- pg_stat_io breakdown (PG16+). Shows who is doing reads/writes/fsyncs:
-- client backends writing their own dirty buffers = bgwriter/checkpointer
-- can't keep up.

SELECT current_setting('server_version_num')::int >= 160000 AS has_pg_stat_io \gset

\if :has_pg_stat_io
SELECT
    backend_type,
    object,
    context,
    reads,
    writes,
    extends,
    fsyncs,
    evictions,
    reuses,
    round(read_time::numeric, 0)  AS read_ms,
    round(write_time::numeric, 0) AS write_ms
FROM pg_stat_io
WHERE coalesce(reads, 0) + coalesce(writes, 0) + coalesce(extends, 0) > 0
ORDER BY coalesce(reads, 0) + coalesce(writes, 0) DESC;
\else
\echo 'pg_stat_io needs PostgreSQL 16 or newer'
\endif

-- read/write time columns stay 0 unless track_io_timing = on.
-- check overhead first:  pg_test_timing
