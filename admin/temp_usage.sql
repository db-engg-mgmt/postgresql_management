-- temp_usage.sql
-- Temp file usage. Queries spilling sorts/hashes to disk show up here.
-- Turn on log_temp_files = '10MB' to get the offending statement in the log.

SELECT datname, temp_files, pg_size_pretty(temp_bytes) AS temp_bytes, stats_reset
FROM pg_stat_database
WHERE temp_files > 0
ORDER BY temp_bytes DESC;

-- temp files on disk right now (superuser / pg_monitor)
SELECT name, pg_size_pretty(size) AS size, modification
FROM pg_ls_tmpdir()
ORDER BY size DESC
LIMIT 20;

SHOW work_mem;
SHOW hash_mem_multiplier;
SHOW temp_file_limit;
