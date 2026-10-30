-- long_running.sql
-- Queries and transactions running longer than a threshold (default 5 min).
--   psql -X -v mins=15 -f monitoring/long_running.sql
--
-- Long *transactions* matter as much as long queries: they pin xmin and stop
-- vacuum from cleaning anything newer than them.

\if :{?mins}
\else
  \set mins 5
\endif

\echo '--- long running queries'
SELECT
    pid,
    usename,
    datname,
    state,
    wait_event_type || ':' || wait_event AS waiting_on,
    date_trunc('second', now() - query_start) AS running_for,
    left(regexp_replace(query, '\s+', ' ', 'g'), 200) AS query
FROM pg_stat_activity
WHERE state = 'active'
  AND backend_type = 'client backend'
  AND now() - query_start > make_interval(mins => :mins)
  AND pid <> pg_backend_pid()
ORDER BY query_start;

\echo '--- long open transactions (any state)'
SELECT
    pid,
    usename,
    datname,
    state,
    date_trunc('second', now() - xact_start)   AS xact_open_for,
    date_trunc('second', now() - state_change) AS in_state_for,
    backend_xmin,
    left(regexp_replace(query, '\s+', ' ', 'g'), 120) AS last_query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
  AND now() - xact_start > make_interval(mins => :mins)
  AND pid <> pg_backend_pid()
ORDER BY xact_start;

-- to cancel just the query:      SELECT pg_cancel_backend(<pid>);
-- to drop the whole connection:  SELECT pg_terminate_backend(<pid>);
