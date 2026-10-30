-- settings.sql
-- Settings changed from default, where they came from, and anything waiting on a restart.

SELECT name, setting, unit, source, sourcefile, sourceline
FROM pg_settings
WHERE source NOT IN ('default', 'override', 'client')
ORDER BY name;

\echo '--- pending restart'
SELECT name, setting
FROM pg_settings
WHERE pending_restart;

\echo '--- errors in config files (typos, bad values)'
SELECT sourcefile, sourceline, name, setting, error
FROM pg_file_settings
WHERE error IS NOT NULL;

\echo '--- per role / per database overrides'
SELECT coalesce(r.rolname, '*') AS role, coalesce(d.datname, '*') AS db, s.setconfig
FROM pg_db_role_setting s
LEFT JOIN pg_roles r    ON r.oid = s.setrole
LEFT JOIN pg_database d ON d.oid = s.setdatabase;

\echo '--- memory related'
SELECT name, setting, unit, pg_size_pretty(
           CASE unit WHEN '8kB' THEN setting::bigint * 8192
                     WHEN 'kB'  THEN setting::bigint * 1024
                     WHEN 'MB'  THEN setting::bigint * 1024 * 1024 END) AS pretty
FROM pg_settings
WHERE name IN ('shared_buffers', 'effective_cache_size', 'work_mem', 'maintenance_work_mem',
               'autovacuum_work_mem', 'wal_buffers', 'temp_buffers', 'huge_pages');

-- reload after editing postgresql.conf:  SELECT pg_reload_conf();
