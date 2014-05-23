#!/bin/dash

# This script addes updates appropriate iptables rules for DNS server
# It reads the values from dnsmasq.conf

debug()
{
    /bin/echo -e "[UPLINK  DEBUG: `date`] ${*}"
}

debug_iptables()
{
    debug iptables $*
    iptables $*
}

DEBUG=/bin/true
IP="ip"

DEBUG="debug"
#IPTABLES="debug_iptables"
IPTABLES="iptables"

flush_rules()
{
    DNS_ADDR=$1
    WAN_INDEX=$2

    ${IPTABLES} -t mangle -N dns-rule-wan-${WAN_INDEX} >/dev/null 2>&1
    ${IPTABLES} -t mangle -F dns-rule-wan-${WAN_INDEX} >/dev/null 2>&1
    ${IPTABLES} -t mangle -D OUTPUT -j dns-rule-wan-${WAN_INDEX} >/dev/null 2>&1
    ${IPTABLES} -t mangle -I OUTPUT -j dns-rule-wan-${WAN_INDEX} 
}

add_rule()
{
    DNS_ADDR=$1
    WAN_INDEX=$2

    $DEBUG "Adding DNS rule for ${DNS_ADDR} to WAN ${WAN_INDEX}"
    ${IPTABLES} -t mangle -A dns-rule-wan-${WAN_INDEX} -d ${DNS_ADDR} -m mark --mark 0/0xff00 -m conntrack --ctstate NEW -j MARK --set-mark $((${WAN_INDEX}<<8))/0xff00 -m comment --comment "Vote for traffic to this DNS to go out WAN ${WAN_INDEX}."
}

awk '/^(# *)?server=/ { sub( /^(# *)?/, "" ) ; sub( /server=/, "") ; sub(/# uplink./,"") ; print ; next }' /etc/dnsmasq.conf | while read line ; do
   flush_rules $line
done

awk '/^(# *)?server=/ { sub( /^(# *)?/, "" ) ; sub( /server=/, "") ; sub(/# uplink./,"") ; print ; next }' /etc/dnsmasq.conf | while read line ; do
   add_rule $line
done




