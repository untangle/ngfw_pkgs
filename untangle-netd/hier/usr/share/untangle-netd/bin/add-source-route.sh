#!/bin/dash

# This script addes the appropriate ip route source route for the address of a WAN
# Usage: add-source-route.sh <address> <routeTable> <family>

## All of the untangle rules MUST fall in this priority.  This makes it easy to
## flush all of the rules.
PRIORITY_MIN="50000"
PRIORITY_MAX="59999"

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
    echo "$0 <address> <rt_table> <family>"
    echo "\t This add a source route for the specified address to the specified table"
    echo
    echo "\t address: the address of the local interface (ex: 1.2.3.4)"
    echo "\t rt_table: the route table (ex: uplink.1)"
    echo "\t family: the family, -4 or -6"
    echo

    exit 254
}

next_free_priority()
{
    local t_min_priority=$1
    local t_max_priority=$2
    
    ip -4 rule show | awk -v min_priority=$t_min_priority -v max_priority=$t_max_priority -v priority=$t_min_priority  \
        '{ sub( ":", "" ) ; if (( $1 >= min_priority ) && ( $1 < max_priority ) && ( priority == $1 )) priority=$1 +1 } END { print priority }'
}

## Start of script
ADDRESS=$1
RT_TABLE=$2
FAMILY=$3

# old version called this as an option argument
# it is now a required argument but this logic is kept for backwards compatibility
# it can be removed in the future
if [ -z "${FAMILY}" ] ; then
    FAMILY="-4"
fi

# No IPv6 source routes for now
if [ "$FAMILY" = "-6" ] ; then
    exit 0
fi

DEBUG=/bin/true
IP="ip"

DEBUG="debug"
IP="debug_ip"

[ -z "${ADDRESS}" ] && usage
[ -z "${RT_TABLE}" ] && usage
[ -z "${FAMILY}" ] && usage

$DEBUG "Adding source default route for ${ADDRESS} to ${RT_TABLE}"

# If table exists (this must be a WAN)
ip route show table ${RT_TABLE} >/dev/null 2>&1
if [ ! $? -eq 0 ] ; then
    $DEBUG "Table ${RT_TABLE} does not exist. Ignoring source route!"
    exit 1
fi

ip rule ls | grep -qE "^5[0-9]{4}:\s*from\s*${ADDRESS}\s*lookup\s*${RT_TABLE}"
if [ $? -eq 0 ] ; then
    # rule already exists
    exit 0
fi
  
t_priority=`next_free_priority 50000 59999`
debug_ip rule add priority ${t_priority} from ${ADDRESS} lookup ${RT_TABLE}



