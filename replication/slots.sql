-- slots.sql
-- Replication slots and how much WAL each one is pinning.
-- An inactive slot nobody is consuming will happily fill pg_wal until the disk is full.
-- Set max_slot_wal_keep_size (PG13+) so a dead consumer can't take the primary down.

SELECT
    slot_name,
    slot_type,
    plugin,
    database,
    active,
    active_pid,
    temporary,
    wal_status,                        -- reserved / extended / unreserved / lost
    pg_size_pretty(safe_wal_size)      AS safe_wal_left,
    pg_size_pretty(
        pg_wal_lsn_diff(
            CASE WHEN pg_is_in_recovery() THEN pg_last_wal_receive_lsn() ELSE pg_current_wal_lsn() END,
            restart_lsn))              AS wal_retained,
    restart_lsn,
    confirmed_flush_lsn
FROM pg_replication_slots
ORDER BY pg_wal_lsn_diff(
            CASE WHEN pg_is_in_recovery() THEN pg_last_wal_receive_lsn() ELSE pg_current_wal_lsn() END,
            restart_lsn) DESC NULLS LAST;

-- total size of pg_wal right now (needs superuser or pg_monitor)
SELECT count(*) AS wal_files, pg_size_pretty(sum(size)) AS pg_wal_size
FROM pg_ls_waldir();

-- drop a slot that is truly abandoned (confirm with whoever owns the consumer!):
--   SELECT pg_drop_replication_slot('slot_name');
