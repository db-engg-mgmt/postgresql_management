#!/usr/bin/env bash
# pg_health_check.sh - runs the main diagnostic scripts against one database
# and writes everything to a timestamped report file. Handy to attach to a
# ticket or diff against last week's run.
#
#   ./bin/pg_health_check.sh -d appdb
#   ./bin/pg_health_check.sh -d appdb -h db01 -U dba -o /tmp/reports
#
# Read-only. Nothing in here changes data or settings.

set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
DB=postgres
OUTDIR=.
CONN=()

while getopts "d:h:p:U:o:" opt; do
  case $opt in
    d) DB=$OPTARG ;;
    h) CONN+=(-h "$OPTARG") ;;
    p) CONN+=(-p "$OPTARG") ;;
    U) CONN+=(-U "$OPTARG") ;;
    o) OUTDIR=$OPTARG ;;
    *) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
  esac
done

host=$(psql -XAt "${CONN[@]}" -d "$DB" -c "select coalesce(host(inet_server_addr()), 'local')") || exit 1
report="$OUTDIR/pg_health_${host//\//_}_${DB}_$(date +%Y%m%d_%H%M).txt"

scripts=(
  monitoring/db_overview.sql
  monitoring/connections.sql
  monitoring/activity.sql
  monitoring/long_running.sql
  monitoring/wait_events.sql
  locks/blocking_tree.sql
  vacuum/xid_wraparound.sql
  vacuum/xmin_horizon.sql
  vacuum/vacuum_queue.sql
  bloat/table_bloat_estimate.sql
  indexes/invalid_indexes.sql
  indexes/unused_indexes.sql
  indexes/duplicate_indexes.sql
  indexes/fk_without_index.sql
  performance/stale_stats.sql
  performance/table_access.sql
  replication/primary_status.sql
  replication/slots.sql
  replication/archiver.sql
  wal/checkpoints.sql
  admin/sequences.sql
  admin/settings.sql
  admin/extensions.sql
)

# pg_stat_statements is optional
if psql -XAt "${CONN[@]}" -d "$DB" -c "select 1 from pg_extension where extname='pg_stat_statements'" | grep -q 1; then
  scripts+=(performance/top_queries.sql)
fi

{
  echo "postgres health check: db=$DB host=$host run=$(date '+%F %T %Z') by=$(whoami)"
  for s in "${scripts[@]}"; do
    echo
    echo "################ $s"
    psql -X -P pager=off "${CONN[@]}" -d "$DB" -f "$HERE/$s" 2>&1
  done
} > "$report"

echo "written: $report"
grep -c ERROR "$report" | xargs -I{} echo "{} error lines (usually permissions - run as a pg_monitor member or superuser)"
