#!/bin/dash

echo "`date -Iseconds`| Checking DB ramdisk size..."

PG_VERSION="9.4"
PG_VAR_DIR="/var/lib/postgresql/${PG_VERSION}"
PG_BIN_DIR="/usr/lib/postgresql/${PG_VERSION}/bin"
PG_MAIN_DIR="/var/lib/postgresql/${PG_VERSION}/main"

percent="`df --output=pcent ${PG_MAIN_DIR} | sed 1d | sed 's/%//'`"
#percent="85"

echo "`date -Iseconds`| DB ramdisk status: $percent%"

if [ "$percent" = "100" ] ; then
    echo "`date -Iseconds`| Completely nuking database..."
    /etc/init.d/postgresql stop

    # mount a ramdisk
    rm -rf ${PG_MAIN_DIR}/*
    chown -R postgres:postgres ${PG_MAIN_DIR}

    # create DB
    su -c "${PG_BIN_DIR}/initdb --encoding=utf8 --locale=${locale} -D ${PG_VAR_DIR}/main" postgres

    # start postgres
    /etc/init.d/postgresql start

    # create user/db/etc
    createuser -U postgres -dSR untangle
    createdb -O postgres -U postgres uvm
    createlang -U postgres plpgsql uvm

    # create 
    /usr/share/untangle/bin/reports-generate-tables.py
    exit 0
fi

if [ "$percent" -gt "70" ] ; then
    echo "`date -Iseconds`| Cleaning tables..."
    # Delete half the data from the DB
    /usr/bin/cleandb-delete-half.py

    # Now that we've cleaned half the data we must run vacuum full
    psql -A -t -U postgres -c "SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname = 'reports';" uvm | grep '[0-9]' | while read table ; do
                                                                                                                                  echo "`date -Iseconds`| VACUUM FULL $table..."
                                                                                                                                  psql -U postgres -c "VACUUM FULL reports.$table;" uvm
                                                                                                                              done
    exit 0
fi


