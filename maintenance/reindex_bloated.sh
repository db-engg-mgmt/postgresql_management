#!/usr/bin/env bash
# reindex_bloated.sh - REINDEX CONCURRENTLY btree indexes whose leaf density
# has dropped below a threshold. Uses pgstattuple, so it reads every candidate
# index; keep the size filter sane and run it in a quiet window.
#
#   ./reindex_bloated.sh -d appdb               # dry run, prints what it would do
#   ./reindex_bloated.sh -d appdb -x            # actually reindex
#   ./reindex_bloated.sh -d appdb -m 500 -t 60  # indexes > 500MB, density < 60%
#
# Needs PG12+ (REINDEX CONCURRENTLY) and the pgstattuple extension in the db.

set -euo pipefail

DB=""
MIN_MB=100
THRESH=65
EXECUTE=0

while getopts "d:m:t:xh" opt; do
  case $opt in
    d) DB=$OPTARG ;;
    m) MIN_MB=$OPTARG ;;
    t) THRESH=$OPTARG ;;
    x) EXECUTE=1 ;;
    *) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
  esac
done

[[ -z $DB ]] && { echo "need -d dbname"; exit 1; }

PSQL=(psql -X -q -v ON_ERROR_STOP=1 -d "$DB")

"${PSQL[@]}" -c "SET client_min_messages = warning; CREATE EXTENSION IF NOT EXISTS pgstattuple" >/dev/null

candidates=$("${PSQL[@]}" -At -F $'\t' <<SQL
SELECT i.indexrelid::regclass, pg_relation_size(i.indexrelid) / 1048576, round(s.avg_leaf_density::numeric, 1)
FROM pg_index i
JOIN pg_class c ON c.oid = i.indexrelid
JOIN pg_am am   ON am.oid = c.relam AND am.amname = 'btree'
JOIN pg_namespace n ON n.oid = c.relnamespace
CROSS JOIN LATERAL pgstatindex(i.indexrelid) s
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
  AND i.indisvalid
  AND pg_relation_size(i.indexrelid) > ${MIN_MB}::bigint * 1048576
  AND s.avg_leaf_density < ${THRESH}
ORDER BY pg_relation_size(i.indexrelid) DESC;
SQL
)

if [[ -z $candidates ]]; then
  echo "nothing under ${THRESH}% leaf density above ${MIN_MB}MB"
  exit 0
fi

printf "%-60s %10s %8s\n" index size_mb density
while IFS=$'\t' read -r idx mb dens; do
  printf "%-60s %10s %8s\n" "$idx" "$mb" "$dens"
done <<< "$candidates"

if [[ $EXECUTE -eq 0 ]]; then
  echo
  echo "dry run. add -x to reindex."
  exit 0
fi

while IFS=$'\t' read -r idx mb dens; do
  echo "$(date '+%F %T') reindexing $idx (${mb}MB, ${dens}%)"
  # lock_timeout so we don't end up queuing behind something and blocking the app
  "${PSQL[@]}" -c "SET lock_timeout = '5s'; REINDEX INDEX CONCURRENTLY $idx;" \
    || echo "  failed on $idx - check for an invalid *_ccnew index left behind (indexes/invalid_indexes.sql)"
  echo "$(date '+%F %T') done $idx, now $("${PSQL[@]}" -At -c "SELECT pg_size_pretty(pg_relation_size('$idx'::regclass))")"
done <<< "$candidates"
