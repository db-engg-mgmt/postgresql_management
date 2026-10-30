-- duplicate_indexes.sql
-- 1) exact duplicates: same table, same columns, same expression/predicate
-- 2) left-prefix overlaps: idx(a) is redundant if idx(a,b) exists (same type, no predicate)
-- Review case 2 by hand - a narrow index can still be faster for some lookups.

\echo '--- exact duplicates'
SELECT
    indrelid::regclass                        AS tbl,
    array_agg(indexrelid::regclass)           AS indexes,
    pg_size_pretty(sum(pg_relation_size(indexrelid))) AS combined_size
FROM pg_index
GROUP BY indrelid, indkey::text, indclass::text, coalesce(indexprs::text, ''), coalesce(indpred::text, '')
HAVING count(*) > 1;

\echo '--- left prefix overlaps'
SELECT
    a.indrelid::regclass                 AS tbl,
    a.indexrelid::regclass               AS redundant_idx,
    pg_size_pretty(pg_relation_size(a.indexrelid)) AS size,
    b.indexrelid::regclass               AS covered_by,
    pg_get_indexdef(a.indexrelid)        AS redundant_def,
    pg_get_indexdef(b.indexrelid)        AS covering_def
FROM pg_index a
JOIN pg_index b
  ON a.indrelid = b.indrelid
 AND a.indexrelid <> b.indexrelid
 AND a.indnatts < b.indnatts
 AND (b.indkey::int2[])[0:a.indnatts - 1] = (a.indkey::int2[])[0:a.indnatts - 1]
 AND (b.indclass::oid[])[0:a.indnatts - 1] = (a.indclass::oid[])[0:a.indnatts - 1]   -- slice both sides, int2vector is 0-based
WHERE a.indexprs IS NULL AND a.indpred IS NULL
  AND b.indexprs IS NULL AND b.indpred IS NULL
  AND NOT a.indisunique
  AND NOT a.indisprimary
ORDER BY pg_relation_size(a.indexrelid) DESC;
