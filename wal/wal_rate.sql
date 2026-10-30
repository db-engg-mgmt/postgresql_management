-- wal_rate.sql
-- Measures WAL generation over a 60 second window. Useful for sizing
-- max_wal_size, archive storage, and replica network.
--   psql -X -v secs=300 -f wal/wal_rate.sql

\if :{?secs}
\else
  \set secs 60
\endif

SELECT pg_current_wal_lsn() AS start_lsn \gset
\echo sampling for :secs seconds...
SELECT pg_sleep(:secs);

SELECT
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), :'start_lsn'))           AS wal_in_window,
    pg_size_pretty((pg_wal_lsn_diff(pg_current_wal_lsn(), :'start_lsn') / :secs)::bigint) AS per_second,
    pg_size_pretty((pg_wal_lsn_diff(pg_current_wal_lsn(), :'start_lsn') / :secs * 3600)::bigint) AS per_hour_est;

-- cumulative WAL stats (PG14+)
SELECT wal_records, wal_fpi, pg_size_pretty(wal_bytes) AS wal_bytes,
       round(100.0 * wal_fpi / nullif(wal_records, 0), 1) AS fpi_pct,
       wal_buffers_full, stats_reset
FROM pg_stat_wal;
-- high fpi_pct = full page images dominate. Longer checkpoint_timeout and
-- wal_compression = lz4/zstd both help.
