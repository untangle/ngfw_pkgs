import os
import sys
import stat
import subprocess
import datetime
import traceback
import re
from sync.network_util import NetworkUtil
from sync.iptables_util import IptablesUtil
from sync import registrar,Manager

# This class is responsible for writing /etc/untangle/iptables-rules.d/300-qos
# and others based on the settings object passed from sync-settings


class QosManager(Manager):
    bypass_mark_mask = 0x01000000
    qos_filename = "/etc/untangle/iptables-rules.d/300-qos"
    src_interface_mark_mask = 0x00ff
    file = None

    def initialize(self):
        registrar.register_settings_file("network", self)
        registrar.register_file(self.qos_filename, "restart-iptables", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        self.write_qos_hook(settings_file.settings, prefix)
        return

    def find_priority(self, qosPriorities, priorityId):
        for qosPriority in qosPriorities:
            if qosPriority.get('priorityId') == priorityId:
                return qosPriority
        return None

    # Returns true if the interface is QoS eligible
    # QoS is run on WAN interfaces ( excluding VLANs )
    def qosed_interface(self, intfSettings):
        if (intfSettings == None):
            return False
        if (intfSettings.get('configType') == None or intfSettings.get('configType') != 'ADDRESSED'):
            return False
        if (intfSettings.get('isWan') == None or not intfSettings.get('isWan')):
            return False
        # if ( intfSettings.get('isVlanInterface') != None and intfSettings.get('isVlanInterface') ):
        #     return False;
        return True

    def write_qos_rule(self, qos_rule):
        if 'enabled' in qos_rule and not qos_rule['enabled']:
            return
        if 'conditions' not in qos_rule:
            return
        if 'ruleId' not in qos_rule:
            return

        if 'priority' in qos_rule:
            target = " -g qos-class%i " % qos_rule['priority']
        else:
            print("ERROR: invalid qos priority: %s" + str(qos_rule))
            return

        description = "QoS Custom Rule #%i" % int(qos_rule['ruleId'])
        commands = IptablesUtil.conditions_to_prep_commands(qos_rule['conditions'], description)
        iptables_conditions = IptablesUtil.conditions_to_iptables_string(qos_rule['conditions'], description)
        commands += ["${IPTABLES} -t mangle -A qos-rules -m mark --mark 0x%X/0x%X " % (self.bypass_mark_mask, self.bypass_mark_mask) + ipt + target for ipt in iptables_conditions]

        self.file.write("# %s\n" % description)
        for cmd in commands:
            self.file.write(cmd + "\n")
        self.file.write("\n")

        return

    def write_qos_custom_rules(self, settings):
        if 'qosRules' not in settings:
            print("ERROR: Missing QoS Custom Rules")
            return

        qos_rules = settings['qosRules']

        for qos_rule in qos_rules:
            try:
                self.write_qos_rule(qos_rule)
            except Exception as e:
                traceback.print_exc()

    def qos_priorities(self, qos_settings):
        return [1, 2, 3, 4, 5, 6, 7]

    def qos_priority_field(self, qos_settings, intf, priorityId, base, field):
        for prio in qos_settings.get('qosPriorities'):
            if prio.get('priorityId') == priorityId:
                return intf.get(base) * (prio.get(field)/100.0)
        debug("Unable to find %s for priority %i" % (field, priorityId))
        return None

    def qos_priority_upload_reserved(self, qos_settings, intf, priorityId):
        return self.qos_priority_field(qos_settings, intf, priorityId, 'uploadBandwidthKbps', 'uploadReservation')

    def qos_priority_upload_limit(self, qos_settings, intf, priorityId):
        return self.qos_priority_field(qos_settings, intf, priorityId, 'uploadBandwidthKbps', 'uploadLimit')

    def qos_priority_download_reserved(self, qos_settings, intf, priorityId):
        return self.qos_priority_field(qos_settings, intf, priorityId, 'downloadBandwidthKbps', 'downloadReservation')

    def qos_priority_download_limit(self, qos_settings, intf, priorityId):
        return self.qos_priority_field(qos_settings, intf, priorityId, 'downloadBandwidthKbps', 'downloadLimit')

    def get_queue_discipline_str(self, qos_settings):
        queue_discipline = qos_settings.get('queueDiscipline')
        if queue_discipline == "pfifo":
            queue_discipline_str = "pfifo"
        elif queue_discipline == "fq_codel":
            queue_discipline_str = "fq_codel"
        elif queue_discipline == "sfq":
            queue_discipline_str = "sfq perturb 10"
        else:
            queue_discipline_str = "fq_codel"  # default if null
        return queue_discipline_str

    def add_htb_rules(self, file, qos_settings, wan_intf):
        wan_dev = wan_intf.get('systemDev')
        imq_dev = wan_intf.get('imqDev')
        default_class = qos_settings.get('defaultPriority')
        wan_upload_bandwidth = wan_intf.get('uploadBandwidthKbps')
        wan_download_bandwidth = wan_intf.get('downloadBandwidthKbps')
        queue_discipline = self.get_queue_discipline_str(qos_settings)

        #
        # egress filtering
        #
        r2q = 10
        quantum = wan_upload_bandwidth * 1024 / (8 * r2q)
        if quantum <= 1000 or quantum >= 20000:
            # quantum need between 1000 and 20000
            # when it is out of range, use quantum as 10000 to calculate the r2q value
            r2q = wan_upload_bandwidth * 1024 / 80000

        if r2q == 10:
            file.write("tc qdisc add dev %s root handle 1: htb default 1%i\n" % (wan_dev, default_class))
        else:
            file.write("tc qdisc add dev %s root handle 1: htb default 1%i r2q %i\n" % (wan_dev, default_class, r2q))

        file.write("tc class add dev %s parent 1: classid 1:1 htb rate %ikbit\n" % (wan_dev, wan_upload_bandwidth))
        for i in self.qos_priorities(qos_settings):
            upload_reserved = self.qos_priority_upload_reserved(qos_settings, wan_intf, i)
            upload_limit = self.qos_priority_upload_limit(qos_settings, wan_intf, i)

            if upload_limit == None and upload_reserved == None:
                continue

            if upload_reserved == None:
                # should never happen as UPLOAD_RESERVED must be >0
                # Can't provide no reservation,TC says '"rate" is required'
                upload_reserved = 100
                reserved = " rate %ikbit " % upload_reserved
            else:
                reserved = " rate %ikbit " % upload_reserved

            if upload_limit == None:
                limited = " ceil 99999999999kbit"
            else:
                limited = " ceil %ikbit " % upload_limit

            quantum = (upload_reserved / wan_upload_bandwidth) * 60000
            if quantum < 2000:
                quantum = 2000

            # egress outbound hierarchical token bucket for class $i - need quantum or prio?
            file.write("tc class add dev %s parent 1:1 classid 1:1%i htb %s %s quantum %i\n" % (wan_dev, i, reserved, limited, int(quantum)))
            file.write("tc qdisc add dev %s parent 1:1%i handle 1%i: %s\n" % (wan_dev, i, i, queue_discipline))
            file.write("tc filter add dev %s parent 1: prio 1%i protocol ip u32 match mark 0x000%i0000 0x000F0000 flowid 1:1%i\n" % (wan_dev, i, i, i))

        file.write("tc filter add dev %s parent 1: prio %i protocol ip u32 match ip dst 0.0.0.0/0 flowid 1:1%i\n" % (wan_dev, 20, default_class))

        #
        # ingress filtering
        # ingress filtering is done via the IMQ interface
        #
        file.write("ifconfig %s up\n" % imq_dev)
        r2q = 10
        quantum = wan_download_bandwidth * 1024 / (8 * r2q)
        if quantum <= 1000 or quantum >= 20000:
            # quantum need between 1000 and 20000
            # when it is out of range, use quantum as 10000 to calculate the r2q value
            r2q = wan_download_bandwidth * 1024 / 80000

        if r2q == 10:
            file.write("tc qdisc add dev %s root handle 1: htb default 1%i\n" % (imq_dev, default_class))
        else:
            file.write("tc qdisc add dev %s root handle 1: htb default 1%i r2q %i\n" % (imq_dev, default_class, r2q))

        file.write("tc class add dev %s parent 1: classid 1:1 htb rate %ikbit\n" % (imq_dev,  wan_download_bandwidth))
        for i in self.qos_priorities(qos_settings):
            download_reserved = self.qos_priority_download_reserved(qos_settings, wan_intf, i)
            download_limit = self.qos_priority_download_limit(qos_settings, wan_intf, i)

            if download_limit == None and download_reserved == None:
                continue

            if download_reserved == None:
                # should never happen as DOWNLOAD_RESERVED must be >0
                # Can't provide no reservation,TC says '"rate" is required'
                download_reserved = 100
                reserved = " rate 100kbit "
            else:
                reserved = " rate %ikbit " % download_reserved

            if download_limit == None:
                limited = " ceil 99999999999kbit"
            else:
                limited = " ceil %ikbit " % download_limit

            quantum = (download_reserved / wan_download_bandwidth) * 60000
            if quantum < 2000:
                quantum = 2000

            # ingress inbound hierarchical token bucket for class $i - need quantum or prio?
            file.write("tc class add dev %s parent 1:1 classid 1:1%i htb %s %s quantum %i\n" % (imq_dev, i, reserved, limited, int(quantum)))
            file.write("tc qdisc add dev %s parent 1:1%i handle 1%i: %s\n" % (imq_dev, i, i, queue_discipline))
            file.write("tc filter add dev %s parent 1: prio 1%i protocol ip u32 match mark 0x000%i0000 0x000F0000 flowid 1:1%i\n" % (imq_dev, i, i, i))

        file.write("tc filter add dev %s parent 1: prio %i protocol ip u32 match ip dst 0.0.0.0/0 flowid 1:1%i\n" % (imq_dev, 20, default_class))

        # this is an attempt to share fairly between hosts (dst on imq)
        # it does not seem to work as expected
        # bug #8207
        # file.write("tc filter add dev %s pref 1 parent 1: protocol ip handle 1 flow hash keys nfct-src\n" % (wan_dev) )
        # file.write("tc filter add dev %s pref 1 parent 1: protocol ip handle 1 flow hash keys nfct-src\n" % (imq_dev) )
        # Maybe this: ?
        # file.write("tc filter add dev %s pref 1 parent 1: protocol ip handle 1 flow hash keys src\n" % (wan_dev) )
        # file.write("tc filter add dev %s pref 1 parent 1: protocol ip handle 1 flow hash keys dst\n" % (imq_dev) )

    def write_qos_hook(self, settings, prefix):
        if settings.get('qosSettings') == None:
            return
        qos_settings = settings.get('qosSettings')
        interfaces = settings.get('interfaces')
        wan_intfs = []
        wan_system_devs = []
        wan_imq_devs = []
        for intf in interfaces:
            if intf.get('isWan'):
                wan_system_devs.append(intf.get('systemDev'))
                wan_imq_devs.append(intf.get('imqDev'))
                wan_intfs.append(intf)

        filename = prefix + self.qos_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.file = open(filename, "w+")
        file = self.file
        file.write("#!/bin/dash")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        file.write("IPTABLES=${IPTABLES:-iptables}" + "\n")
        file.write("\n\n")

        file.write("# Stop QoS \n")

        file.write("# delete qdiscs \n")
        for dev in wan_system_devs:
            file.write("tc qdisc del dev %s root    2> /dev/null > /dev/null \n" % dev)
            file.write("tc qdisc del dev %s ingress 2> /dev/null > /dev/null \n" % dev)
        for dev in wan_imq_devs:
            file.write("tc qdisc del dev %s root    2> /dev/null > /dev/null \n" % dev)
            file.write("tc qdisc del dev %s ingress 2> /dev/null > /dev/null \n" % dev)
        file.write("\n\n")

        file.write("# delete any remaining qdiscs \n")
        file.write("tc qdisc show | awk '{print $5}' | sort | uniq | while read dev ; do\n")
        file.write("    tc qdisc del dev $dev root    2> /dev/null > /dev/null \n")
        file.write("    tc qdisc del dev $dev ingress 2> /dev/null > /dev/null \n")
        file.write("done\n")
        file.write("\n\n")

        if not qos_settings.get('qosEnabled'):
            # if not driver default - set qdisc
            if qos_settings.get('queueDiscipline') != 'driver':
                queue_discipline = self.get_queue_discipline_str(qos_settings)
                file.write("# set qdiscs \n")
                file.write("tc qdisc show | awk '{print $5}' | sort | uniq | while read dev ; do\n")
                file.write("    tc qdisc add dev $dev root %s \n" % queue_discipline)
                #file.write( "    tc qdisc add dev $dev ingress %s \n" % queue_discipline)
                file.write("done\n")
                file.write("\n\n")

            file.flush()
            file.close()
            os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
            print("QosManager: Wrote %s" % filename)
            return

        file.write("# Start QoS \n")
        file.write("modprobe imq\n")
        for wan_intf in wan_intfs:
            self.add_htb_rules(file, qos_settings, wan_intf)

        file.write("\n\n")

        file.write("# Create restore-qos-mark chain" + "\n")
        file.write("${IPTABLES} -t mangle -N restore-qos-mark 2>/dev/null" + "\n")
        file.write("${IPTABLES} -t mangle -F restore-qos-mark >/dev/null 2>&1" + "\n")
        file.write("\n")

        file.write("# Create qos-imq chain" + "\n")
        file.write("${IPTABLES} -t mangle -N qos-imq 2>/dev/null" + "\n")
        file.write("${IPTABLES} -t mangle -F qos-imq >/dev/null 2>&1" + "\n")
        file.write("\n")

        file.write("# Create qos-rules chain" + "\n")
        file.write("${IPTABLES} -t mangle -N qos-rules 2>/dev/null" + "\n")
        file.write("${IPTABLES} -t mangle -F qos-rules >/dev/null 2>&1" + "\n")
        file.write("\n")

        file.write("# Call restore-qos-mark chain from postrouting-qos chain in mangle" + "\n")
        file.write("${IPTABLES} -t mangle -D postrouting-qos -m comment --comment \"Restore QoS Mark\" -j restore-qos-mark >/dev/null 2>&1" + "\n")
        file.write("${IPTABLES} -t mangle -A postrouting-qos -m comment --comment \"Restore QoS Mark\" -j restore-qos-mark" + "\n")
        file.write("${IPTABLES} -t mangle -D postrouting-qos -m conntrack --ctstate NEW -m comment --comment \"Call QoS Rules\" -j qos-rules >/dev/null 2>&1" + "\n")
        file.write("${IPTABLES} -t mangle -A postrouting-qos -m conntrack --ctstate NEW -m comment --comment \"Call QoS Rules\" -j qos-rules" + "\n")
        file.write("\n")

        file.write("# Call restore-qos-mark chain from prerouting-qos chain in mangle" + "\n")
        file.write("${IPTABLES} -t mangle -D prerouting-qos -m comment --comment \"Restore QoS Mark\" -j restore-qos-mark >/dev/null 2>&1" + "\n")
        file.write("${IPTABLES} -t mangle -A prerouting-qos -m comment --comment \"Restore QoS Mark\" -j restore-qos-mark" + "\n")
        file.write("${IPTABLES} -t mangle -D prerouting-qos -m conntrack --ctstate NEW -m comment --comment \"Call QoS Rules\" -j qos-rules >/dev/null 2>&1" + "\n")
        file.write("${IPTABLES} -t mangle -A prerouting-qos -m conntrack --ctstate NEW -m comment --comment \"Call QoS Rules\" -j qos-rules" + "\n")
        file.write("\n")

        file.write("# Call qos-imq chain from prerouting-qos chain in mangle" + "\n")
        file.write("${IPTABLES} -t mangle -D prerouting-qos -m comment --comment \"Do inbound QoS via IMQ\" -j qos-imq >/dev/null 2>&1" + "\n")
        file.write("${IPTABLES} -t mangle -A prerouting-qos -m comment --comment \"Do inbound QoS via IMQ\" -j qos-imq" + "\n")
        file.write("\n")

        file.write(r"""
# Flush qos-classX chains
for i in 1 2 3 4 5 6 7 ; do 
    ${IPTABLES} -t mangle -F qos-class${i} >/dev/null 2>&1
done""")

        file.write(r"""
# Create special targets for both marking the current packet and the rest of the session via connmark
for i in 1 2 3 4 5 6 7 ; do 
    ${IPTABLES} -t mangle -N qos-class${i} >/dev/null 2>&1
    ${IPTABLES} -t mangle -F qos-class${i} 
    ${IPTABLES} -t mangle -A qos-class${i} -j MARK --set-mark 0x000${i}0000/0x000F0000
    ${IPTABLES} -t mangle -A qos-class${i} -j CONNMARK --set-mark 0x000${i}0000/0x000F0000
done
""")

        file.write(r"""
# If we see a UDP mark on a packet immediately save it to the conntrack before further processing
# We do this because userspace may decide to mark a packet and we need to save it to conntrack
${IPTABLES} -t mangle -I restore-qos-mark -p udp -m mark ! --mark 0x00000000/0x000F0000 -j CONNMARK --save-mark --mask 0x000F0000 -m comment --comment "save non-zero QoS mark"
    
# Also need to do this in the tune table because that is where UDP packets are QUEUEd
# if there is a non-zero mark there we should save it. After the UVM is queue the packet it will release it with NF_REPEAT
# and so this rule will save the new QoS mark
${IPTABLES} -t tune -I POSTROUTING -p udp -m mark ! --mark 0x00000000/0x000F0000 -j CONNMARK --save-mark --mask 0x000F0000 -m comment --comment "save non-zero QoS mark"
KERNVER=$(uname -r | awk -F. '{ printf("%02d%02d%02d\n",$1,$2,$3); }')
ORIGVER=31049

if [ "$KERNVER" -ge "$ORIGVER" ]; then
${IPTABLES} -t mangle -A restore-qos-mark -m conntrack  ! --ctstate UNTRACKED -j CONNMARK --restore-mark --mask 0x000F0000 -m comment --comment "restore QoS mark"
else
# Using -m state --state instead of -m conntrack --ctstate ref: http://markmail.org/thread/b7eg6aovfh4agyz7
${IPTABLES} -t mangle -A restore-qos-mark -m state ! --state UNTRACKED -j CONNMARK --restore-mark --mask 0x000F0000 -m comment --comment "restore QoS mark"
fi

""")
        file.write("\n")

        file.write("# Insert IMQ rules for each WAN interface" + "\n")
        for intfSettings in interfaces:
            if self.qosed_interface(intfSettings):
                imqDev = intfSettings.get('imqDev')
                devnumstr = imqDev.replace("imq", "")
                file.write("${IPTABLES} -t mangle -A qos-imq -m mark --mark 0x%04X/0x%04X -j IMQ --todev %s" % (intfSettings['interfaceId'], self.src_interface_mark_mask, devnumstr) + "\n")
        file.write("\n")

        if qos_settings['pingPriority'] != None and qos_settings['pingPriority'] != 0:
            file.write("# Ping Priority " + "\n")
            file.write("${IPTABLES} -t mangle -A qos-rules -p icmp --icmp-type echo-request -g qos-class%i -m comment --comment \"set ping priority\"" % qos_settings['pingPriority'] + "\n")
            file.write("${IPTABLES} -t mangle -A qos-rules -p icmp --icmp-type echo-reply   -g qos-class%i -m comment --comment \"set ping priority\"" % qos_settings['pingPriority'] + "\n")
            file.write("\n")

        if qos_settings['sshPriority'] != None and qos_settings['sshPriority'] != 0:
            file.write("# Ssh Priority " + "\n")
            file.write("${IPTABLES} -t mangle -A qos-rules -p tcp --dport 22 -g qos-class%i -m comment --comment \"set SSH priority\"" % qos_settings['sshPriority'] + "\n")
            file.write("\n")

        if qos_settings['dnsPriority'] != None and qos_settings['dnsPriority'] != 0:
            file.write("# Dns Priority " + "\n")
            file.write("${IPTABLES} -t mangle -A qos-rules -p udp --dport 53 -g qos-class%i -m comment --comment \"set DNS priority\"" % qos_settings['dnsPriority'] + "\n")
            file.write("${IPTABLES} -t mangle -A qos-rules -p tcp --dport 53 -g qos-class%i -m comment --comment \"set DNS priority\"" % qos_settings['dnsPriority'] + "\n")
            file.write("\n")

        if qos_settings['openvpnPriority'] != None and qos_settings['openvpnPriority'] != 0:
            file.write("# Openvpn Priority " + "\n")
            file.write("${IPTABLES} -t mangle -A qos-rules -p udp --dport 1194 -g qos-class%i -m comment --comment \"set openvpn priority\"" % qos_settings['openvpnPriority'] + "\n")
            file.write("${IPTABLES} -t mangle -A qos-rules -p tcp --dport 1194 -g qos-class%i -m comment --comment \"set openvpn priority\"" % qos_settings['openvpnPriority'] + "\n")
            file.write("\n")

        self.write_qos_custom_rules(qos_settings)

        if qos_settings['defaultPriority'] != None and qos_settings['defaultPriority'] != 0:
            file.write("# Default Priority " + "\n")
            file.write("${IPTABLES} -t mangle -A qos-rules -m mark     --mark 0/0x000F0000 -g qos-class%i -m comment --comment \"set default priority if unset\"" % qos_settings['defaultPriority'] + "\n")
            file.write("${IPTABLES} -t mangle -A qos-rules -m connmark --mark 0/0x000F0000 -g qos-class%i -m comment --comment \"set default priority if unset\"" % qos_settings['defaultPriority'] + "\n")
            file.write("\n")

        file.flush()
        file.close()

        print("QosManager: Wrote %s" % filename)

        return


registrar.register_manager(QosManager())
