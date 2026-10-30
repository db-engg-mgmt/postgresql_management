-- table_privileges.sql
-- Who can do what on tables in a schema, plus default privileges.
--   psql -X -v schema=app -f security/table_privileges.sql

\if :{?schema}
\else
  \set schema public
\endif

SELECT grantee, table_name,
       string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privs
FROM information_schema.role_table_grants
WHERE table_schema = :'schema'
  AND grantee <> (SELECT tableowner FROM pg_tables WHERE schemaname = :'schema' AND tablename = table_name)
GROUP BY grantee, table_name
ORDER BY grantee, table_name;

-- default privileges (what new objects will get)
SELECT pg_get_userbyid(d.defaclrole) AS for_objects_created_by,
       n.nspname AS in_schema,
       CASE d.defaclobjtype WHEN 'r' THEN 'tables' WHEN 'S' THEN 'sequences'
                            WHEN 'f' THEN 'functions' WHEN 'T' THEN 'types' WHEN 'n' THEN 'schemas' END AS obj,
       d.defaclacl
FROM pg_default_acl d
LEFT JOIN pg_namespace n ON n.oid = d.defaclnamespace;

-- tables with row level security on
SELECT oid::regclass, relrowsecurity, relforcerowsecurity
FROM pg_class
WHERE relrowsecurity;

-- typical read only role:
--   CREATE ROLE app_ro NOLOGIN;
--   GRANT USAGE ON SCHEMA app TO app_ro;
--   GRANT SELECT ON ALL TABLES IN SCHEMA app TO app_ro;
--   ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA app GRANT SELECT ON TABLES TO app_ro;
--   (PG14+: or just GRANT pg_read_all_data)
