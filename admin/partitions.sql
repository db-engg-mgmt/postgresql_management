-- partitions.sql
-- Partitioned tables, partition counts, sizes and bounds.
--   psql -X -v parent=public.events -f admin/partitions.sql   (detail for one parent)

\if :{?parent}
\else
  \set parent ''
\endif

SELECT
    p.oid::regclass                         AS parent,
    pt.partstrat                            AS strategy,   -- r=range l=list h=hash
    pg_get_partkeydef(p.oid)                AS part_key,
    count(*)                                AS partitions,
    pg_size_pretty(sum(pg_total_relation_size(i.relid))) AS total_size
FROM pg_class p
JOIN pg_partitioned_table pt ON pt.partrelid = p.oid
CROSS JOIN LATERAL pg_partition_tree(p.oid) i
WHERE i.isleaf
  AND p.relispartition = false
GROUP BY p.oid, pt.partstrat
ORDER BY sum(pg_total_relation_size(i.relid)) DESC;

SELECT
    i.relid::regclass                       AS partition,
    i.level,
    pg_get_expr(c.relpartbound, c.oid)      AS bound,
    pg_size_pretty(pg_total_relation_size(i.relid)) AS size,
    c.reltuples::bigint                     AS est_rows
FROM pg_partition_tree(nullif(:'parent', '')::regclass) i
JOIN pg_class c ON c.oid = i.relid
WHERE :'parent' <> ''
ORDER BY i.level, c.relname;

-- watch for rows landing in a DEFAULT partition - usually means the job that
-- creates future partitions stopped running.
SELECT c.oid::regclass AS default_partition, c.reltuples::bigint AS est_rows
FROM pg_class c
WHERE c.relispartition
  AND pg_get_expr(c.relpartbound, c.oid) = 'DEFAULT';
