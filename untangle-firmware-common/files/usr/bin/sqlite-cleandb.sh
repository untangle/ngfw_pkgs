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

# Only clean DB if the percentage of used ramdisk is more than the soft limit
limit_percent="50"
# When cleaning, try to reach a target percent of used ramdisk
target_percent="35"

if [ "$percent" -gt "$limit_percent" ] ; then

    # delete the enough data to get approximately back to the target disk usage percent
    delete_percent="`awk \"BEGIN {printf \\\"%.0f\\\", ((($percent-$target_percent)/($percent))*100)}\" `"
    echo "`date -Iseconds`| Cleaning postgres DB... (deleting ${delete_percent}%)"

    clean_db $delete_percent

    exit 0
fi


