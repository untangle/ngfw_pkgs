#!/bin/dash

DIR="/var/lib/sqlite"

clean_db()
{
    echo "`date -Iseconds`| Cleaning tables..."
    # delete half of data
    /usr/bin/sqlite-delete-percent.py $1
    sqlite3 /var/lib/sqlite/reports.db 'vacuum;'
}

# If DB doesn't exsit - nothing to do
if [ ! -f $DIR/reports.db ] ; then
    exit 0
fi

percent="`df --output=pcent ${DIR} | sed 1d | sed 's/%//'`"
#percent="100"
#percent="85"
echo "`date -Iseconds`| DB ramdisk status: $percent%"

# try to maintain approximately this amount of space used
target_percent="50"

if [ "$percent" -gt "$target_percent" ] ; then

    # delete the enough data to get approximately back to the target disk usage percent
    delete_percent="`awk \"BEGIN {printf \\\"%.0f\\\", ((($percent-$target_percent)/($percent))*100)}\" `"
    echo "`date -Iseconds`| Cleaning postgres DB... (deleting ${delete_percent}%)"

    clean_db $delete_percent

    sleep 10
    echo "`date -Iseconds`| DB ramdisk status: $percent%"

    exit 0
fi


