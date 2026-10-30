-- xmin_horizon.sql
-- "Vacuum is running but dead tuples aren't going away."
-- Something is holding back the xmin horizon. There are four usual suspects;
-- this checks all of them and shows the age of each.

\echo '--- 1. long running / idle-in-transaction sessions'
SELECT pid, usename, datname, state, backend_xmin,
       age(backend_xmin) AS xmin_age,
       date_trunc('second', now() - xact_start) AS xact_age,
       left(query, 60) AS query
FROM pg_stat_activity
WHERE backend_xmin IS NOT NULL
ORDER BY age(backend_xmin) DESC
LIMIT 5;

\echo '--- 2. replication slots (physical slot xmin = hot_standby_feedback from a replica)'
SELECT slot_name, slot_type, active, database,
       xmin, age(xmin) AS xmin_age,
       catalog_xmin, age(catalog_xmin) AS catalog_xmin_age
FROM pg_replication_slots
WHERE xmin IS NOT NULL OR catalog_xmin IS NOT NULL
ORDER BY greatest(age(xmin), age(catalog_xmin)) DESC;

\echo '--- 3. forgotten prepared transactions'
SELECT gid, prepared, owner, database, transaction,
       age(transaction) AS xid_age
FROM pg_prepared_xacts
ORDER BY prepared;

\echo '--- 4. standbys reporting feedback'
SELECT application_name, client_addr, backend_xmin, age(backend_xmin) AS xmin_age
FROM pg_stat_replication
WHERE backend_xmin IS NOT NULL;

-- fixes, in order:
--   1. pg_terminate_backend(pid), then set idle_in_transaction_session_timeout
--   2. drop/advance unused slots (SELECT pg_drop_replication_slot('x')), or kill the
--      long query on the replica that's feeding back an old xmin
--   3. COMMIT PREPARED 'gid' / ROLLBACK PREPARED 'gid' -- check with the app owner first
