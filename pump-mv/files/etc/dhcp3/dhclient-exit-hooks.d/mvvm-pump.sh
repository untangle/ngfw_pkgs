#!/bin/sh

BOGUS_ADDRESS_BASE="169.254.210.50"
BOGUS_NETMASK="255.255.0.0"

#
# Error checking
#
mkdir -p /var/log/mvvm &> /dev/null

MCLI="/usr/bin/mcli"

if [ ! -f ${MCLI} ] ; then 
    echo "$0: ${MCLI} missing (`date`)" >> /var/log/mvvm/wrapper.log 2>&1
    exit 1
fi

#
# Up script
# If in fake mode, restart
# Otherwise just update address
#
case "${reason}" in
    ## Lease is updated, call mcli updateAddress
    "BOUND"|"RENEW"|"REBIND"|"REBOOT")
        echo "$0: DHCP - ${reason}. (`date`)" >> /var/log/mvvm/iptables.log 2>&1
        ## These must be backgrounded due to the locking around network configuration.
        ${MCLI} updateAddress >> /var/log/mvvm/iptables.log 2>&1 &
        ;;

    ## Failed to update lease, set to bogus address and then call update address.
    "FAIL"|"TIMEOUT"|"EXPIRE")
        echo "$0: DHCP - ${reason}. Setting to bogus address(`date`)" >> /var/log/mvvm/iptables.log 2>&1
    
        ## If it fails, bring the interface up with a bogus address
        if [ -n "${interface}" ]; then
            ifconfig ${interface} ${BOGUS_ADDRESS_BASE} netmask ${BOGUS_NETMASK} up
        else
            echo "$0: interface is not set, unable to set to bogus address" \
                >> /var/log/mvvm/iptables.log 2>&1
        fi

        ## These must be backgrounded due to the locking around network configuration.
        ${MCLI} updateAddress >> /var/log/mvvm/iptables.log 2>&1 &
        ;;

    ## Unknown commands.
    *)
        echo "Ignoring command for reason: '${reason}'"
        ;;
esac
