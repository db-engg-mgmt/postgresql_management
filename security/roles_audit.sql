-- roles_audit.sql
-- Quick security review: superusers, login roles without password expiry,
-- role memberships, and who can connect / create in public.

\echo '--- roles with elevated attributes'
SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolreplication, rolbypassrls,
       rolcanlogin, rolvaliduntil, rolconnlimit
FROM pg_roles
WHERE rolname !~ '^pg_'
ORDER BY rolsuper DESC, rolcreaterole DESC, rolname;

\echo '--- password hash type (anything not SCRAM is md5 or plain)'
SELECT rolname,
       CASE WHEN rolpassword IS NULL THEN 'no password'
            WHEN rolpassword LIKE 'SCRAM-SHA-256$%' THEN 'scram'
            WHEN rolpassword LIKE 'md5%' THEN 'md5'
            ELSE 'other' END AS pw_type
FROM pg_authid
WHERE rolcanlogin
ORDER BY 2, 1;

\echo '--- role membership'
SELECT m.rolname AS member, r.rolname AS member_of, g.rolname AS granted_by, am.admin_option
FROM pg_auth_members am
JOIN pg_roles r ON r.oid = am.roleid
JOIN pg_roles m ON m.oid = am.member
LEFT JOIN pg_roles g ON g.oid = am.grantor
WHERE m.rolname !~ '^pg_'
ORDER BY 1, 2;

\echo '--- CREATE on public schema (default before PG15)'
SELECT has_schema_privilege('public', 'public', 'CREATE') AS public_can_create;

\echo '--- SECURITY DEFINER functions not owned by a superuser-ish role, without search_path set'
SELECT p.oid::regprocedure AS func, pg_get_userbyid(p.proowner) AS owner, p.proconfig
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.prosecdef
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND (p.proconfig IS NULL OR NOT EXISTS (SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%'));

\echo '--- hba rules in effect (PG10+)'
SELECT line_number, type, database, user_name, address, netmask, auth_method, error
FROM pg_hba_file_rules
ORDER BY line_number;
