-- index_usage.sql
-- All indexes on user tables with size and scan counts, biggest first.
--   psql -X -v tbl=public.orders -f indexes/index_usage.sql   (one table)

\if :{?tbl}
\else
  \set tbl ''
\endif

SELECT
    s.relid::regclass                          AS tbl,
    s.indexrelname                             AS idx,
    pg_size_pretty(pg_relation_size(s.indexrelid)) AS size,
    s.idx_scan,
    s.idx_tup_read,
    s.idx_tup_fetch,
    s.last_idx_scan,                            -- PG16+, remove on older versions
    i.indisunique AS uniq,
    am.amname     AS type
FROM pg_stat_user_indexes s
JOIN pg_index i  ON i.indexrelid = s.indexrelid
JOIN pg_class ic ON ic.oid = s.indexrelid
JOIN pg_am am    ON am.oid = ic.relam
WHERE (:'tbl' = '' OR s.relid = to_regclass(:'tbl'))
ORDER BY pg_relation_size(s.indexrelid) DESC
LIMIT 50;
