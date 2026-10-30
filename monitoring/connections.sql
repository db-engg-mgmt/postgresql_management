-- connections.sql
-- Connection headroom and who is using the slots.

SELECT
    current_setting('max_connections')::int                 AS max_conn,
    current_setting('superuser_reserved_connections')::int  AS su_reserved,
    count(*) FILTER (WHERE backend_type = 'client backend') AS client_conns,
    count(*)                                                AS all_backends,
    round(100.0 * count(*) FILTER (WHERE backend_type = 'client backend')
          / current_setting('max_connections')::int, 1)     AS pct_used
FROM pg_stat_activity;

-- by user / db / state
SELECT usename, datname, state, count(*) AS conns
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY 1, 2, 3
ORDER BY conns DESC;

-- by client host - handy for spotting a runaway app server or a pool that isn't pooling
SELECT client_addr, application_name, count(*) AS conns,
       count(*) FILTER (WHERE state = 'idle') AS idle
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY 1, 2
ORDER BY conns DESC
LIMIT 25;

-- per-role limits that are set
SELECT rolname, rolconnlimit
FROM pg_roles
WHERE rolconnlimit <> -1;
