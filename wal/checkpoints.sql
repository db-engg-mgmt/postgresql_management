-- checkpoints.sql
-- Checkpoint / bgwriter stats. PG17 moved checkpoint counters out of
-- pg_stat_bgwriter into pg_stat_checkpointer, so this branches on version.
--
-- What you want: most checkpoints "timed", not "requested". Lots of requested
-- checkpoints = max_wal_size is too small for the write rate, which means more
-- full page writes and more WAL.

SELECT current_setting('server_version_num')::int >= 170000 AS pg17 \gset

\if :pg17
SELECT
    num_timed,
    num_requested,
    round(100.0 * num_requested / nullif(num_timed + num_requested, 0), 1) AS pct_requested,
    buffers_written,
    round(write_time::numeric / 1000) AS write_s,
    round(sync_time::numeric / 1000)  AS sync_s,
    stats_reset
FROM pg_stat_checkpointer;

SELECT buffers_clean, maxwritten_clean, buffers_alloc, stats_reset
FROM pg_stat_bgwriter;
\else
SELECT
    checkpoints_timed,
    checkpoints_req,
    round(100.0 * checkpoints_req / nullif(checkpoints_timed + checkpoints_req, 0), 1) AS pct_requested,
    buffers_checkpoint,
    buffers_clean,
    maxwritten_clean,
    buffers_backend,          -- backends writing their own buffers: bad if this is high
    buffers_backend_fsync,    -- should be 0
    buffers_alloc,
    stats_reset
FROM pg_stat_bgwriter;
\endif

SELECT name, setting, unit
FROM pg_settings
WHERE name IN ('checkpoint_timeout', 'max_wal_size', 'min_wal_size',
               'checkpoint_completion_target', 'wal_compression', 'full_page_writes',
               'bgwriter_lru_maxpages', 'bgwriter_delay', 'log_checkpoints');

-- turn on log_checkpoints if it isn't already -- the log lines give you
-- per-checkpoint write/sync time and the WAL distance between checkpoints.
