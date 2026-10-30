-- unused_indexes.sql
-- Indexes with zero (or near zero) scans since stats were last reset.
--
-- Before dropping anything:
--   * check stats_reset date below - a week of stats proves nothing about the month-end job
--   * check the standbys too, idx_scan is per node and read traffic may only hit replicas
--   * unique / PK / exclusion indexes are skipped, they enforce constraints
--   * DROP INDEX CONCURRENTLY, and keep the CREATE statement handy (indexdef column)

SELECT stats_reset FROM pg_stat_database WHERE datname = current_database();

SELECT
    s.schemaname || '.' || s.relname          AS tbl,
    s.indexrelname                            AS idx,
    s.idx_scan,
    pg_size_pretty(pg_relation_size(s.indexrelid)) AS idx_size,
    pg_size_pretty(pg_relation_size(s.relid))      AS tbl_size,
    t.n_tup_ins + t.n_tup_upd + t.n_tup_del   AS writes_on_table,
    pg_get_indexdef(s.indexrelid)             AS indexdef
FROM pg_stat_user_indexes s
JOIN pg_index i              ON i.indexrelid = s.indexrelid
JOIN pg_stat_user_tables t   ON t.relid = s.relid
WHERE s.idx_scan < 50
  AND NOT i.indisunique
  AND NOT i.indisprimary
  AND NOT EXISTS (SELECT 1 FROM pg_constraint c WHERE c.conindid = s.indexrelid)
ORDER BY pg_relation_size(s.indexrelid) DESC;
