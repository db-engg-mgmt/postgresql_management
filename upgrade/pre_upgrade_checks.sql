-- pre_upgrade_checks.sql
-- Things that break or slow down a major version upgrade (pg_upgrade or dump/restore).
-- Run in EVERY database on the old cluster:
--   for db in $(psql -XAtc "select datname from pg_database where datallowconn"); do
--     echo "== $db"; psql -X -d "$db" -f upgrade/pre_upgrade_checks.sql
--   done

SELECT version();

\echo '--- extensions (each must be installed for the NEW version before pg_upgrade)'
SELECT extname, extversion FROM pg_extension ORDER BY 1;

\echo '--- prepared transactions (pg_upgrade refuses to run with these)'
SELECT gid, prepared, owner, database FROM pg_prepared_xacts;

\echo '--- logical replication slots (only carried over by pg_upgrade from PG17+ old clusters)'
SELECT slot_name, slot_type, plugin, active FROM pg_replication_slots;

\echo '--- reg* data types in user tables (pg_upgrade cannot handle most of them)'
SELECT c.oid::regclass AS tbl, a.attname, a.atttypid::regtype
FROM pg_attribute a
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE a.atttypid IN ('regproc'::regtype, 'regprocedure'::regtype, 'regoper'::regtype,
                     'regoperator'::regtype, 'regconfig'::regtype, 'regdictionary'::regtype,
                     'regnamespace'::regtype, 'regcollation'::regtype)
  AND a.attnum > 0 AND NOT a.attisdropped
  AND n.nspname NOT IN ('pg_catalog', 'information_schema');

SELECT current_setting('server_version_num')::int < 120000 AS pre12 \gset
\if :pre12
\echo '--- tables WITH OIDS (gone since PG12, must be altered WITHOUT OIDS first)'
SELECT oid::regclass FROM pg_class WHERE relkind = 'r' AND relhasoids;
\endif

\echo '--- sql_identifier / unknown / abstime style columns'
SELECT c.oid::regclass AS tbl, a.attname, format_type(a.atttypid, a.atttypmod) AS type
FROM pg_attribute a
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE format_type(a.atttypid, a.atttypmod) IN ('unknown', 'abstime', 'reltime', 'tinterval', 'information_schema.sql_identifier')
  AND c.relkind IN ('r', 'm')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema');

\echo '--- user defined postfix operators (removed in PG14)'
SELECT oid::regoperator FROM pg_operator WHERE oprright = 0 AND oid >= 16384;

\echo '--- objects depending on removed/changed catalog functions are best found with a schema-only restore test:'
\echo '    pg_dump -s olddb | psql newcluster_testdb   and read the errors'

\echo '--- largest tables (rough idea of dump/restore time, and of --link vs copy)'
SELECT c.oid::regclass, pg_size_pretty(pg_total_relation_size(c.oid))
FROM pg_class c
WHERE c.relkind = 'r'
ORDER BY pg_total_relation_size(c.oid) DESC
LIMIT 10;

\echo '--- large objects (dump/restore of many LOs is painfully slow)'
SELECT count(*) AS large_objects FROM pg_largeobject_metadata;

\echo '--- non default collation provider / version (re-index text indexes if glibc changes)'
SELECT datname, datcollate, datctype, datlocprovider, datcollversion
FROM pg_database;
