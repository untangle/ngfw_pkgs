#!/bin/dash

#
# This script uses wget to retrieve the new lists and updates from google-safe-browsing
# Note: This script is NOT efficient and it is not advised to run it frequently
# This uses google's v1 safe browsing API, which is due to expire
# If they publish a decently working v2 implementation we should switch to that, but this script will do in the meantime
#

PHISH_LIST="goog-black-hash"
#API_KEY="ABQIAAAAcF3DrVo7y87-tH8HDXqeYBTJqIcXJiJ1Klr7Vk1tUUBxWLpa4w"
API_KEY="ABQIAAAADeGMABJtwtXxRtSCFqAh0hSCR3xUxns-zIMU4EaPNOmpirNj5g"
HOME_DIR="/usr/share/untangle-google-safebrowsing"
LOCK_FILE="/tmp/$PHISH_LIST.update.pid"
INITIAL_LOAD_HOUR="23"

# Check for another process
if [ -f $LOCK_FILE ] ; then
    echo "Another $0 is already running (lock file $LOCK_FILE exists)"
    exit 0
else
    echo $$ > $LOCK_FILE
fi
echo $#
# If this is the first time, the version is -1
if [ ! -f $HOME_DIR/lib/$PHISH_LIST.ver ] ; then
    if [ $# -gt 0 -o `date "+%H"` -eq $INITIAL_LOAD_HOUR ] ; then 
        echo "Initiliazing..."
    else 
        # Because the load caused by the initial loadout
        # If we detect that this is the first time this has been run we just exit unless 
        # it is the 24th hour of the day
        echo "Initial load can only be performed at the ${INITIAL_LOAD_HOUR}th hour (override with -f)" 
        rm -f $LOCK_FILE ; exit 0
    fi 
    echo "-1" > $HOME_DIR/lib/$PHISH_LIST.ver
fi
# If there is no list, create an empty list
if [ ! -f $HOME_DIR/lib/$PHISH_LIST ] ; then
    touch $HOME_DIR/lib/$PHISH_LIST
fi

PHISH_LIST_VERSION="`cat $HOME_DIR/lib/$PHISH_LIST.ver`"

echo "Current Phish   List Version: $PHISH_LIST_VERSION"

echo "Downloading updates..."
echo "wget -q \"http://sb.google.com/safebrowsing/update?client=api&apikey=$API_KEY&version=$PHISH_LIST:1:$PHISH_LIST_VERSION\" -O /tmp/$PHISH_LIST.$PHISH_LIST_VERSION"
wget -q "http://sb.google.com/safebrowsing/update?client=api&apikey=$API_KEY&version=$PHISH_LIST:1:$PHISH_LIST_VERSION" -O /tmp/$PHISH_LIST.$PHISH_LIST_VERSION
if [ $? != 0 ] ; then
    echo "Downloading updates...failed"
    echo "wget returned an error"
    exit 1
else
    echo "Downloading updates...done"
fi

# An empty file means no updates
if [ ! -s /tmp/$PHISH_LIST.$PHISH_LIST_VERSION ] ; then
    echo "No new updates."
    rm -f $LOCK_FILE ; exit 0
fi

PHISH_NEW_VERSION="`cat /tmp/$PHISH_LIST.$PHISH_LIST_VERSION | head -n 1 | sed 's/.*\.\([0-9]*\).*/\1/g'`"

if [ -z "$PHISH_NEW_VERSION" ] ; then
    echo "Invalid response: Unable to determine version (/tmp/$PHISH_LIST.$PHISH_LIST_VERSION)"
    rm -f $LOCK_FILE ; exit 0
fi

echo "New     Phish   List Version: $PHISH_NEW_VERSION"

rm -f /tmp/$PHISH_LIST 
cp -f $HOME_DIR/lib/$PHISH_LIST /tmp/$PHISH_LIST

echo -n "Updating /tmp/$PHISH_LIST |"
i=0
tail -n +2 /tmp/$PHISH_LIST.$PHISH_LIST_VERSION | while read line ; do 
    hash="`echo $line | cut -c2- `"
    operation="`echo $line | cut -c1 `"
    if   [ "X$operation" = "X+" ] ; then
        #echo "adding   $hash"
        echo $hash >> /tmp/$PHISH_LIST
    elif [ "X$operation" = "X-" ] ; then
        #echo "removing $hash"
        sed -i '/$hash/d' /tmp/$PHISH_LIST
    elif [ -z $line ] ; then
        true
    else
        echo "unknown format: $line"
    fi
    if [ $(($i%500)) -eq 0 ] ; then
        echo -n "."
    fi
    i=$((i+1))
done
echo "| Complete."

cat /tmp/$PHISH_LIST | sort | uniq > $HOME_DIR/lib/$PHISH_LIST
echo "$PHISH_NEW_VERSION" > $HOME_DIR/lib/$PHISH_LIST.ver
rm -f /tmp/$PHISH_LIST 

echo "Updated $HOME_DIR/lib/$PHISH_LIST"
