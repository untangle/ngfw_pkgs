#!/bin/sh

# This script will sleep up until max_wait seconds
# or until the specified interface acquires an IP address

# It is used to delay the networking init scripts to wait on the pppoe interafces
# to acquire IP addresses. (DHCP does not need this because its blocking)

usage() {
    echo "Usage: $0 <interface> <max_wait>"
    echo "Example: $0 ppp0 60"
    exit 2
}

if [ $# -lt 2 ] ; then
    usage
fi

INTERFACE=$1
MAX_WAIT=$2

i=0
while [ $i -lt $MAX_WAIT ] ; do
    i=$(($i+1))
    ip addr show $INTERFACE 2>&1 | grep -qE 'inet\s.*scope global'
    if [ $? -eq 0 ] ;  then
        exit 0
    fi

    sleep 1
done

# should we exit with an error?
# Since this script is called from if-up, probably not
exit 0
