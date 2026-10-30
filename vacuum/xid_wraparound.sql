-- xid_wraparound.sql
-- Transaction ID (and multixact) age. Once a database gets within ~3M of the
-- 2^31 limit it stops accepting writes, so this one goes on every monitoring
-- dashboard.
--
-- Rule of thumb I alert on:
--   > autovacuum_freeze_max_age (200M default)   anti-wraparound vacuums are kicking in, normal
--   > 1 billion                                  something is blocking freezing, go look
--   > 1.5 billion                                drop everything

SELECT
    datname,
    age(datfrozenxid)                                  AS xid_age,
    round(100.0 * age(datfrozenxid) / 2147483647, 2)   AS pct_to_wrap,
    mxid_age(datminmxid)                               AS mxid_age,
    current_setting('autovacuum_freeze_max_age')::bigint AS freeze_max_age
FROM pg_database
ORDER BY age(datfrozenxid) DESC;

-- oldest tables in the current database (includes toast)
SELECT
    c.oid::regclass                         AS tbl,
    c.relkind,
    age(c.relfrozenxid)                     AS xid_age,
    mxid_age(c.relminmxid)                  AS mxid_age,
    pg_size_pretty(pg_table_size(c.oid))    AS size,
    s.last_autovacuum,
    s.last_vacuum
FROM pg_class c
LEFT JOIN pg_stat_all_tables s ON s.relid = c.oid
WHERE c.relkind IN ('r', 'm', 't')
ORDER BY age(c.relfrozenxid) DESC
LIMIT 20;

-- if age keeps climbing, run vacuum/xmin_horizon.sql to see what's holding it back,
-- then:  VACUUM (FREEZE, VERBOSE) <table>;
