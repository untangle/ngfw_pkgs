#!/bin/sh

BOGUS_ADDRESS_BASE="169.254.210.50"
BOGUS_NETMASK="255.255.0.0"

## DHCP auto renew script, used to kill any processes lingering around
## This is hardcoded, so if it changes, it must be updated in the other location.
DHCP_AUTO_RENEW="/usr/share/metavize/networking/dhcp-auto-renew"

INTERFACE=$2

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
if [ "x$1" = "xup" ] ; then
    echo "mvvm-pump.sh: Interface Up. mcli updateAddress (`date`)" >> /var/log/mvvm/iptables.log 2>&1
    /usr/bin/mcli updateAddress >> /var/log/mvvm/iptables.log 2>&1 &
fi

#
# Renewal Script
# Tell mvvm of new address
#
if [ "x$1" = "xrenewal" ] ; then
    echo "mvvm-pump.sh: DHCP Renewal. mcli updateAddress (`date`)" >> /var/log/mvvm/iptables.log 2>&1
    /usr/bin/mcli updateAddress >> /var/log/mvvm/iptables.log 2>&1 &
fi

#
# Down Script
# if already down (in fake mode) do nothing, otherwise restart (go into fakemode)
# 
if [ "x$1" = "xdown" ] ; then
    echo "mvvm-pump.sh: Interface Down. Restarting (`date`)" >> /var/log/mvvm/iptables.log 2>&1
    
    ## If it fails, bring the interface up with a bogus address
    if [ -n "${INTERFACE}" ]; then
        ifconfig ${INTERFACE} ${BOGUS_ADDRESS_BASE} netmask ${BOGUS_NETMASK}
    else
        echo "mvvm-pump.sh: Interface is not set, unable to set to bogus address" \
            >> /var/log/mvvm/iptables.log 2>&1
    fi

    /usr/bin/mcli updateAddress >> /var/log/mvvm/iptables.log 2>&1 &
    
    if [ -f ${DHCP_AUTO_RENEW} ] && [ -n "${INTERFACE}" ]; then
        nohup sh ${DHCP_AUTO_RENEW} ${INTERFACE} &
    else
        echo "mvvm-pump.sh: Auto renew script doesn't exist or interface is unset, exiting" \
            >> /var/log/mvvm/iptables.log 2>&1
    fi
fi
