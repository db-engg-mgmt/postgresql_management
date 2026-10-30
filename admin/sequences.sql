-- sequences.sql
-- Sequences (incl. identity / serial) approaching their max. An int4 serial
-- PK running out at 2.1 billion is a fun way to spend a weekend.

SELECT
    schemaname || '.' || sequencename      AS seq,
    data_type,
    last_value,
    max_value,
    round(100.0 * coalesce(last_value, 0) / max_value, 2) AS pct_used,
    increment_by
FROM pg_sequences
ORDER BY coalesce(last_value, 0)::numeric / max_value DESC
LIMIT 20;

-- integer columns fed by a bigint sequence (sequence won't stop you, the column will)
SELECT
    d.refobjid::regclass        AS tbl,
    a.attname                   AS col,
    format_type(a.atttypid, a.atttypmod) AS col_type,
    s.seqrelid::regclass        AS seq,
    ps.last_value
FROM pg_depend d
JOIN pg_sequence s  ON s.seqrelid = d.objid
JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
JOIN pg_sequences ps ON format('%I.%I', ps.schemaname, ps.sequencename)::regclass = s.seqrelid
WHERE d.classid = 'pg_class'::regclass
  AND d.deptype IN ('a', 'i')
  AND a.atttypid IN ('int2'::regtype, 'int4'::regtype)
ORDER BY ps.last_value DESC NULLS LAST;

-- migrating int -> bigint on a big table without a long lock is its own project:
-- add new bigint column, backfill in batches, swap in a short transaction.
