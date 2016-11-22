import os
import sys
import subprocess
import datetime
import traceback
import re
from netd.network_util import NetworkUtil
from netd.iptables_util import IptablesUtil

# This class is responsible for writing /etc/untangle-netd/iptables-rules.d/300-qos
# and others based on the settings object passed from sync-settings.py
class QosManager:
    bypassMarkMask = 0x01000000
    qosFilename = "/etc/untangle-netd/iptables-rules.d/300-qos"
    srcInterfaceMarkMask = 0x00ff
    file = None

    def find_priority( self, qosPriorities, priorityId ):
        for qosPriority in qosPriorities:
            if qosPriority.get('priorityId') == priorityId:
                return qosPriority
        return None

    def systemDev_variable_name( self, intfSettings ):
        return intfSettings['systemDev'].replace(".","_")

    # Returns true if the interface is QoS eligible
    # QoS is run on WAN interfaces ( excluding VLANs )
    def qosed_interface( self, intfSettings ):
        if ( intfSettings == None ):
            return False
        if ( intfSettings.get('configType') == None or intfSettings.get('configType') != 'ADDRESSED' ):
            return False
        if ( intfSettings.get('isWan') == None or not intfSettings.get('isWan') ):
            return False
        # if ( intfSettings.get('isVlanInterface') != None and intfSettings.get('isVlanInterface') ):
        #     return False;
        return True

    def write_qos_rule( self, qos_rule, verbosity=0 ):

        if 'enabled' in qos_rule and not qos_rule['enabled']:
            return
        if 'conditions' not in qos_rule or 'list' not in qos_rule['conditions']:
            return
        if 'ruleId' not in qos_rule:
            return

        if 'priority' in qos_rule:
            target = " -g qos-class%i " % qos_rule['priority']
        else:
            print "ERROR: invalid qos priority: %s" + str(qos_rule)
            return

        description = "QoS Custom Rule #%i" % int(qos_rule['ruleId'])
        iptables_conditions = IptablesUtil.conditions_to_iptables_string( qos_rule['conditions']['list'], description, verbosity );

        iptables_commands = [ "${IPTABLES} -t mangle -A qos-rules -m mark --mark 0x%X/0x%X " % (self.bypassMarkMask,self.bypassMarkMask) + ipt + target for ipt in iptables_conditions ]

        self.file.write("# %s\n" % description);
        for cmd in iptables_commands:
            self.file.write(cmd + "\n")
        self.file.write("\n");

        return

    def write_qos_custom_rules( self, settings, verbosity=0 ):

        if settings == None or 'qosRules' not in settings or 'list' not in settings['qosRules']:
            print "ERROR: Missing QoS Custom Rules"
            return
        
        qos_rules = settings['qosRules']['list'];

        for qos_rule in qos_rules:
            try:
                self.write_qos_rule( qos_rule, verbosity );
            except Exception,e:
                traceback.print_exc(e)

    def write_qos_hook( self, settings, prefix, verbosity ):

        if settings == None or settings.get('interfaces') == None or settings.get('interfaces').get('list') == None:
            return;
        if settings.get('qosSettings') == None:
            return;
        qosSettings = settings.get('qosSettings')
        interfaces = settings.get('interfaces').get('list')

        filename = prefix + self.qosFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        self.file = open( filename, "w+" )
        file = self.file
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        if not qosSettings.get('qosEnabled'):
            file.write("# Stop QoS \n")
            file.write("/usr/share/untangle-netd/bin/qos-service.py stop" + "\n")
            file.flush()
            file.close()
            os.system("chmod a+x %s" % filename)
            if verbosity > 0: print "QosManager: Wrote %s" % filename
            return

        # Write the settings JSON as a comment at top of script
        # We do this because the actual logic reads the settings directly in qos-service
        # But we only restart networking when something changes, so if QoS settings change
        # we need something to change in the file so it restarts networking
        # NGFW-10116
        #
        # FIXME
        # The proper fix for this would be to rewrite qos-service so that it doesn't read the settings
        # directly. The logic should be in the iptables-rules.d script like everything else
        # and should be written when settings are saved.
        file.write("# QoS Settings: \n")
        file.write(("# %s" % str(qosSettings)) + "\n")
        file.write("\n\n");

        file.write("# Start QoS \n")
        file.write("/usr/share/untangle-netd/bin/qos-service.py start" + "\n")
        file.write("\n\n");

        file.write("# Create restore-qos-mark chain" + "\n");
        file.write("${IPTABLES} -t mangle -N restore-qos-mark 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F restore-qos-mark >/dev/null 2>&1" + "\n");
        file.write("\n");

        file.write("# Create qos-imq chain" + "\n");
        file.write("${IPTABLES} -t mangle -N qos-imq 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F qos-imq >/dev/null 2>&1" + "\n");
        file.write("\n");

        file.write("# Create qos-rules chain" + "\n");
        file.write("${IPTABLES} -t mangle -N qos-rules 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F qos-rules >/dev/null 2>&1" + "\n");
        file.write("\n");

        file.write("# Call restore-qos-mark chain from postrouting-qos chain in mangle" + "\n");
        file.write("${IPTABLES} -t mangle -D postrouting-qos -m comment --comment \"Restore QoS Mark\" -j restore-qos-mark >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t mangle -A postrouting-qos -m comment --comment \"Restore QoS Mark\" -j restore-qos-mark" + "\n");
        file.write("${IPTABLES} -t mangle -D postrouting-qos -m conntrack --ctstate NEW -m comment --comment \"Call QoS Rules\" -j qos-rules >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t mangle -A postrouting-qos -m conntrack --ctstate NEW -m comment --comment \"Call QoS Rules\" -j qos-rules" + "\n");
        file.write("\n");

        file.write("# Call restore-qos-mark chain from prerouting-qos chain in mangle" + "\n");
        file.write("${IPTABLES} -t mangle -D prerouting-qos -m comment --comment \"Restore QoS Mark\" -j restore-qos-mark >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t mangle -A prerouting-qos -m comment --comment \"Restore QoS Mark\" -j restore-qos-mark" + "\n");
        file.write("${IPTABLES} -t mangle -D prerouting-qos -m conntrack --ctstate NEW -m comment --comment \"Call QoS Rules\" -j qos-rules >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t mangle -A prerouting-qos -m conntrack --ctstate NEW -m comment --comment \"Call QoS Rules\" -j qos-rules" + "\n");
        file.write("\n");

        file.write("# Call qos-imq chain from prerouting-qos chain in mangle" + "\n");
        file.write("${IPTABLES} -t mangle -D prerouting-qos -m comment --comment \"Do inbound QoS via IMQ\" -j qos-imq >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t mangle -A prerouting-qos -m comment --comment \"Do inbound QoS via IMQ\" -j qos-imq" + "\n");
        file.write("\n");

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
        file.write("\n");

        file.write("# Insert IMQ rules for each WAN interface" + "\n");
        for intfSettings in interfaces:
            if self.qosed_interface( intfSettings ):
                imqDev = intfSettings.get('imqDev')
                devnumstr = imqDev.replace("imq","")
                file.write("${IPTABLES} -t mangle -A qos-imq -m mark --mark 0x%04X/0x%04X -j IMQ --todev %s" % (intfSettings['interfaceId'], self.srcInterfaceMarkMask, devnumstr) + "\n")
        file.write("\n");

        if qosSettings['pingPriority'] != None and qosSettings['pingPriority'] != 0:
            file.write("# Ping Priority " + "\n")
            file.write("${IPTABLES} -t mangle -A qos-rules -p icmp --icmp-type echo-request -g qos-class%i -m comment --comment \"set ping priority\"" % qosSettings['pingPriority'] + "\n")
            file.write("${IPTABLES} -t mangle -A qos-rules -p icmp --icmp-type echo-reply   -g qos-class%i -m comment --comment \"set ping priority\"" % qosSettings['pingPriority'] + "\n")
            file.write("\n");

        if qosSettings['sshPriority'] != None and qosSettings['sshPriority'] != 0:
            file.write("# Ssh Priority " + "\n")
            file.write("${IPTABLES} -t mangle -A qos-rules -p tcp --dport 22 -g qos-class%i -m comment --comment \"set SSH priority\"" % qosSettings['sshPriority'] + "\n")
            file.write("\n");

        if qosSettings['dnsPriority'] != None and qosSettings['dnsPriority'] != 0:
            file.write("# Dns Priority " + "\n")
            file.write("${IPTABLES} -t mangle -A qos-rules -p udp --dport 53 -g qos-class%i -m comment --comment \"set DNS priority\"" % qosSettings['dnsPriority'] + "\n")
            file.write("${IPTABLES} -t mangle -A qos-rules -p tcp --dport 53 -g qos-class%i -m comment --comment \"set DNS priority\"" % qosSettings['dnsPriority'] + "\n")
            file.write("\n");

        if qosSettings['openvpnPriority'] != None and qosSettings['openvpnPriority'] != 0:
            file.write("# Openvpn Priority " + "\n")
            file.write("${IPTABLES} -t mangle -A qos-rules -p udp --dport 1194 -g qos-class%i -m comment --comment \"set openvpn priority\"" % qosSettings['openvpnPriority'] + "\n")
            file.write("${IPTABLES} -t mangle -A qos-rules -p tcp --dport 1194 -g qos-class%i -m comment --comment \"set openvpn priority\"" % qosSettings['openvpnPriority'] + "\n")
            file.write("\n");

        self.write_qos_custom_rules( qosSettings, verbosity)

        if qosSettings['defaultPriority'] != None and qosSettings['defaultPriority'] != 0:
            file.write("# Default Priority " + "\n")
            file.write("${IPTABLES} -t mangle -A qos-rules -m mark     --mark 0/0x000F0000 -g qos-class%i -m comment --comment \"set default priority if unset\"" % qosSettings['defaultPriority'] + "\n")
            file.write("${IPTABLES} -t mangle -A qos-rules -m connmark --mark 0/0x000F0000 -g qos-class%i -m comment --comment \"set default priority if unset\"" % qosSettings['defaultPriority'] + "\n")
            file.write("\n");

        file.flush()
        file.close()

        if verbosity > 0: print "QosManager: Wrote %s" % filename

        return


    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "QosManager: sync_settings()"
        
        self.write_qos_hook( settings, prefix, verbosity )

        return
