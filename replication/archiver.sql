-- archiver.sql
-- WAL archiving status. If archiving fails, WAL piles up in pg_wal and your
-- PITR window silently stops moving forward.

SELECT
    archived_count,
    last_archived_wal,
    last_archived_time,
    date_trunc('second', now() - last_archived_time) AS since_last_ok,
    failed_count,
    last_failed_wal,
    last_failed_time,
    last_failed_time > coalesce(last_archived_time, '-infinity') AS currently_failing,
    stats_reset
FROM pg_stat_archiver;

SELECT name, setting
FROM pg_settings
WHERE name IN ('archive_mode', 'archive_command', 'archive_library', 'archive_timeout', 'wal_level');

-- files waiting to be archived (superuser / pg_monitor)
SELECT count(*) AS ready_files
FROM pg_ls_archive_statusdir()
WHERE name LIKE '%.ready';

-- test the archive path end to end: SELECT pg_switch_wal(); then rerun this and check
-- last_archived_wal moved.
