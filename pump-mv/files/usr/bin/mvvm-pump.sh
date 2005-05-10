#!/bin/sh

mkdir -p /var/log/mvvm &> /dev/null

if [ "$1" = "up" ] ; then
    if [ -f /tmp/fakemode-restart ] ; then
        rm -f /tmp/fakemode-restart
        echo "mvvm-pump.sh: Interface Up. Restarting" >> /var/log/mvvm/wrapper.log 2>&1
        if [ -f /etc/init.d/mvvm ] ; then 
            /etc/init.d/mvvm restart
        fi
    else
        echo "mvvm-pump.sh: Interface Up. mcli updateAddress" >> /var/log/mvvm/wrapper.log 2>&1
        if [ -f /etc/init.d/mvvm ] ; then 
            /usr/bin/mcli updateAddress &> /dev/null &
        fi
    fi
fi

if [ "$1" = "renewal" ] ; then
    echo "mvvm-pump.sh: DHCP Renewal. mcli updateAddress" >> /var/log/mvvm/wrapper.log 2>&1
    if [ -f /usr/bin/mcli ] ; then 
        /usr/bin/mcli updateAddress &> /dev/null &
    fi
fi

if [ "$1" = "down" ] ; then
    echo "mvvm-pump.sh: Interface Down. Restarting" >> /var/log/mvvm/wrapper.log 2>&1
    if [ -f /etc/init.d/mvvm ] ; then 
        /etc/init.d/mvvm restart
        touch /tmp/fakemode-restart
    fi
fi
