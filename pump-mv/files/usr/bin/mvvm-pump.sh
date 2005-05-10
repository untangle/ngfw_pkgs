#!/bin/sh

mkdir -p /var/log/mvvm &> /dev/null

if [ "$1" = "up" ] ; then
    echo "mvvm-pump.sh: Interface Up. Restarting" >> /var/log/mvvm/wrapper.log 2>&1
    if [ -f @PREFIX@/etc/init.d/mvvm ] ; then 
        @PREFIX@/etc/init.d/mvvm restart
    fi
fi

if [ "$1" = "renewal" ] ; then
    echo "mvvm-pump.sh: DHCP Renewal. mcli updateAddress" >> /var/log/mvvm/wrapper.log 2>&1
    if [ -f @PREFIX@/usr/bin/mcli ] ; then 
        @PREFIX@/usr/bin/mcli updateAddress &> /dev/null &
    fi
fi

if [ "$1" = "down" ] ; then
    echo "mvvm-pump.sh: Interface Down. Restarting" >> /var/log/mvvm/wrapper.log 2>&1
    if [ -f @PREFIX@/etc/init.d/mvvm ] ; then 
        @PREFIX@/etc/init.d/mvvm restart
    fi
fi
