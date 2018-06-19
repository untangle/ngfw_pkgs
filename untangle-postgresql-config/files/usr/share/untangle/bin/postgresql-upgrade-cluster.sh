#! /bin/bash

set -xu

VERSION_OLD=$1
VERSION_NEW=$2

PG_VAR_DIR_OLD="/var/lib/postgresql/${VERSION_OLD}/main"
PG_BIN_DIR_OLD="/usr/lib/postgresql/${VERSION_OLD}/bin"
PG_CONF_OLD="/etc/postgresql/${VERSION_OLD}/main/postgresql.conf"

PG_VAR_DIR_NEW="/var/lib/postgresql/${VERSION_NEW}/main"
PG_BIN_DIR_NEW="/usr/lib/postgresql/${VERSION_NEW}/bin"
PG_CONF_NEW="/etc/postgresql/${VERSION_NEW}/main/postgresql.conf"

if [ -d $PG_VAR_DIR_OLD ] ; then
  echo "[$(date +%Y-%m%-dT%H:%m)] Starting conversion"

  # Stop all instances
  systemctl stop postgresql || true
  /etc/init.d/postgresql stop || true

  # Start 9.4
  systemctl start postgresql@9.4-main || true
  /etc/init.d/postgresql start 9.4 || true

  # Drop old extension (pervent upgrade from working)
  psql -U postgres -c "drop extension tablefunc" uvm || true

  # Stop all instances
  systemctl stop postgresql || true
  /etc/init.d/postgresql stop || true
  
  # Run conversion
  pushd /tmp
  su postgres -c "/usr/lib/postgresql/${VERSION_NEW}/bin/pg_upgrade --link -b $PG_BIN_DIR_OLD -B $PG_BIN_DIR_NEW -d $PG_VAR_DIR_OLD -D $PG_VAR_DIR_NEW -o ' -c config_file='$PG_CONF_OLD -O ' -c config_file='$PG_CONF_NEW"
  if [ $? != 0 ] ; then
      echo "[$(date +%Y-%m%-dT%H:%m)] Conversion FAILED"
      pg_dropcluster $VERSION_OLD main
      exit 0
  fi
  
  pg_dropcluster $VERSION_OLD main
  popd

  rm -fr $PG_VAR_DIR_OLD
  echo "[$(date +%Y-%m%-dT%H:%m)] Conversion complete"
  echo
fi
