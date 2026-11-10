# PostgreSQL 18 vs 17: Key Features and Advantages

PostgreSQL 18 was released on 2025-09-25. This page summarizes what it adds or improves over PostgreSQL 17, and the upgrade changes to plan for.

Full details: [PostgreSQL 18 release notes](https://www.postgresql.org/docs/release/18/)

## Headline advantages

| Area | PostgreSQL 17 | PostgreSQL 18 |
|---|---|---|
| Storage I/O | Synchronous reads, one at a time | **Asynchronous I/O (AIO)** for sequential scans, bitmap heap scans and vacuum. The project reports up to 3x faster reads from storage. |
| Multicolumn B-tree indexes | Usually need a filter on the leading column | **Skip scan** uses the index even when leading columns aren't filtered |
| Major-version upgrades | Planner statistics lost; `ANALYZE` needed after `pg_upgrade` | **`pg_upgrade` keeps optimizer statistics**, so performance holds up right after cutover |
| UUID primary keys | `gen_random_uuid()` (v4, random order) | **`uuidv7()`**: timestamp-ordered UUIDs that index and cache much better |
| Generated columns | `STORED` only | **Virtual generated columns** (computed on read) are now the default |
| Authentication | Password, SCRAM, LDAP, GSSAPI, certs | Adds **OAuth 2.0** (through validator libraries) |

## Performance and optimizer

- **Asynchronous I/O subsystem**, controlled by `io_method` (`sync`, `worker`, `io_uring` on Linux), `io_combine_limit` and `io_max_combine_limit`.
- **B-tree skip scan** for multicolumn indexes with no condition on the leading columns.
- **`OR` clauses rewritten as arrays** (`= ANY(...)`) so more queries can use indexes.
- **Parallel GIN index builds**, for faster indexing of JSONB and full-text data.
- **`EXPLAIN ANALYZE` includes `BUFFERS` by default**.

## Upgrades and operations

- **`pg_upgrade` retains optimizer statistics** (extended statistics excepted; opt out with `--no-statistics`).
- **`pg_upgrade --swap`** swaps data directories instead of copying or linking, which is potentially the fastest mode.
- **`pg_upgrade --jobs`** runs pre-upgrade checks in parallel.
- **Data checksums are on by default** in `initdb`.

## Developer and SQL features

- **`uuidv7()`**, plus an explicit `uuidv4()` alias.
- **Virtual generated columns** are the default; use `STORED` for write-time computation.
- **`OLD` and `NEW` in `RETURNING`** for `INSERT`, `UPDATE`, `DELETE` and `MERGE`:
  ```sql
  UPDATE accounts SET balance = balance + 10 WHERE id = 1
  RETURNING old.balance AS old_balance, new.balance AS new_balance;
  ```
- **Temporal constraints**: `WITHOUT OVERLAPS` on `PRIMARY KEY` and `UNIQUE`, and `PERIOD` on foreign keys.
- **`NOT NULL` constraints** are stored in `pg_constraint`, can be added as `NOT VALID`, and can be marked `[NO] INHERIT`.
- **Text handling**: the `PG_UNICODE_FAST` builtin collation and `casefold()` for accurate case-insensitive matching.

## Security

- **OAuth authentication** (`oauth` method in `pg_hba.conf`, `oauth_validator_libraries`).
- **Wire protocol 3.2**, the first new protocol version since 7.4, with 256-bit cancel keys. libpq still defaults to 3.0.
- **MD5 passwords are deprecated**: `CREATE ROLE`/`ALTER ROLE` now warn about them. Move to SCRAM-SHA-256.
- New `pg_get_acl()` and `has_largeobject_privilege()` functions.

## Replication

- **Logical replication of generated columns** (`publish_generated_columns` publication option).
- **`idle_replication_slot_timeout`** automatically invalidates abandoned slots, which helps prevent WAL bloat.
- `CREATE SUBSCRIPTION` streaming now defaults to `parallel`.

## Vacuum and autovacuum

- **`autovacuum_worker_slots`** lets `autovacuum_max_workers` change without a restart.
- **`autovacuum_vacuum_max_threshold`** puts a fixed cap on the dead-tuple trigger for large tables.
- **Eager freezing** of all-visible pages during normal vacuums (`vacuum_max_eager_freeze_failure_rate`).
- `vacuum_truncate` server setting; `VACUUM (ONLY)` / `ANALYZE (ONLY)` for partitioned parents.

## Upgrade checklist (17 to 18 incompatibilities)

- [ ] **Checksums**: new clusters default to checksums on. For `pg_upgrade` from a non-checksum 17 cluster, create the 18 cluster with `initdb --no-data-checksums` (or enable checksums on 17 first).
- [ ] **MD5**: inventory roles that still use MD5 passwords and plan a migration to SCRAM.
- [ ] **VACUUM/ANALYZE** now process inheritance children by default; use `ONLY` for the old behavior.
- [ ] **Full-text search** now uses the cluster's default collation provider. On ICU or builtin-collation clusters, reindex full-text and `pg_trgm` indexes after `pg_upgrade`.
- [ ] **`COPY FROM` CSV** no longer treats `\.` as end-of-file.
- [ ] **Unlogged partitioned tables** are no longer allowed.
- [ ] **`AFTER` triggers** run as the role that was active when the event was queued.
- [ ] Re-test monitoring queries that use `pg_backend_memory_contexts` (`level` is now 1-based and the `parent` column was removed).
