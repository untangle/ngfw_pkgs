#!/usr/bin/env python

import os, getopt, sys, json, subprocess

def usage():
    print """\
usage: %s start|stop|status|sessions 
    start   - start QoS services
    stop    - stop QoS services
    status  - print QoS status
    session - print current sessions
""" % sys.argv[0]
    sys.exit(1)

def qos_priorities():
    return [1,2,3,4,5,6,7]

def qos_priority_field( qos_settings, intf, priorityId, base, field ):
    for prio in qos_settings.get('qosPriorities').get('list'):
        if prio.get('priorityId') == priorityId:
            return intf.get(base) * (prio.get(field)/100.0)
    print("Unable to find %s for priority %i" % (field, priorityId))
    return None

def qos_priority_upload_reserved( qos_settings, intf, priorityId ):
    return qos_priority_field( qos_settings, intf, priorityId, 'uploadBandwidthKbps', 'uploadReservation')

def qos_priority_upload_limit( qos_settings, intf, priorityId ):
    return qos_priority_field( qos_settings, intf, priorityId, 'uploadBandwidthKbps', 'uploadLimit')

def qos_priority_download_reserved( qos_settings, intf, priorityId ):
    return qos_priority_field( qos_settings, intf, priorityId, 'downloadBandwidthKbps', 'downloadReservation')

def qos_priority_download_limit( qos_settings, intf, priorityId ):
    return qos_priority_field( qos_settings, intf, priorityId, 'downloadBandwidthKbps', 'downloadLimit')

def run( cmd, ignore_errors=False, print_cmd=False ):
    if print_cmd:
        print cmd
    ret = os.system( cmd )
    if ret != 0 and not ignore_errors:
        print("ERROR: Command failed: %i \"%s\"" % (ret, cmd))

def flush_htb_rules( wan_intfs ):
    #print "Flushing HTB..."

    for intf in wan_intfs:
        wan_dev = intf.get('systemDev')
        imq_dev = intf.get('imqDev')
        run( "tc qdisc del dev %s root    2> /dev/null > /dev/null" % wan_dev, ignore_errors=True )
        run( "tc qdisc del dev %s ingress 2> /dev/null > /dev/null" % wan_dev, ignore_errors=True )
        run( "tc qdisc del dev %s root    2> /dev/null > /dev/null" % imq_dev, ignore_errors=True )
        run( "tc qdisc del dev %s ingress 2> /dev/null > /dev/null" % imq_dev, ignore_errors=True )
    
    #make sure we clean everything by iterating over the lists of devices
    #that have a queueing discipline but utun has rules on it without QoS so leave those alone
    p = subprocess.Popen(["sh","-c","tc qdisc show | awk '{ print $5; }'"],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    for line in iter(p.stdout.readline, ''):
        dev = line.strip()
        # print( "Flushing %s..." % dev )
        if dev != "utun":
            run("tc qdisc del dev %s root    2> /dev/null > /dev/null" % dev, ignore_errors=True)
            run("tc qdisc del dev %s ingress 2> /dev/null > /dev/null" % dev, ignore_errors=True)
                
def add_htb_rules( qos_settings, wan_intf ):
    #print "Adding HTB for %s and %s..." % (wan_intf.get('systemDev'), wan_intf.get('imqDev'))

    wan_dev = wan_intf.get('systemDev')
    imq_dev = wan_intf.get('imqDev')

    add_qdisc = "tc qdisc add dev " 
    add_class = "tc class add dev " 
    add_filtr = "tc filter add dev " 
    sfq = "sfq perturb 10"
    
    default_class = qos_settings.get('defaultPriority')

    #
    # egress filtering
    #
    run("tc qdisc add dev %s root handle 1: htb default 1%i" % (wan_dev, default_class) )
    wan_upload_bandwidth = wan_intf.get('uploadBandwidthKbps')
    run("tc class add dev %s parent 1: classid 1:1 htb rate %ikbit" % (wan_dev, wan_upload_bandwidth) )
    for i in qos_priorities(): 
        upload_reserved = qos_priority_upload_reserved( qos_settings, wan_intf, i)
        upload_limit    = qos_priority_upload_limit( qos_settings, wan_intf, i)

        if upload_limit == None and upload_reserved == None:
            continue

        if upload_reserved == None:
            # should never happen as UPLOAD_RESERVED must be >0
            # Can't provide no reservation,TC says '"rate" is required'
            upload_reserved=100
            reserved=" rate %ikbit " % upload_reserved
        else:
            reserved=" rate %ikbit " % upload_reserved

        if upload_limit == None:
            limited=" ceil 99999999999kbit"
        else:
            limited=" ceil %ikbit " % upload_limit

        quantum = (upload_reserved / wan_upload_bandwidth) * 60000
        if quantum < 2000:
            quantum = 2000

        # egress outbound hierarchical token bucket for class $i - need quantum or prio?
        run("%s %s parent 1:1 classid 1:1%i htb %s %s quantum %i" % (add_class, wan_dev, i, reserved, limited, int(quantum)) ) 
        run("%s %s parent 1:1%i handle 1%i: %s" % (add_qdisc, wan_dev, i, i, sfq) )
        run("%s %s parent 1: prio 1%i protocol ip u32 match mark 0x000%i0000 0x000F0000 flowid 1:1%i" % (add_filtr, wan_dev, i, i, i) )

    #
    # ingress filtering
    # ingress filtering is done via the IMQ interface
    #
    run("ifconfig %s up" % imq_dev)
    run("%s %s root handle 1: htb default 1%i" % (add_qdisc, imq_dev, default_class) )
    wan_download_bandwidth = wan_intf.get('downloadBandwidthKbps')
    run("%s %s parent 1: classid 1:1 htb rate %ikbit" % (add_class, imq_dev,  wan_download_bandwidth) )
    for i in qos_priorities(): 
        download_reserved = qos_priority_download_reserved( qos_settings, wan_intf, i)
        download_limit    = qos_priority_download_limit( qos_settings, wan_intf, i)

        if download_limit == None and download_reserved == None:
            continue
        
        if download_reserved == None:
            # should never happen as DOWNLOAD_RESERVED must be >0
            # Can't provide no reservation,TC says '"rate" is required'
            download_reserved=100
            reserved = " rate 100kbit "
        else:
            reserved=" rate %ikbit " % download_reserved

        if download_limit == None:
            limited=" ceil 99999999999kbit"
        else:
            limited=" ceil %ikbit " % download_limit

        quantum = (download_reserved / wan_download_bandwidth) * 60000
        if quantum < 2000:
            quantum = 2000

        # ingress inbound hierarchical token bucket for class $i - need quantum or prio?
        run("%s %s parent 1:1 classid 1:1%i htb %s %s quantum %i" % (add_class, imq_dev, i, reserved, limited, int(quantum)) )
        run("%s %s parent 1:1%i handle 1%i: %s" % (add_qdisc, imq_dev, i, i, sfq) )
        run("%s %s parent 1: prio 1%i protocol ip u32 match mark 0x000%i0000 0x000F0000 flowid 1:1%i" % (add_filtr, imq_dev, i, i, i) )

def stop( qos_settings, wan_intfs ):
    flush_htb_rules( wan_intfs )

def start( qos_settings, wan_intfs ):
    flush_htb_rules( wan_intfs )

    if qos_settings.get('qosEnabled') != True:
        sys.exit(0)

    run( "modprobe imq" )

    for wan_intf in wan_intfs:
        add_htb_rules( qos_settings, wan_intf )
    
    sys.exit(0)

def status( qos_interfaces, wan_intfs ):
    for wan_intf in wan_intfs:
        wan_dev = wan_intf.get('systemDev')
        imq_dev = wan_intf.get('imqDev')
        wan_name = wan_intf.get('name')
        run( "tc -s class ls dev %s | sed \"s/^class/interface: %s Outbound class/\"" % (wan_dev, wan_name) )
        run( "tc -s class ls dev %s | sed \"s/^class/interface: %s Inbound class/\"" % (imq_dev, wan_name) )
        #run("echo ------ Qdisc  ------")
        #run("tc -s qdisc ls dev %s" % wan_dev)
        #run("tc -s qdisc ls dev %s" % imq_dev)
        #run("echo ------ Class  ------")
        #run("tc -s class ls dev %s" % wan_dev)
        #run("tc -s class ls dev %s" % imq_dev)
        #run("echo ------ Filter ------")
        #run("tc -s filter ls dev %s" % wan_dev)
        #run("tc -s filter ls dev %s" % imq_dev)

def sessions( qos_interfaces, wan_intfs ):
    run( r"""cat /proc/net/ip_conntrack | grep -v '127.0.0.1' | grep tcp | sed 's/[a-z]*=//g' | awk '{printf "proto %s state %s src %s dst %s src-port %s dst-port %s packets %s bytes %s priority %x\n", $1, $4, $5, $6, $7, $8, $9, $10, rshift(and($18,0x000F0000),16)}'""")
    run( r"""cat /proc/net/ip_conntrack | grep -v '127.0.0.1' | grep udp | sed 's/\[.*\]//g' | sed 's/[a-z]*=//g' | awk '{printf "proto %s state xx src %s dst %s src-port %s dst-port %s packets %s bytes %s priority %x\n", $1, $4, $5, $6, $7, $8, $9, rshift(and($16,0x000F0000),16)}'""")

    
#
# Main
#

try:
     opts, args = getopt.getopt(sys.argv[1:], "", [])
except getopt.GetoptError, err:
     print str(err)
     usage()
     sys.exit(2)

if len(args) < 1:
    usage()

action = args[0]

network_settings = json.loads(open('/usr/share/untangle/settings/untangle-vm/network.js', 'r').read())
if network_settings == None:
    print "Failed to read network settings"
    sys.exit(1)

qos_settings = network_settings.get('qosSettings')
if qos_settings == None:
    print "Failed to read qos settings"
    sys.exit(1)

if qos_settings.get('defaultPriority') == None:
    print "Failed to read default class"
    sys.exit(1)

if network_settings.get('interfaces') == None:
    print "Failed to read interfaces"
    sys.exit(1)
interfaces = network_settings.get('interfaces').get('list')

wan_intfs = []
for intf in interfaces:
    if intf.get('configType') == "ADDRESSED" and intf.get('isWan'):
        if intf.get('systemDev') == None:
            print "Failed to read systemDev on %s" % intf.get('name')
            sys.exit(1)
        if intf.get('imqDev') == None:
            print "Failed to read imqDev on %s" % intf.get('name')
            sys.exit(1)
        if intf.get('downloadBandwidthKbps') == None:
            print "Failed to read downloadBandwidthKbps on %s" % intf.get('name')
            sys.exit(1)
        if intf.get('uploadBandwidthKbps') == None:
            print "Failed to read uploadBandwidthKbps on %s" % intf.get('name')
            sys.exit(1)
        wan_intfs.append(intf)

if action == "stop":
    stop( qos_settings, wan_intfs )
elif action == "start":
    start( qos_settings, wan_intfs )
elif action == "status":
    status( qos_settings, wan_intfs )
elif action == "sessions":
    sessions( qos_settings, wan_intfs )
else:
    print "Unknown argument: %s" % action
    usage

sys.exit(0)


