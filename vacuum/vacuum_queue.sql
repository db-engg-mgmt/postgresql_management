-- vacuum_queue.sql
-- Which tables autovacuum *should* be picking up, using each table's own
-- thresholds (honours per-table reloptions overrides). Tables at the top with
-- an old last_autovacuum are being starved.

WITH s AS (
    SELECT
        current_setting('autovacuum_vacuum_threshold')::float         AS v_thresh,
        current_setting('autovacuum_vacuum_scale_factor')::float      AS v_scale,
        current_setting('autovacuum_analyze_threshold')::float        AS a_thresh,
        current_setting('autovacuum_analyze_scale_factor')::float     AS a_scale,
        current_setting('autovacuum_vacuum_insert_threshold')::float  AS i_thresh,
        current_setting('autovacuum_vacuum_insert_scale_factor')::float AS i_scale
),
opts AS (
    SELECT c.oid,
           (SELECT split_part(o, '=', 2)::float FROM unnest(c.reloptions) o WHERE o LIKE 'autovacuum_vacuum_threshold=%')    AS v_thresh,
           (SELECT split_part(o, '=', 2)::float FROM unnest(c.reloptions) o WHERE o LIKE 'autovacuum_vacuum_scale_factor=%') AS v_scale,
           (SELECT split_part(o, '=', 2)::float FROM unnest(c.reloptions) o WHERE o LIKE 'autovacuum_analyze_threshold=%')   AS a_thresh,
           (SELECT split_part(o, '=', 2)::float FROM unnest(c.reloptions) o WHERE o LIKE 'autovacuum_analyze_scale_factor=%') AS a_scale,
           (SELECT split_part(o, '=', 2)     FROM unnest(c.reloptions) o WHERE o LIKE 'autovacuum_enabled=%')               AS av_enabled
    FROM pg_class c
    WHERE c.relkind IN ('r', 'm')
)
SELECT
    t.schemaname || '.' || t.relname                     AS tbl,
    t.n_live_tup,
    t.n_dead_tup,
    round(coalesce(o.v_thresh, s.v_thresh) + coalesce(o.v_scale, s.v_scale) * c.reltuples) AS vac_trigger_at,
    t.n_dead_tup > coalesce(o.v_thresh, s.v_thresh) + coalesce(o.v_scale, s.v_scale) * c.reltuples AS needs_vacuum,
    t.n_mod_since_analyze > coalesce(o.a_thresh, s.a_thresh) + coalesce(o.a_scale, s.a_scale) * c.reltuples AS needs_analyze,
    t.n_ins_since_vacuum > s.i_thresh + s.i_scale * c.reltuples AS needs_insert_vacuum,
    o.av_enabled                                          AS autovac_enabled_opt,
    t.last_autovacuum,
    t.autovacuum_count
FROM pg_stat_user_tables t
JOIN pg_class c ON c.oid = t.relid
JOIN opts o     ON o.oid = t.relid
CROSS JOIN s
ORDER BY t.n_dead_tup DESC
LIMIT 30;

-- big hot tables usually want lower scale factors, e.g.
--   ALTER TABLE events SET (autovacuum_vacuum_scale_factor = 0.01, autovacuum_vacuum_cost_limit = 2000);
