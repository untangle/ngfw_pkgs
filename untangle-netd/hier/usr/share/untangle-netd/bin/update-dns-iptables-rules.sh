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
    WAN_INDEX=$1

    ${IPTABLES} -t mangle -N dns-rule-wan-${WAN_INDEX} >/dev/null 2>&1
    ${IPTABLES} -t mangle -F dns-rule-wan-${WAN_INDEX} >/dev/null 2>&1
    ${IPTABLES} -t mangle -D OUTPUT -j dns-rule-wan-${WAN_INDEX} >/dev/null 2>&1
    ${IPTABLES} -t mangle -I OUTPUT -j dns-rule-wan-${WAN_INDEX} 
}

add_rule()
{
    WAN_INDEX=$1
    DNS_ADDR=$2

    $DEBUG "Adding DNS rule for ${DNS_ADDR} to WAN ${WAN_INDEX}"
    ${IPTABLES} -t mangle -A dns-rule-wan-${WAN_INDEX} -d ${DNS_ADDR} -m mark --mark 0/0xff00 -m conntrack --ctstate NEW -j MARK --set-mark $((${WAN_INDEX}<<8))/0xff00 -m comment --comment "Vote for traffic to this DNS to go out WAN ${WAN_INDEX}."
}

awk -F"[ =]" '/server=/ {print $4 " " $2}' /etc/dnsmasq.conf | sed -e 's/uplink.//' | while read line ; do
   flush_rules $line
done

awk -F"[ =]" '/server=/ {print $4 " " $2}' /etc/dnsmasq.conf | sed -e 's/uplink.//' | while read line ; do
   add_rule $line
done




