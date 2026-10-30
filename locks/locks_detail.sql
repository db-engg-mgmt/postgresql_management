-- locks_detail.sql
-- Every non-trivial lock held or requested, with the relation name resolved.
-- granted = f rows are the ones waiting.
--
-- Optional filter on a table:  psql -X -v rel=public.orders -f locks/locks_detail.sql

\if :{?rel}
\else
  \set rel ''
\endif

SELECT
    l.pid,
    a.usename,
    l.locktype,
    CASE
        WHEN l.relation IS NOT NULL THEN l.relation::regclass::text
        WHEN l.locktype = 'transactionid' THEN 'xid ' || l.transactionid
        WHEN l.locktype = 'advisory' THEN 'advisory ' || l.classid || ':' || l.objid
        ELSE l.locktype
    END                                   AS target,
    l.mode,
    l.granted,
    l.fastpath,
    date_trunc('second', now() - l.waitstart) AS waiting_for,   -- PG14+
    a.state,
    left(regexp_replace(a.query, '\s+', ' ', 'g'), 80) AS query
FROM pg_locks l
LEFT JOIN pg_stat_activity a ON a.pid = l.pid
WHERE l.locktype NOT IN ('virtualxid')
  AND l.pid <> pg_backend_pid()
  AND (:'rel' = '' OR l.relation = to_regclass(:'rel'))
ORDER BY l.granted, l.waitstart NULLS LAST, l.pid;

-- lock counts by mode, quick look for something grabbing AccessExclusive
SELECT mode, granted, count(*)
FROM pg_locks
WHERE locktype = 'relation'
GROUP BY 1, 2
ORDER BY 1, 2;
