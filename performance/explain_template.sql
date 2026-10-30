-- explain_template.sql
-- How I capture a plan for a slow query so it can be compared later.
-- Paste the query where marked. BEGIN/ROLLBACK keeps DML from actually changing data.

\pset pager off
\timing on

SET track_io_timing = on;      -- superuser only; drop this line otherwise
SET work_mem = '64MB';         -- comment out unless you're testing work_mem specifically

BEGIN;
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS, WAL, FORMAT TEXT)
-- >>> query here <<<
SELECT 1;
ROLLBACK;

-- What to look at:
--  * estimated rows vs actual rows off by 10x+ -> stats problem (performance/stale_stats.sql)
--  * "Buffers: shared read=" large -> cold cache or too much data touched
--  * "Rows Removed by Filter" huge on a Seq Scan -> index candidate
--  * Sort Method: external merge / Hash Batches > 1 -> work_mem spill
--  * Nested Loop with high loops on the inner side -> bad estimate upstream
--
-- For a query you can't run (it's already slow in prod), auto_explain catches it:
--   LOAD 'auto_explain';
--   SET auto_explain.log_min_duration = '5s';
--   SET auto_explain.log_analyze = on;
--   SET auto_explain.log_buffers = on;
