#!/usr/bin/env bash
# basebackup.sh - physical backup with pg_basebackup, then verify it.
#
#   ./basebackup.sh -o /backup/base                 # local, connects as $PGUSER
#   ./basebackup.sh -o /backup/base -h primary01 -U replicator
#
# Uses tar format + compressed, streams WAL so the backup is self-consistent.
# PG15+ for --compress=server-zstd style options; falls back to gzip below 15.
#
# For real PITR setups use pgBackRest or Barman (incremental, parallel, retention,
# archive management). This is for ad hoc copies and for seeding replicas.

set -euo pipefail

OUT=/backup/base
HOST=""
USERNAME=""

while getopts "o:h:U:" opt; do
  case $opt in
    o) OUT=$OPTARG ;;
    h) HOST=$OPTARG ;;
    U) USERNAME=$OPTARG ;;
    *) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
  esac
done

CONN=()
[[ -n $HOST ]] && CONN+=(-h "$HOST")
[[ -n $USERNAME ]] && CONN+=(-U "$USERNAME")

ver=$(psql -XAt "${CONN[@]}" -d postgres -c "show server_version_num")
DEST="$OUT/base_$(date +%Y%m%d_%H%M)"
mkdir -p "$DEST"

if (( ver >= 150000 )); then
  COMP=(--compress=server-zstd:3)
else
  COMP=(-z)
fi

echo "$(date '+%F %T') starting backup to $DEST (server $ver)"
pg_basebackup "${CONN[@]}" -D "$DEST" -Ft "${COMP[@]}" -Xs -P -c fast \
  -l "basebackup $(hostname) $(date +%F)"

echo "$(date '+%F %T') verifying"
# pg_verifybackup reads tar format from PG18 on. On older versions extract the
# tars to a scratch dir and point it there, or take the backup with -Fp.
if (( ver >= 180000 )); then
  pg_verifybackup "$DEST" || { echo "VERIFY FAILED"; exit 2; }
else
  echo "skipping pg_verifybackup (tar format needs PG18 client tools)"
  [[ -s "$DEST/backup_manifest" ]] || { echo "no backup_manifest?"; exit 2; }
fi

du -sh "$DEST"
echo "$(date '+%F %T') done"

# seed a new replica instead (plain format + writes standby.signal / primary_conninfo):
#   pg_basebackup -h primary01 -U replicator -D /var/lib/pgsql/17/data -Fp -Xs -P -R -C -S replica2_slot
