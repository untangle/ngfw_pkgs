#! /bin/bash

set -eux

## variables
VERSION_OLD=$1
VERSION_NEW=$2

case "$VERSION_OLD:$VERSION_NEW" in
  *[!0-9.:]*|:*)
    echo "Usage: $0 OLD_MAJOR NEW_MAJOR" >&2
    exit 2
    ;;
esac

SCRIPT_NAME=$(basename $0)

PG_VAR_DIR_OLD="/var/lib/postgresql/${VERSION_OLD}/main"
PG_BIN_DIR_OLD="/usr/lib/postgresql/${VERSION_OLD}/bin"
PG_CONF_OLD="/etc/postgresql/${VERSION_OLD}/main/postgresql.conf"

PG_VAR_DIR_NEW="/var/lib/postgresql/${VERSION_NEW}/main"
PG_BIN_DIR_NEW="/usr/lib/postgresql/${VERSION_NEW}/bin"
PG_CONF_NEW="/etc/postgresql/${VERSION_NEW}/main/postgresql.conf"

## functions
log() {
  echo "[$(date +%Y-%m-%dT%H:%m)] ${SCRIPT_NAME} $1"
}

## main
if [ "$VERSION_OLD" = "$VERSION_NEW" ]; then
  exit 0
fi

if [ ! -d "$PG_VAR_DIR_OLD" ] || [ ! -d "$PG_VAR_DIR_NEW" ]; then
  log "source or target cluster directory is missing"
  exit 1
fi

if [ ! -x "$PG_BIN_DIR_OLD/pg_ctl" ] || [ ! -x "$PG_BIN_DIR_NEW/pg_upgrade" ]; then
  log "source or target PostgreSQL binaries are missing"
  exit 1
fi

log "starting conversion from $VERSION_OLD to $VERSION_NEW"

# Be safe when invoked directly after a completed migration.
if pg_lsclusters -h | awk -v target="$VERSION_NEW" \
  '$1 == target && $2 == "main" && $3 == "5432" && $4 == "online" { found=1 } END { exit !found }'; then
  log "target cluster is already active on port 5432; migration already complete"
  exit 0
fi

# Stop only the source and target clusters.  Trixie requires a verified
# customer backup before this non-rollback link-mode migration.
pg_ctlcluster "$VERSION_OLD" main stop || true
pg_ctlcluster "$VERSION_NEW" main stop || true

WORK_DIR=$(mktemp -d /tmp/pg-upgrade-${VERSION_OLD}-${VERSION_NEW}-XXXXXX)
chown postgres:postgres "$WORK_DIR"
pushd "$WORK_DIR" >/dev/null
OLD_OPTIONS="-c config_file=${PG_CONF_OLD}"
NEW_OPTIONS="-c config_file=${PG_CONF_NEW}"

su -s /bin/sh postgres -c \
  "\"$PG_BIN_DIR_NEW/pg_upgrade\" --check -b \"$PG_BIN_DIR_OLD\" -B \"$PG_BIN_DIR_NEW\" -d \"$PG_VAR_DIR_OLD\" -D \"$PG_VAR_DIR_NEW\" -o \"$OLD_OPTIONS\" -O \"$NEW_OPTIONS\""

# Link mode avoids requiring a second full database copy on customer
# appliances.  The old cluster is retired after successful migration.
su -s /bin/sh postgres -c \
  "\"$PG_BIN_DIR_NEW/pg_upgrade\" --link -b \"$PG_BIN_DIR_OLD\" -B \"$PG_BIN_DIR_NEW\" -d \"$PG_VAR_DIR_OLD\" -D \"$PG_VAR_DIR_NEW\" -o \"$OLD_OPTIONS\" -O \"$NEW_OPTIONS\""

popd >/dev/null
pg_dropcluster --stop "$VERSION_OLD" main
log "conversion result: SUCCESS; old cluster retired"
