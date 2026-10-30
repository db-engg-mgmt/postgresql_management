-- standby_status.sql
-- Run on a STANDBY.

SELECT pg_is_in_recovery() AS in_recovery \gset
\if :in_recovery
\else
  \echo 'not a standby (pg_is_in_recovery = false). use replication/primary_status.sql'
  \quit
\endif

SELECT
    pg_is_in_recovery()                                   AS in_recovery,
    pg_last_wal_receive_lsn()                             AS received,
    pg_last_wal_replay_lsn()                              AS replayed,
    pg_size_pretty(pg_wal_lsn_diff(pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn())) AS replay_backlog,
    pg_last_xact_replay_timestamp()                       AS last_replayed_xact,
    CASE
        WHEN pg_last_wal_receive_lsn() = pg_last_wal_replay_lsn() THEN interval '0'
        ELSE date_trunc('second', now() - pg_last_xact_replay_timestamp())
    END                                                   AS replay_delay,
    pg_is_wal_replay_paused()                             AS replay_paused;
-- note: on a quiet primary last_replayed_xact gets old even with zero lag, hence the CASE.

-- wal receiver connection to upstream
SELECT
    pid, status, sender_host, sender_port, slot_name,
    received_tli,
    flushed_lsn,
    latest_end_lsn,
    date_trunc('second', now() - last_msg_receipt_time) AS since_last_msg
FROM pg_stat_wal_receiver;

-- queries cancelled because they conflicted with replay
SELECT datname, confl_tablespace, confl_lock, confl_snapshot, confl_bufferpin, confl_deadlock
FROM pg_stat_database_conflicts
WHERE datname NOT IN ('template0', 'template1');

SELECT name, setting
FROM pg_settings
WHERE name IN ('primary_conninfo', 'primary_slot_name', 'hot_standby', 'hot_standby_feedback',
               'max_standby_streaming_delay', 'max_standby_archive_delay',
               'recovery_min_apply_delay', 'restore_command');

-- pause/resume replay (e.g. to keep a consistent view for a long report):
--   SELECT pg_wal_replay_pause();   SELECT pg_wal_replay_resume();
