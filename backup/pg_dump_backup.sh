#!/usr/bin/env bash
# pg_dump_backup.sh - nightly logical backup of every database + globals,
# directory format with parallel jobs, keeps N days.
#
#   ./pg_dump_backup.sh -o /backup/pg -j 4 -k 7
#
# Connection comes from the usual env vars / ~/.pgpass (PGHOST, PGPORT, PGUSER).
# Logical backups are not a replacement for base backups + WAL archiving
# if you need point in time recovery.

set -uo pipefail

OUT=/backup/pg
JOBS=2
KEEP=7

while getopts "o:j:k:h" opt; do
  case $opt in
    o) OUT=$OPTARG ;;
    j) JOBS=$OPTARG ;;
    k) KEEP=$OPTARG ;;
    *) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
  esac
done

STAMP=$(date +%Y%m%d_%H%M)
DEST="$OUT/$STAMP"
mkdir -p "$DEST"
LOG="$DEST/backup.log"
rc=0

log() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }

log "globals"
pg_dumpall --globals-only -f "$DEST/globals.sql" 2>>"$LOG" || { log "FAILED globals"; rc=1; }

for db in $(psql -XAtc "SELECT datname FROM pg_database WHERE datallowconn AND datname <> 'template1' ORDER BY 1"); do
  log "dumping $db"
  if pg_dump -Fd -j "$JOBS" -Z 5 -f "$DEST/$db.dir" "$db" 2>>"$LOG"; then
    # sanity: the TOC must be readable
    pg_restore -l "$DEST/$db.dir" > /dev/null 2>>"$LOG" || { log "FAILED toc check $db"; rc=1; }
    log "ok $db $(du -sh "$DEST/$db.dir" | cut -f1)"
  else
    log "FAILED $db"
    rc=1
  fi
done

log "removing backups older than $KEEP days"
find "$OUT" -mindepth 1 -maxdepth 1 -type d -mtime +"$KEEP" -exec rm -rf {} +

[[ $rc -ne 0 ]] && log "finished WITH ERRORS" || log "finished"
exit $rc

# restore one db:
#   createdb -T template0 appdb_restore
#   pg_restore -j 4 -d appdb_restore /backup/pg/20261028_0100/appdb.dir
# restore one table:
#   pg_restore -d appdb_restore -t orders /backup/pg/20261028_0100/appdb.dir
