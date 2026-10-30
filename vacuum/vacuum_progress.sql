-- vacuum_progress.sql
-- Running vacuums (auto and manual) with phase and percent through the heap.
-- \watch 10 on this during a big manual vacuum.

SELECT
    p.pid,
    p.datname,
    p.relid::regclass                        AS tbl,
    p.phase,
    pg_size_pretty(p.heap_blks_total * current_setting('block_size')::bigint) AS heap_size,
    round(100.0 * p.heap_blks_scanned  / nullif(p.heap_blks_total, 0), 1) AS scanned_pct,
    round(100.0 * p.heap_blks_vacuumed / nullif(p.heap_blks_total, 0), 1) AS vacuumed_pct,
    p.index_vacuum_count                     AS index_passes,
    date_trunc('second', now() - a.xact_start) AS running_for,
    a.wait_event_type || ':' || a.wait_event AS waiting_on,
    CASE WHEN a.query ILIKE '%to prevent wraparound%' THEN 'WRAPAROUND' END AS wraparound,
    left(a.query, 80)                        AS query
FROM pg_stat_progress_vacuum p
JOIN pg_stat_activity a ON a.pid = p.pid
ORDER BY a.xact_start;

-- index_passes > 1 means maintenance_work_mem / autovacuum_work_mem ran out
-- holding dead tuple ids and it had to scan every index again (less of an
-- issue on PG17+ with the new tid store).

SELECT count(*) AS autovac_workers_busy,
       current_setting('autovacuum_max_workers') AS max_workers
FROM pg_stat_activity
WHERE backend_type = 'autovacuum worker';

-- other progress views worth knowing:
--   pg_stat_progress_create_index, pg_stat_progress_analyze,
--   pg_stat_progress_cluster, pg_stat_progress_basebackup, pg_stat_progress_copy
