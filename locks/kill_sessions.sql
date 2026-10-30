-- kill_sessions.sql
-- Templates for clearing sessions. These are commented out on purpose.
-- Run the SELECT first, look at what you're about to kill, then uncomment.
--
-- pg_cancel_backend   -> cancels current query, connection stays
-- pg_terminate_backend -> kills the connection (open txn rolls back)

-- 1. preview: idle in transaction longer than 10 minutes
SELECT pid, usename, application_name, client_addr,
       date_trunc('second', now() - state_change) AS idle_for,
       left(query, 80) AS last_query
FROM pg_stat_activity
WHERE state IN ('idle in transaction', 'idle in transaction (aborted)')
  AND now() - state_change > interval '10 minutes';

-- SELECT pg_terminate_backend(pid)
-- FROM pg_stat_activity
-- WHERE state IN ('idle in transaction', 'idle in transaction (aborted)')
--   AND now() - state_change > interval '10 minutes';

-- 2. cancel active queries over 30 minutes for a given user
-- SELECT pg_cancel_backend(pid)
-- FROM pg_stat_activity
-- WHERE state = 'active'
--   AND usename = 'report_user'
--   AND now() - query_start > interval '30 minutes';

-- 3. kill the root blocker(s) -- sessions that block others but aren't blocked themselves
-- SELECT pg_terminate_backend(b)
-- FROM (SELECT DISTINCT unnest(pg_blocking_pids(pid)) AS b FROM pg_stat_activity) x
-- WHERE cardinality(pg_blocking_pids(b)) = 0;

-- 4. kick everyone off a database (e.g. before DROP/rename). Also block new connects first:
-- ALTER DATABASE appdb ALLOW_CONNECTIONS false;
-- SELECT pg_terminate_backend(pid) FROM pg_stat_activity
-- WHERE datname = 'appdb' AND pid <> pg_backend_pid();
-- (PG13+: DROP DATABASE appdb WITH (FORCE); does this for you)

-- better long term: set timeouts so you don't need this file
--   ALTER ROLE app SET idle_in_transaction_session_timeout = '5min';
--   ALTER ROLE report_user SET statement_timeout = '30min';
--   PG17+: transaction_timeout
