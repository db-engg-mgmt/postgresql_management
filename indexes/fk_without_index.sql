-- fk_without_index.sql
-- Foreign keys whose referencing columns have no index starting with them.
-- Every DELETE/UPDATE on the parent then seq scans the child, and holds
-- locks while doing it. Shows up as random slow deletes and lock waits.

SELECT
    c.conrelid::regclass                      AS child_table,
    c.conname                                 AS fk_name,
    c.confrelid::regclass                     AS parent_table,
    array_agg(a.attname ORDER BY x.n)         AS fk_columns,
    pg_size_pretty(pg_relation_size(c.conrelid)) AS child_size,
    format('CREATE INDEX CONCURRENTLY ON %s (%s);',
           c.conrelid::regclass,
           string_agg(quote_ident(a.attname), ', ' ORDER BY x.n)) AS suggested
FROM pg_constraint c
CROSS JOIN LATERAL unnest(c.conkey) WITH ORDINALITY AS x(attnum, n)
JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = x.attnum
WHERE c.contype = 'f'
  AND NOT EXISTS (
        SELECT 1
        FROM pg_index i
        WHERE i.indrelid = c.conrelid
          AND (i.indkey::int2[])[0:cardinality(c.conkey) - 1] @> c.conkey
          AND (i.indkey::int2[])[0:cardinality(c.conkey) - 1] <@ c.conkey
  )
GROUP BY c.conrelid, c.conname, c.confrelid
ORDER BY pg_relation_size(c.conrelid) DESC;
