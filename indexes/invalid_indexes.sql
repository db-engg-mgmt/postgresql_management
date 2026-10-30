-- invalid_indexes.sql
-- Leftovers from a failed CREATE INDEX CONCURRENTLY / REINDEX CONCURRENTLY.
-- They still get maintained on every write but the planner never uses them.
-- REINDEX CONCURRENTLY leaves ones ending in _ccnew / _ccold.

SELECT
    n.nspname || '.' || c.relname   AS idx,
    i.indrelid::regclass            AS tbl,
    pg_size_pretty(pg_relation_size(c.oid)) AS size,
    i.indisvalid,
    i.indisready,
    pg_get_indexdef(c.oid)          AS def
FROM pg_index i
JOIN pg_class c     ON c.oid = i.indexrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE NOT i.indisvalid OR NOT i.indisready;

-- fix: either
--   DROP INDEX CONCURRENTLY <idx>;  then recreate
-- or
--   REINDEX INDEX CONCURRENTLY <idx>;
