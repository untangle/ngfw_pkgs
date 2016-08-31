#!/bin/dash

PG_VERSION="9.4"
PG_VAR_DIR="/var/lib/postgresql/${PG_VERSION}"
PG_BIN_DIR="/usr/lib/postgresql/${PG_VERSION}/bin"
PG_MAIN_DIR="/var/lib/postgresql/${PG_VERSION}/main"

reinit_db()
{
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
}

clean_db()
{
    echo "`date -Iseconds`| Cleaning tables..."
    # Delete half the data from the DB
    /usr/bin/cleandb-delete-half.py

    # Now that we've cleaned half the data we must run vacuum full
    psql -A -t -U postgres -c "SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname = 'reports';" uvm | grep '[0-9]' | while read table ; do
                                                                                                                                  echo "`date -Iseconds`| VACUUM FULL $table..."
                                                                                                                                  psql -U postgres -c "VACUUM FULL reports.$table;" uvm
                                                                                                                              done
}

echo "`date -Iseconds`| Cleaning postgres DB..."

# If postgres not running, reinitialize
if [ ! -f "/var/run/postgresql/${PG_VERSION}-main.pid" ] ; then
    echo "`date -Iseconds`| Postgres not running."
    reinit_db
    exit 0
fi

percent="`df --output=pcent ${PG_MAIN_DIR} | sed 1d | sed 's/%//'`"
#percent="100"
#percent="85"
echo "`date -Iseconds`| DB ramdisk status: $percent%"

# If more than 90% used, just reinitialize
if [ "$percent" -gt "90" ] ; then
    reinit_db
    exit 0
fi

# If more than 75% used, clean up data
if [ "$percent" -gt "75" ] ; then
    clean_db
    exit 0
fi


