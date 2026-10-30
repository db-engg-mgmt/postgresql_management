-- activity.sql
-- What is every backend doing right now. First thing I run when someone says "the db is slow".
--
-- usage: psql -X -f monitoring/activity.sql
--        psql -X -v state=active -f monitoring/activity.sql   (filter by state)

\if :{?state}
\else
  \set state ''
\endif

SELECT
    pid,
    usename,
    datname,
    application_name                          AS app,
    client_addr,
    backend_type,
    state,
    wait_event_type || ':' || wait_event      AS waiting_on,
    date_trunc('second', now() - backend_start) AS conn_age,
    date_trunc('second', now() - xact_start)    AS xact_age,
    date_trunc('second', now() - query_start)   AS query_age,
    backend_xid,
    backend_xmin,
    left(regexp_replace(query, '\s+', ' ', 'g'), 120) AS query
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
  AND (:'state' = '' OR state = :'state')
ORDER BY
    CASE state WHEN 'active' THEN 1 WHEN 'idle in transaction' THEN 2 ELSE 3 END,
    xact_start NULLS LAST;

-- quick summary by state
SELECT coalesce(state, '<' || backend_type || '>') AS state, count(*)
FROM pg_stat_activity
GROUP BY 1
ORDER BY 2 DESC;
