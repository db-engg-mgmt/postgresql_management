-- logical_replication.sql
-- Publications / subscriptions health. Run sections on the side they belong to.

\echo '=== publisher side'
SELECT pubname, puballtables, pubinsert, pubupdate, pubdelete, pubtruncate
FROM pg_publication;

SELECT pubname, schemaname || '.' || tablename AS tbl
FROM pg_publication_tables
ORDER BY 1, 2;

-- published tables with no PK / replica identity -> UPDATE/DELETE will error
SELECT p.pubname, c.oid::regclass AS tbl, c.relreplident
FROM pg_publication p
JOIN pg_publication_tables pt ON pt.pubname = p.pubname
JOIN pg_class c ON c.oid = format('%I.%I', pt.schemaname, pt.tablename)::regclass
WHERE c.relreplident = 'd'
  AND NOT EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = c.oid AND i.indisprimary);

\echo '=== subscriber side'
SELECT subname, subenabled, subconninfo IS NOT NULL AS has_conninfo, subslotname, subpublications
FROM pg_subscription;

SELECT
    subname,
    pid,
    relid::regclass                  AS syncing_table,   -- non null while initial copy runs
    received_lsn,
    latest_end_lsn,
    date_trunc('second', now() - last_msg_receipt_time) AS since_last_msg
FROM pg_stat_subscription;

-- per table sync state: i=init d=copying s=synced r=ready
SELECT srsubid, srrelid::regclass AS tbl, srsubstate
FROM pg_subscription_rel
WHERE srsubstate <> 'r';

-- apply errors (PG15+)
SELECT subname, apply_error_count, sync_error_count, stats_reset
FROM pg_stat_subscription_stats;

-- a conflict (dup key etc) stops apply. Check the subscriber log for the failing LSN, then
-- fix the row, or skip it:  ALTER SUBSCRIPTION s SKIP (lsn = '0/14C0378');  -- PG15+
