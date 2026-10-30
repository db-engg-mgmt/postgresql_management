-- extensions.sql
-- Installed extensions and whether a newer version is available
-- (common after a minor upgrade or package update).

SELECT e.extname, e.extversion AS installed, a.default_version AS available,
       e.extversion <> a.default_version AS update_available,
       n.nspname AS schema
FROM pg_extension e
JOIN pg_available_extensions a ON a.name = e.extname
JOIN pg_namespace n ON n.oid = e.extnamespace
ORDER BY 1;

SHOW shared_preload_libraries;

-- update one:  ALTER EXTENSION pg_stat_statements UPDATE;
