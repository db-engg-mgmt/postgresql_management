-- ddl_lock_queue.sql
-- The classic outage: an ALTER TABLE waits for AccessExclusiveLock behind one
-- long SELECT, and then every new query on that table queues behind the ALTER.
-- This shows sessions waiting on relation locks and what they are queued behind.
--
-- Prevention for migrations:
--   SET lock_timeout = '3s';
--   ALTER TABLE ...;      -- retry in a loop instead of waiting forever

SELECT
    w.pid                              AS waiting_pid,
    w.relation::regclass               AS rel,
    w.mode                             AS wants,
    date_trunc('second', now() - w.waitstart) AS waited,
    left(regexp_replace(wa.query, '\s+', ' ', 'g'), 70) AS waiting_query,
    pg_blocking_pids(w.pid)            AS blocked_by,
    (SELECT string_agg(DISTINCT h.mode, ', ')
       FROM pg_locks h
      WHERE h.relation = w.relation AND h.granted
        AND h.pid = ANY(pg_blocking_pids(w.pid))) AS held_modes
FROM pg_locks w
JOIN pg_stat_activity wa ON wa.pid = w.pid
WHERE NOT w.granted
  AND w.locktype = 'relation'
ORDER BY w.waitstart;
