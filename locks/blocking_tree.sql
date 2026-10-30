-- blocking_tree.sql
-- Who is blocking whom, shown as a tree from the root blocker down.
-- The root blocker (depth 0) is usually the one to deal with -- killing
-- the sessions underneath it does nothing.

WITH RECURSIVE
blocked AS (
    SELECT pid, unnest(pg_blocking_pids(pid)) AS blocker
    FROM pg_stat_activity
    WHERE cardinality(pg_blocking_pids(pid)) > 0
),
roots AS (
    SELECT DISTINCT b.blocker AS pid
    FROM blocked b
    WHERE NOT EXISTS (SELECT 1 FROM blocked x WHERE x.pid = b.blocker)
),
tree AS (
    SELECT r.pid, NULL::int AS blocked_by, 0 AS depth, ARRAY[r.pid] AS path
    FROM roots r
    UNION ALL
    SELECT b.pid, b.blocker, t.depth + 1, t.path || b.pid
    FROM blocked b
    JOIN tree t ON b.blocker = t.pid
    WHERE NOT b.pid = ANY(t.path)          -- guard against cycles (deadlock detector will catch these anyway)
)
SELECT
    repeat('  ', t.depth) || t.pid       AS pid_tree,
    t.blocked_by,
    a.usename,
    a.datname,
    a.state,
    a.wait_event_type || ':' || a.wait_event AS waiting_on,
    date_trunc('second', now() - a.xact_start)  AS xact_age,
    date_trunc('second', now() - a.state_change) AS in_state_for,
    left(regexp_replace(a.query, '\s+', ' ', 'g'), 100) AS query
FROM tree t
JOIN pg_stat_activity a ON a.pid = t.pid
ORDER BY t.path;

-- count of sessions stuck behind each root
WITH b AS (
    SELECT unnest(pg_blocking_pids(pid)) AS blocker FROM pg_stat_activity
)
SELECT blocker, count(*) AS directly_blocking
FROM b
GROUP BY blocker
ORDER BY 2 DESC;
