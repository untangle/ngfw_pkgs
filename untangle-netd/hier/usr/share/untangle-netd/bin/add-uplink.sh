#!/bin/dash

# This script addes the appropriate ip route rules for a WAN interface
# Usage: add-uplink.sh <interface> <gatewayIP> <routeTable> <family>

## All of the untangle rules MUST fall in this priority.  This makes it easy to
## flush all of the rules.
UNTANGLE_PRIORITY_BASE="36"
UNTANGLE_PRIORITY_DEFAULT="${UNTANGLE_PRIORITY_BASE}6900"

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
    echo "$0 <interface> <gateway> <rt_table> <family>"
    echo "\t This will configure an uplink table <rt_table> with gateway"
    echo "\t and add routing entries for all of the addresses on interface."
    echo
    echo "\t interface: the interface (ex: eth0)"
    echo "\t gateway: the gateway address (ex: 1.2.3.4)"
    echo "\t rt_table: the route table (ex: uplink.1)"
    echo "\t family: the family, -4 or -6, -4 assumed if not specified"
    echo

    exit 254
}

## Determine all of the routable aliases of an interface.
ip_interface_get_v4_aliases()
{
    ## Print out all of the aliases
    ip -4 -f inet addr show $1 scope global | awk '/inet/ { sub ( "/.*", "", $2 ) ; print  $2 }'
}

## Finds the first unused priority between $1 and $2
ip_rule_get_v4_priority()
{
    local t_min_priority=$1
    local t_max_priority=$2
    
    ip -4 rule show | awk -v min_priority=$t_min_priority -v max_priority=$t_max_priority -v priority=$t_min_priority  \
        '{ sub( ":", "" ) ; if (( $1 >= min_priority ) && ( $1 < max_priority ) && ( priority == $1 )) priority=$1 +1 } END { print priority }'

}

## Determine if the rules are up to date.
ip_rule_update_v4_source_routes()
{
    local t_interface
    local t_gateway
    local t_rt_table
    local t_aliases
    local t_expected_hash
    local t_current_hash
    local t_current_aliases
    local t_alias

    t_interface=$1
    t_gateway=$2
    t_rt_table=$3
    
    t_aliases=`ip_interface_get_v4_aliases $t_interface`
    t_current_aliases=`ip rule show | awk "/from [0-9].*lookup ${t_rt_table}/ { print \\$3 }"`
 
    if [ "${t_aliases}x" = "${t_current_aliases}x" ]; then
        $DEBUG "Source based uplinks are up to date for '${t_interface}'"
        return 0
    fi

    ## Delete the current rules
    for t_alias in ${t_current_aliases}; do 
        # ignore error (if alias didnt exist previously)
        ${IP} -4 rule del from ${t_alias} lookup ${t_rt_table} >/dev/null 2>&1
    done

    for t_alias in ${t_aliases} ; do
        t_priority=`ip_rule_get_v4_priority ${UNTANGLE_PRIORITY_BASE}5000 ${UNTANGLE_PRIORITY_BASE}6000`
        ${IP} -4 rule add from ${t_alias} priority  ${t_priority} lookup ${t_rt_table}
    done
}

## Start of script
IFACE=$1
GATEWAY=$2
RT_TABLE=$3
FAMILY=$4
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

$DEBUG "$0 $*"
$DEBUG "Adding uplink for [${IFACE}] -> ${GATEWAY} to ${RT_TABLE}"

# Add source routes to force traffic from aliases out correct intf
if [ "$FAMILY" = "-4" ] ; then
    ip_rule_update_v4_source_routes ${IFACE} ${GATEWAY} ${RT_TABLE}
else
    # XXX source routes for IPv6?
    true
fi

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
ip ${FAMILY} rule show | grep -q ${UNTANGLE_PRIORITY_DEFAULT} || {
    $DEBUG "Adding default uplink rule for ${RT_TABLE} IPv4"
    ip ${FAMILY} rule del priority ${UNTANGLE_PRIORITY_DEFAULT} >/dev/null 2>&1
    ${IP} ${FAMILY} rule add priority ${UNTANGLE_PRIORITY_DEFAULT} lookup ${RT_TABLE}
}


