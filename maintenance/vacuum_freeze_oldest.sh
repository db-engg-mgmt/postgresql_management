#!/usr/bin/env bash
# vacuum_freeze_oldest.sh - VACUUM FREEZE the N tables with the oldest relfrozenxid.
# Meant to run from cron on a quiet night so anti-wraparound autovacuums don't
# all land at once during business hours.
#
#   ./vacuum_freeze_oldest.sh -d appdb -n 10
#   ./vacuum_freeze_oldest.sh -d appdb -n 5 -a 150000000   # only tables older than 150M xids
#
# cron example:
#   30 1 * * 0  /opt/dba/postgresql_management/maintenance/vacuum_freeze_oldest.sh -d appdb -n 20 >> /var/log/pg_freeze.log 2>&1

set -euo pipefail

DB=""
N=10
MIN_AGE=100000000

while getopts "d:n:a:h" opt; do
  case $opt in
    d) DB=$OPTARG ;;
    n) N=$OPTARG ;;
    a) MIN_AGE=$OPTARG ;;
    *) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
  esac
done
[[ -z $DB ]] && { echo "need -d dbname"; exit 1; }

PSQL=(psql -X -q -v ON_ERROR_STOP=1 -d "$DB")

tables=$("${PSQL[@]}" -At <<SQL
SELECT format('%I.%I', n.nspname, c.relname)
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'm')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND age(c.relfrozenxid) > $MIN_AGE
ORDER BY age(c.relfrozenxid) DESC
LIMIT $N;
SQL
)

[[ -z $tables ]] && { echo "$(date '+%F %T') nothing older than $MIN_AGE"; exit 0; }

for t in $tables; do
  before=$("${PSQL[@]}" -At -c "SELECT age(relfrozenxid) FROM pg_class WHERE oid = '$t'::regclass")
  start=$(date +%s)
  "${PSQL[@]}" -c "VACUUM (FREEZE, ANALYZE) $t;"
  after=$("${PSQL[@]}" -At -c "SELECT age(relfrozenxid) FROM pg_class WHERE oid = '$t'::regclass")
  echo "$(date '+%F %T') $t age $before -> $after in $(( $(date +%s) - start ))s"
done
