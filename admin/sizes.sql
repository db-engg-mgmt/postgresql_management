-- sizes.sql
-- Database, schema and table sizes.

\echo '--- databases'
SELECT datname, pg_size_pretty(pg_database_size(oid)) AS size
FROM pg_database
ORDER BY pg_database_size(oid) DESC;

\echo '--- schemas in current db'
SELECT n.nspname AS schema,
       pg_size_pretty(sum(pg_total_relation_size(c.oid))) AS total
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'm', 'p')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
GROUP BY n.nspname
ORDER BY sum(pg_total_relation_size(c.oid)) DESC;

\echo '--- top 30 tables (heap / toast / indexes)'
SELECT
    c.oid::regclass                                     AS tbl,
    c.reltuples::bigint                                 AS est_rows,
    pg_size_pretty(pg_total_relation_size(c.oid))       AS total,
    pg_size_pretty(pg_relation_size(c.oid))             AS heap,
    pg_size_pretty(pg_table_size(c.oid) - pg_relation_size(c.oid)) AS toast_fsm_vm,
    pg_size_pretty(pg_indexes_size(c.oid))              AS indexes
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'm')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(c.oid) DESC
LIMIT 30;

\echo '--- tablespaces'
SELECT spcname, pg_tablespace_location(oid) AS location,
       pg_size_pretty(pg_tablespace_size(oid)) AS size
FROM pg_tablespace;
