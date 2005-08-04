#!/bin/sh

#
# Error checking
#
mkdir -p /var/log/mvvm &> /dev/null
if [ ! -f /usr/bin/mcli ] ; then 
    echo "mvvm-pump.sh: /usr/bin/mcli missing (`date`)" >> /var/log/mvvm/wrapper.log 2>&1
    exit 1
fi

#
# Up script
# If in fake mode, restart
# Otherwise just update address
#
if [ "$1" = "up" ] ; then
    echo "mvvm-pump.sh: Interface Up. mcli updateAddress (`date`)" >> /var/log/mvvm/wrapper.log 2>&1
    /usr/bin/mcli updateAddress &> /dev/null &
fi

#
# Renewal Script
# Tell mvvm of new address
#
if [ "$1" = "renewal" ] ; then
    echo "mvvm-pump.sh: DHCP Renewal. mcli updateAddress (`date`)" >> /var/log/mvvm/wrapper.log 2>&1
    /usr/bin/mcli updateAddress &> /dev/null &
fi

#
# Down Script
# if already down (in fake mode) do nothing, otherwise restart (go into fakemode)
# 
if [ "$1" = "down" ] ; then
    echo "mvvm-pump.sh: Interface Down. Restarting (`date`)" >> /var/log/mvvm/wrapper.log 2>&1
    /usr/bin/mcli updateAddress &> /dev/null &
fi
