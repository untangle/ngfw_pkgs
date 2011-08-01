#!/usr/bin/python
# this is a utility script that reads /etc/untangle-net-alpaca/netConfig.js
# it makes reading the config in shell scripts a bit easier

import simplejson as json
import sys

if (len(sys.argv) < 2): 
    print "usage: " + sys.argv[0] + " [wan|non_wan|wan_idx|non_wan_idx]"
    print "\"wan\"          prints all wan interface names"
    print "\"non_wan\"      prints all non-wan interface names"
    print "\"wan_idx\"      prints all wan interface indexes (IDs)"
    print "\"non_wan_idx\"  prints all non-wan interface indexes (IDs)"

    sys.exit(1)


netConfigFile = open('/etc/untangle-net-alpaca/netConfig.js', 'r')
netConfigObj = json.loads(netConfigFile.read())


if sys.argv[1] == 'wan':
    for intf in netConfigObj['interfaceList']['list']:
        if intf['WAN'] != None and intf['WAN'].lower() == 'true':
            print intf['systemName']
    sys.exit(0)

if sys.argv[1] == 'non_wan':
    for intf in netConfigObj['interfaceList']['list']:
        if intf['WAN'] != None and intf['WAN'].lower() == 'false':
            print intf['systemName']
    sys.exit(0)

if sys.argv[1] == 'wan_idx':
    for intf in netConfigObj['interfaceList']['list']:
        if intf['WAN'] != None and intf['WAN'].lower() == 'true':
            print intf['interfaceId']
    sys.exit(0)

if sys.argv[1] == 'non_wan_idx':
    for intf in netConfigObj['interfaceList']['list']:
        if intf['WAN'] != None and intf['WAN'].lower() == 'false':
            print intf['interfaceId']
    sys.exit(0)




