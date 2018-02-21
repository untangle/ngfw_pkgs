#!/bin/dash

# This script addes the appropriate ip route rules for a WAN interface
# Usage: add-uplink.sh <interface> <gatewayIP> <routeTable> <family>

# The ip route priority for the default rule
PRIORITY_DEFAULT="1000000"

## Functions
debug()
{
    /bin/echo -e "[UPLINK  DEBUG: `date`] ${*}"
}

debug_ip()
{
    debug ip $*
    ip $*
}

usage()
{
    echo "$0 <interface> <gateway> <rt_table> <family> <dns1> <dns2>"
    echo "\t This will configure an uplink table <rt_table> with gateway"
    echo "\t and add routing entries for all of the addresses on interface."
    echo
    echo "\t interface: the interface (ex: eth0)"
    echo "\t gateway: the gateway address (ex: 1.2.3.4)"
    echo "\t rt_table: the route table (ex: uplink.1)"
    echo "\t family: the family, -4 or -6"
    echo

    exit 254
}

## Start of script
IFACE=$1
GATEWAY=$2
RT_TABLE=$3
FAMILY=$4

# old version called this as an option argument
# it is now a required argument but this logic is kept for backwards compatibility
# it can be removed in the future
if [ -z "${FAMILY}" ] ; then
    FAMILY="-4"
fi


DEBUG=/bin/true
IP="ip"

DEBUG="debug"
IP="debug_ip"

[ -z "${IFACE}" ] && usage
[ -z "${GATEWAY}" ] && usage
[ -z "${RT_TABLE}" ] && usage

$DEBUG "Adding default route table ${RT_TABLE} for ${IFACE} to ${GATEWAY}."

# Add/Replace an implicit route for that gateway on IFACE
# This is for ISPs that give out gateways not within the customer's network/netmask
# Ignore "RTNETLINK answers: File exists" error, this just mean the route exists
${IP} ${FAMILY} route replace ${GATEWAY} dev ${IFACE} 2>&1 | grep -v 'File exists'

# Add/Replace the default route in the uplink table
# Ignore "RTNETLINK answers: File exists" error, this just mean the route exists - IPv6 throws this, IPv4 does not
if [ "$FAMILY" = "-4" ] ; then
    # IPv4
    # IPv4 only allows for one default, so add/replace it.
    ${IP} ${FAMILY} route replace table ${RT_TABLE} default via ${GATEWAY} 2>&1 | grep -v 'File exists'
fi
if [ "$FAMILY" = "-6" ] ; then
    # IPv6
    # IPv6 allows for multiple defaults (not sure why), so we flush the table and add/replace a new default
    ${IP} ${FAMILY} route flush table ${RT_TABLE}
    ${IP} ${FAMILY} route replace table ${RT_TABLE} default via ${GATEWAY} 2>&1 | grep -v 'File exists'
fi

## If necessary add the default uplink rule for IPv4
ip ${FAMILY} rule show | grep -q ${PRIORITY_DEFAULT} || {
    $DEBUG "Adding default uplink rule for ${RT_TABLE} IPv4"
    ip ${FAMILY} rule del priority ${PRIORITY_DEFAULT} >/dev/null 2>&1
    ${IP} ${FAMILY} rule add priority ${PRIORITY_DEFAULT} lookup ${RT_TABLE}
}


