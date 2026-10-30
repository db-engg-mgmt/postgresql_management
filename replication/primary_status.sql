-- primary_status.sql
-- Run on the PRIMARY. Each connected standby / wal receiver and how far behind it is.
--
-- write_lag  = WAL reached standby memory
-- flush_lag  = WAL fsynced on standby
-- replay_lag = WAL applied, i.e. visible to queries on standby
-- Lag times are NULL when the standby is fully caught up and idle - that's fine.

SELECT
    pid,
    application_name,
    client_addr,
    state,
    sync_state,
    sync_priority,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn))   AS not_sent,
    pg_size_pretty(pg_wal_lsn_diff(sent_lsn, flush_lsn))              AS not_flushed,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)) AS replay_behind,
    write_lag,
    flush_lag,
    replay_lag,
    date_trunc('second', now() - backend_start) AS connected_for,
    reply_time
FROM pg_stat_replication
ORDER BY application_name;

SELECT name, setting
FROM pg_settings
WHERE name IN ('synchronous_standby_names', 'synchronous_commit', 'wal_level',
               'max_wal_senders', 'max_replication_slots', 'wal_keep_size',
               'max_slot_wal_keep_size', 'hot_standby_feedback');

-- big "not_sent"     -> primary side: network or wal sender busy
-- big "not_flushed"  -> standby disk is slow
-- replay lag only    -> standby is replaying slowly or a query on the standby is
--                       holding up replay (see standby_status.sql, conflicts)
