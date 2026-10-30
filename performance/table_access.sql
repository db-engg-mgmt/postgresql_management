-- table_access.sql
-- Seq scan vs index scan per table. Big tables with lots of seq_tup_read are
-- where a missing index usually lives. Confirm with EXPLAIN (ANALYZE, BUFFERS)
-- before creating anything.

SELECT
    schemaname || '.' || relname                      AS tbl,
    pg_size_pretty(pg_relation_size(relid))           AS size,
    n_live_tup,
    seq_scan,
    seq_tup_read,
    seq_tup_read / nullif(seq_scan, 0)                AS avg_rows_per_seqscan,
    idx_scan,
    round(100.0 * idx_scan / nullif(seq_scan + idx_scan, 0), 1) AS idx_pct,
    n_tup_ins, n_tup_upd, n_tup_del,
    round(100.0 * n_tup_hot_upd / nullif(n_tup_upd, 0), 1)      AS hot_upd_pct
FROM pg_stat_user_tables
WHERE pg_relation_size(relid) > 10 * 1024 * 1024
ORDER BY seq_tup_read DESC
LIMIT 25;

-- low HOT update ratio on a heavily updated table -> consider fillfactor 80-90
-- and check whether an indexed column is being updated needlessly.
