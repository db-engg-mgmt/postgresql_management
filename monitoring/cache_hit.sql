-- cache_hit.sql
-- Buffer cache hit ratios, db level and per table/index.
-- Note this only counts shared_buffers hits. A "miss" may still come from the OS
-- page cache, so a low number here isn't automatically a disk problem.

SELECT
    sum(heap_blks_hit)  AS heap_hit,
    sum(heap_blks_read) AS heap_read,
    round(100.0 * sum(heap_blks_hit) / nullif(sum(heap_blks_hit) + sum(heap_blks_read), 0), 2) AS heap_hit_pct,
    round(100.0 * sum(idx_blks_hit) / nullif(sum(idx_blks_hit) + sum(idx_blks_read), 0), 2)   AS idx_hit_pct
FROM pg_statio_user_tables;

-- tables doing the most physical reads
SELECT
    schemaname || '.' || relname AS tbl,
    heap_blks_read,
    heap_blks_hit,
    round(100.0 * heap_blks_hit / nullif(heap_blks_hit + heap_blks_read, 0), 1) AS hit_pct,
    idx_blks_read,
    round(100.0 * idx_blks_hit / nullif(idx_blks_hit + idx_blks_read, 0), 1)    AS idx_hit_pct,
    toast_blks_read
FROM pg_statio_user_tables
ORDER BY heap_blks_read + coalesce(idx_blks_read, 0) DESC
LIMIT 20;

-- what is actually sitting in shared_buffers (needs: CREATE EXTENSION pg_buffercache)
-- SELECT c.relname,
--        pg_size_pretty(count(*) * current_setting('block_size')::int) AS buffered,
--        round(100.0 * count(*) / (SELECT setting::int FROM pg_settings WHERE name = 'shared_buffers'), 1) AS pct_of_sb
-- FROM pg_buffercache b
-- JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
-- WHERE b.reldatabase = (SELECT oid FROM pg_database WHERE datname = current_database())
-- GROUP BY c.relname
-- ORDER BY count(*) DESC
-- LIMIT 20;
