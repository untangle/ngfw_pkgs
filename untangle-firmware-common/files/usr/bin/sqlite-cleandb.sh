#!/bin/dash

DIR="/var/lib/sqlite"

reinit_db()
{
    echo "`date -Iseconds`| Completely nuking database..."
    rm -rf ${DIR}/*
    /usr/share/untangle/bin/reports-generate-tables.py -d sqlite
}

clean_db()
{
    echo "`date -Iseconds`| Cleaning tables..."
    /usr/bin/sqlite-delete-half.py

}

echo "`date -Iseconds`| Cleaning postgres DB..."

percent="`df --output=pcent ${DIR} | sed 1d | sed 's/%//'`"
#percent="100"
percent="85"
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


