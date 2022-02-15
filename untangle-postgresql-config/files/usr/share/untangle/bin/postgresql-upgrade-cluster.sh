#! /bin/bash

set -xu

## variables
VERSION_OLD=$1
VERSION_NEW=$2

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
if [ $VERSION_OLD = $VERSION_NEW ] || [ ! -d $PG_VAR_DIR_OLD ] ; then
  exit 0
fi

log "starting conversion from $VERSION_OLD to $VERSION_NEW"

# Drop old extension (prevent upgrade from working)
psql -U postgres -c "drop extension tablefunc" uvm

# Stop all instances
systemctl stop postgresql
sleep 3

# Run conversion
pushd /tmp
su postgres -c "/usr/lib/postgresql/${VERSION_NEW}/bin/pg_upgrade --link -b $PG_BIN_DIR_OLD -B $PG_BIN_DIR_NEW -d $PG_VAR_DIR_OLD -D $PG_VAR_DIR_NEW -o ' -c config_file='$PG_CONF_OLD -O ' -c config_file='$PG_CONF_NEW"
if [ $? != 0 ] ; then
  status="FAILURE"
else
  status="SUCCESS"
fi
popd

log "conversion result: $status"

# remove old cluster and associated files
pg_dropcluster $VERSION_OLD main
rm -fr $PG_VAR_DIR_OLD
log "dropped old cluster"

