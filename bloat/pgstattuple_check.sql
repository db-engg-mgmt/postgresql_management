-- pgstattuple_check.sql
-- Exact bloat numbers for one table and its indexes, using pgstattuple.
-- This READS THE WHOLE TABLE. Run off-peak, or on a standby restored from backup.
--
--   CREATE EXTENSION IF NOT EXISTS pgstattuple;
--   psql -X -v tbl=public.orders -f bloat/pgstattuple_check.sql
--
-- pgstattuple_approx() is much cheaper (uses the visibility map) and is
-- usually good enough to decide whether a repack is worth it.

\if :{?tbl}
\else
  \echo 'usage: psql -v tbl=schema.table -f bloat/pgstattuple_check.sql'
  \quit
\endif

\echo '--- approx (cheap)'
SELECT
    pg_size_pretty(table_len)        AS table_len,
    round(approx_tuple_percent::numeric, 1) AS live_pct,
    round(dead_tuple_percent::numeric, 1)   AS dead_pct,
    round(approx_free_percent::numeric, 1)  AS free_pct,
    pg_size_pretty(approx_free_space::bigint) AS free_space
FROM pgstattuple_approx(:'tbl'::regclass);

\echo '--- btree indexes (pgstatindex)'
SELECT
    i.indexrelid::regclass                      AS idx,
    pg_size_pretty(pg_relation_size(i.indexrelid)) AS size,
    s.avg_leaf_density,
    s.leaf_fragmentation,
    s.deleted_pages
FROM pg_index i
JOIN pg_class c ON c.oid = i.indexrelid
JOIN pg_am am   ON am.oid = c.relam AND am.amname = 'btree'
CROSS JOIN LATERAL pgstatindex(i.indexrelid) s
WHERE i.indrelid = :'tbl'::regclass;

-- avg_leaf_density well under ~70 on a btree that was built at 90 = worth a
-- REINDEX INDEX CONCURRENTLY.
--
-- For the table itself: VACUUM FULL takes an AccessExclusive lock for the whole
-- rewrite. pg_repack / pg_squeeze do it online:
--   pg_repack -d appdb -t public.orders --no-superuser-check -j 2
