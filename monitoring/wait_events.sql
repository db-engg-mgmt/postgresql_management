-- wait_events.sql
-- Poor man's ASH. Aggregates what active sessions are waiting on.
-- Run it with \watch 2 during an incident to see the pattern shift:
--
--   psql -X
--   \i monitoring/wait_events.sql
--   \watch 2
--
-- Rough guide:
--   IO:DataFileRead          -> reading from disk, check cache hit / missing index
--   Lock:relation / tuple    -> lock contention, run locks/blocking_tree.sql
--   LWLock:WALWrite / WALInsert -> WAL bottleneck, check storage latency
--   LWLock:BufferMapping     -> shared_buffers churn
--   LWLock:LockManager       -> too many partitions/indexes touched per query (fast-path exhausted)
--   Client:ClientRead        -> idle in transaction, app is holding the txn open
--   NULL wait                -> on CPU

SELECT
    coalesce(wait_event_type, 'CPU') AS wait_type,
    coalesce(wait_event, '-')        AS wait_event,
    count(*)                         AS sessions,
    string_agg(pid::text, ',' ORDER BY pid) AS pids
FROM pg_stat_activity
WHERE state IN ('active', 'idle in transaction')
  AND backend_type = 'client backend'
  AND pid <> pg_backend_pid()
GROUP BY 1, 2
ORDER BY sessions DESC;
