-- table_bloat_estimate.sql
-- Rough table bloat estimate from catalog stats only (no table scan, safe on prod).
--
-- How it works: for each table, sum avg_width from pg_stats, add the tuple header
-- (23 bytes + null bitmap, aligned to 8), work out how many tuples fit in a page
-- after fillfactor, and compare the expected page count with relpages.
--
-- It's an estimate. It drifts when stats are stale (ANALYZE first), on tables with
-- lots of TOAST, and on tiny tables. Use bloat/pgstattuple_check.sql when you need
-- a real number for one table before scheduling a repack.

WITH cfg AS (
    SELECT current_setting('block_size')::int AS bs,
           24  AS page_hdr,
           23  AS tup_hdr,
           4   AS item_ptr,
           8   AS maxalign
),
cols AS (
    SELECT
        c.oid,
        n.nspname,
        c.relname,
        c.reltuples,
        c.relpages,
        coalesce((SELECT substring(o FROM 'fillfactor=(\d+)')::int
                    FROM unnest(c.reloptions) o WHERE o LIKE 'fillfactor=%'), 100) AS ff,
        sum((1 - coalesce(s.null_frac, 0)) * coalesce(s.avg_width, 0)) AS data_width,
        max(coalesce(s.null_frac, 0)) > 0                              AS has_nulls,
        count(a.attnum)                                                AS ncols,
        count(s.attname)                                               AS ncols_with_stats
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
    LEFT JOIN pg_stats s ON s.schemaname = n.nspname AND s.tablename = c.relname AND s.attname = a.attname
    WHERE c.relkind = 'r'
      AND n.nspname NOT IN ('pg_catalog', 'information_schema')
      AND n.nspname NOT LIKE 'pg_toast%'
    GROUP BY c.oid, n.nspname, c.relname, c.reltuples, c.relpages, c.reloptions
),
est AS (
    SELECT
        cols.*,
        cfg.bs,
        -- header incl. null bitmap, rounded up to maxalign
        ceil((cfg.tup_hdr + CASE WHEN has_nulls THEN ceil(ncols / 8.0) ELSE 0 END)::numeric / cfg.maxalign) * cfg.maxalign
          + ceil(data_width / cfg.maxalign) * cfg.maxalign + cfg.item_ptr AS tuple_bytes,
        cfg.page_hdr
    FROM cols, cfg
    WHERE reltuples > 0
),
calc AS (
    SELECT
        *,
        greatest(1, floor((bs - page_hdr) * ff / 100.0 / tuple_bytes)) AS tuples_per_page
    FROM est
)
SELECT
    nspname || '.' || relname                               AS tbl,
    pg_size_pretty(relpages::bigint * bs)                   AS actual_size,
    pg_size_pretty(ceil(reltuples / tuples_per_page)::bigint * bs) AS expected_size,
    pg_size_pretty(greatest(relpages - ceil(reltuples / tuples_per_page), 0)::bigint * bs) AS est_bloat,
    round((100 * greatest(relpages - ceil(reltuples / tuples_per_page), 0) / nullif(relpages, 0))::numeric, 1) AS bloat_pct,
    ff AS fillfactor,
    CASE WHEN ncols_with_stats < ncols THEN 'missing stats, run ANALYZE' END AS note
FROM calc
WHERE relpages > 128          -- skip anything under ~1MB
ORDER BY greatest(relpages - ceil(reltuples / tuples_per_page), 0) DESC
LIMIT 30;
