#!/usr/bin/env python

import os, getopt, sys, json, subprocess, parse, platform

def usage():
    print """\
usage: %s start|stop|status|sessions 
    start   - start QoS services
    stop    - stop QoS services
    status  - print QoS status
    session - print current sessions
""" % sys.argv[0]
    sys.exit(1)

def debug(str):
    if False:
        print(str)

def qos_priorities():
    return [1,2,3,4,5,6,7]

def qos_priority_field( qos_settings, intf, priorityId, base, field ):
    for prio in qos_settings.get('qosPriorities').get('list'):
        if prio.get('priorityId') == priorityId:
            return intf.get(base) * (prio.get(field)/100.0)
    debug("Unable to find %s for priority %i" % (field, priorityId))
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

def runSubprocess(cmd):
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell=True)
    result=[]
    for line in proc.stdout:
        result.append(line)
    return result


def flush_htb_rules( wan_intfs ):
    debug("Flushing HTB...")

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
        debug( "Flushing %s..." % dev )
        if dev != "utun":
            run("tc qdisc del dev %s root    2> /dev/null > /dev/null" % dev, ignore_errors=True)
            run("tc qdisc del dev %s ingress 2> /dev/null > /dev/null" % dev, ignore_errors=True)
                
def add_htb_rules( qos_settings, wan_intf ):
    debug( "Adding HTB for %s and %s..." % (wan_intf.get('systemDev'), wan_intf.get('imqDev')) )

    wan_dev = wan_intf.get('systemDev')
    imq_dev = wan_intf.get('imqDev')
    sfq = "sfq perturb 10"
    default_class = qos_settings.get('defaultPriority')
    wan_upload_bandwidth = wan_intf.get('uploadBandwidthKbps')
    wan_download_bandwidth = wan_intf.get('downloadBandwidthKbps')

    #
    # egress filtering
    #
    run("tc qdisc add dev %s root handle 1: htb default 1%i" % (wan_dev, default_class) )
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
        run("tc class add dev %s parent 1:1 classid 1:1%i htb %s %s quantum %i" % (wan_dev, i, reserved, limited, int(quantum)) ) 
        run("tc qdisc add dev %s parent 1:1%i handle 1%i: %s" % (wan_dev, i, i, sfq) )
        run("tc filter add dev %s parent 1: prio 1%i protocol ip u32 match mark 0x000%i0000 0x000F0000 flowid 1:1%i" % (wan_dev, i, i, i) )

    #
    # ingress filtering
    # ingress filtering is done via the IMQ interface
    #
    run("ifconfig %s up" % imq_dev)
    run("tc qdisc add dev %s root handle 1: htb default 1%i" % (imq_dev, default_class) )
    run("tc class add dev %s parent 1: classid 1:1 htb rate %ikbit" % (imq_dev,  wan_download_bandwidth) )
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
        run("tc class add dev %s parent 1:1 classid 1:1%i htb %s %s quantum %i" % (imq_dev, i, reserved, limited, int(quantum)) )
        run("tc qdisc add dev %s parent 1:1%i handle 1%i: %s" % (imq_dev, i, i, sfq) )
        run("tc filter add dev %s parent 1: prio 1%i protocol ip u32 match mark 0x000%i0000 0x000F0000 flowid 1:1%i" % (imq_dev, i, i, i) )
    
    # this is an attempt to share fairly between hosts (dst on imq)
    # it does not seem to work as expected
    # bug #8207
    # run("tc filter add dev %s pref 1 parent 1: protocol ip handle 1 flow hash keys nfct-src" % (wan_dev) )
    # run("tc filter add dev %s pref 1 parent 1: protocol ip handle 1 flow hash keys nfct-src" % (imq_dev) )
    # Maybe this: ?
    # run("tc filter add dev %s pref 1 parent 1: protocol ip handle 1 flow hash keys src" % (wan_dev) )
    # run("tc filter add dev %s pref 1 parent 1: protocol ip handle 1 flow hash keys dst" % (imq_dev) )

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
    
def statusToJSON(input):
    #Parse patterns for qos-service.py status output
    firstLine='interface: {} class {} {} {} rate {} ceil {} burst {} cburst {}'
    secondLine=' Sent {:d} bytes {:d} pkt (dropped {:d}, overlimits {:d} requeues {:d}) '
    thirdLine=' rate {} {} backlog {} {} requeues {:d} '
    fourthLine= ' lended: {:d} borrowed: {:d} giants: {:d}'
    lastLine=' tokens: {} ctokens:{}'
    priorityParser='parent {} leaf {} prio {:d}'
    indexMap={1:firstLine, 2:secondLine, 3:thirdLine, 4:fourthLine, 5:lastLine}
    priorityQueueToName = { '10:': '0 - Default','11:': '1 - Very High','12:': '2 - High', '13:':'3 - Medium','14:':'4 - Low','15:':'5 - Limited','16:':'6 - Limited More','17:':'7 - Limited Severely' }

    output = []
    count = 1
    entry = {}
    skipEntry=False
    for line in input:
        if count <= 5:
            res=parse.parse(indexMap[count],line)
            parsed = res.fixed
            if count == 1:
                entry['interface_name']=parsed[0]
                entry['burst']=parsed[len(parsed)-2]
                if 'prio' in parsed[3]:
                    skipEntry=False
                    prioParse = parse.parse(priorityParser, parsed[3])
                    val=prioParse.fixed
                    entry['priority']=priorityQueueToName[val[1]]
                if parsed[3]=='root':
                    skipEntry=True
            if count == 2:
                entry['sent']=str(parsed[0]) + ' bytes'
            if count == 3:
                entry['rate']=parsed[0]
            if count == 5:
                entry['tokens']=int(parsed[0])
                entry['ctokens']=int(parsed[1])
            count+=1
        else:
            if not skipEntry:
                output.append(dict(entry))
            entry.clear()
            count=1
            continue
    newlist = sorted(output, key=lambda k: k['priority'])
    return newlist
    

def status( qos_interfaces, wan_intfs ):

    json_objs = []
    for wan_intf in wan_intfs:
        result=''
        wan_dev = wan_intf.get('systemDev')
        imq_dev = wan_intf.get('imqDev')
        wan_name = wan_intf.get('name')
        result= runSubprocess( "tc -s class ls dev %s | sed \"s/^class/interface: %s Outbound class/\"" % (wan_dev, wan_name) )
        result.extend( runSubprocess( "tc -s class ls dev %s | sed \"s/^class/interface: %s Inbound class/\"" % (imq_dev, wan_name)))
        json_objs.extend( statusToJSON(result) )
       
        #run("echo ------ Qdisc  ------")
        #run("tc -s qdisc ls dev %s" % wan_dev)
        #run("tc -s qdisc ls dev %s" % imq_dev)
        #run("echo ------ Class  ------")
        #run("tc -s class ls dev %s" % wan_dev)
        #run("tc -s class ls dev %s" % imq_dev)
        #run("echo ------ Filter ------")
        #run("tc -s filter ls dev %s" % wan_dev)
        #run("tc -s filter ls dev %s" % imq_dev)
    print json_objs
        

def sessionsToJSON(input):
    #Parse patterns for qos-service.py sessions output
    parsePattern='proto {:^} state {:^} src {:^} dst {:^} src-port {:^d} dst-port {:^d} priority {:^d}'
    entryKeys=('proto','state','src','dst','src_port','dst_port','priority')
    output=[]
    entry={}
    for line in input:
        res=parse.parse(parsePattern,line[:-1])
        if res:
            parsed = res.fixed
            output.append(dict(zip(entryKeys,parsed)))
    return json.dumps(output)
    
        
        
def sessions( qos_interfaces, wan_intfs ):
    if "2.6.32" in platform.platform():
        result = runSubprocess( r"""cat /proc/net/ip_conntrack | grep -v '127.0.0.1' | grep tcp | sed 's/[a-z]*=//g' | awk '{printf "proto %s state %12s src %15s dst %15s src-port %5s dst-port %5s priority %x\n", $1, $4, $5, $6, $7, $8, rshift(and($18,0x000F0000),16)}'""")
        result.extend(runSubprocess( r"""cat /proc/net/ip_conntrack | grep -v '127.0.0.1' | grep udp | sed 's/\[.*\]//g' | sed 's/[a-z]*=//g' | awk '{printf "proto %s state           xx src %15s dst %15s src-port %5s dst-port %5s priority %x\n", $1, $4, $5, $6, $7, rshift(and($16,0x000F0000),16)}'"""))
    else:
        result = runSubprocess( r"""cat /proc/net/ip_conntrack | grep -v '127.0.0.1' | grep tcp | sed 's/\[.*\]//g' | sed 's/[a-z]*=//g' | awk '{printf "proto %s state %12s src %15s dst %15s src-port %5s dst-port %5s priority %x\n", $1, $4, $5, $6, $7, $8, rshift(and($13,0x000F0000),16)}'""")
        result.extend(runSubprocess( r"""cat /proc/net/ip_conntrack | grep -v '127.0.0.1' | grep udp | sed 's/\[.*\]//g' | sed 's/[a-z]*=//g' | awk '{printf "proto %s state           xx src %15s dst %15s src-port %5s dst-port %5s priority %x\n", $1, $4, $5, $6, $7, rshift(and($12,0x000F0000),16)}'"""))
    return result
    
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
    print sessionsToJSON( sessions( qos_settings, wan_intfs ) )
elif action == "sessions2":
    for i in sessions( qos_settings, wan_intfs ):
        print i.strip()
else:
    print "Unknown argument: %s" % action
    usage

sys.exit(0)


