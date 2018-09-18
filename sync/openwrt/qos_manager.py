import os
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar

# This class is responsible for writing FIXME
# based on the settings object passed from sync-settings
class QosManager:
    qos_rules_sys_filename = "/etc/config/nftables-rules.d/300-qos-rules-sys"

    def initialize(self):
        registrar.register_file(self.qos_rules_sys_filename, "restart-qos", self)
        pass

    def create_settings(self, settings, prefix, delete_list, filename, verbosity=0):
        print("%s: Initializing settings" % self.__class__.__name__)
        settings['qos'] = {}
        settings['qos']['qosEnabled'] = False
        settings['qos']['defaultPriority'] = 3
        pass

    def write_qos_rules_sys_file(self, settings, prefix, verbosity):
        filename = prefix + self.qos_rules_sys_filename
        file_dir = os.path.dirname( filename )
        if not os.path.exists( file_dir ):
            os.makedirs( file_dir )

        file = open( filename, "w+" )
        file.write("#!/bin/sh");
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n")
        file.write("nft delete table inet qos 2>/dev/null || true\n")
        file.write("\n")
        file.write("tc qdisc show | awk '{print $5}' | sort | uniq | while read dev ; do\n")
        file.write("\ttc qdisc del dev $dev root 2> /dev/null > /dev/null\n")
        file.write("\ttc qdisc del dev $dev ingress 2> /dev/null > /dev/null\n")
        file.write("done\n")
        file.write("\n")
        file.write("find /sys/class/net -type l -name ifb* | cut -d '/' -f 5 | sort | uniq | while read dev ; do\n")
        file.write("\tip link set dev $dev down 2> /dev/null > /dev/null\n")
        file.write("\tip link delete dev $dev type ifb 2> /dev/null > /dev/null\n")
        file.write("done\n")
        file.write("\n")

        try:
            qos = settings['qos']
            if qos.get('qosEnabled'):

                file.write("nft add table inet qos\n")
                file.write("nft add chain inet qos restore-priority-mark\n")
                file.write("nft add rule inet qos restore-priority-mark meta mark and 0xff0000 == 0x40000 ct mark set ct mark and 0xff00ffff or 0x40000 ip dscp set cs1 counter\n")
                file.write("nft add rule inet qos restore-priority-mark meta mark and 0xff0000 == 0x30000 ct mark set ct mark and 0xff00ffff or 0x30000 ip dscp set cs0 counter\n")
                file.write("nft add rule inet qos restore-priority-mark meta mark and 0xff0000 == 0x20000 ct mark set ct mark and 0xff00ffff or 0x20000 ip dscp set cs2 counter\n")
                file.write("nft add rule inet qos restore-priority-mark meta mark and 0xff0000 == 0x10000 ct mark set ct mark and 0xff00ffff or 0x10000 ip dscp set cs7 counter\n")
                file.write("nft add chain inet qos postrouting-qos \"{ type filter hook postrouting priority 50 ; }\"\n")
                file.write("nft add rule inet qos postrouting-qos meta mark and 0xff0000 == 0x00000 meta mark set mark or 0x%s0000\n" % ('{:02x}'.format(qos.get('defaultPriority'))))
                file.write("nft add rule inet qos postrouting-qos jump restore-priority-mark\n")

                interfaces = settings.get('network').get('interfaces')
                for intf in interfaces:
                    if intf.get('wan'):
                        file.write("# qos for %i\n" % intf.get('interfaceId'))
                        file.write("\n")

                        file.write("# create an ifb device %i\n" % intf.get('interfaceId'))
                        file.write("ip link set dev ifb4%s down 2> /dev/null\n" % intf.get('device'))
                        file.write("ip link delete ifb4%s type ifb 2> /dev/null\n" % intf.get('device'))
                        file.write("ip link add name ifb4%s type ifb\n" % intf.get('device'))
                        file.write("\n")

                        file.write("# egress %i\n" % intf.get('interfaceId'))
                        file.write("tc qdisc del dev %s root 2> /dev/null\n" % intf.get('device'))
                        file.write("tc qdisc add dev %s root cake bandwidth %skbit diffserv4\n" % (intf.get('device'),intf.get('uploadKbps')))
                        file.write("\n")

                        file.write("# ingress %i\n" % intf.get('interfaceId'))
                        file.write("tc qdisc del dev %s handle ffff: ingress 2> /dev/null\n" % intf.get('device'))
                        file.write("tc qdisc add dev %s handle ffff: ingress\n" % intf.get('device'))
                        file.write("\n")

                        file.write("tc qdisc del dev ifb4%s root 2> /dev/null\n" % intf.get('device'))
                        file.write("tc qdisc add dev ifb4%s root cake bandwidth %skbit diffserv4\n" % (intf.get('device'),intf.get('downloadKbps')))
                        file.write("\n")

                        file.write("# bring up ifb device %i\n" % intf.get('interfaceId'))
                        file.write("ip link set dev ifb4%s up\n" % intf.get('device'))
                        file.write("\n")

                        file.write("tc filter add dev %s parent ffff: protocol ip prio 1 u32 match u32 0 0 flowid :1 action connmark action pedit munge ip tos set 0 pipe csum ip continue\n" % intf.get('device'))
                        file.write("tc filter add dev %s parent ffff: protocol ip prio 2 u32 match mark 0x00040000 0x00ff0000 flowid :1 action pedit munge ip tos set 32 pipe csum ip pipe mirred egress redirect dev ifb4%s\n" % (intf.get('device'),intf.get('device')))
                        file.write("tc filter add dev %s parent ffff: protocol ip prio 3 u32 match mark 0x00030000 0x00ff0000 flowid :1 action pedit munge ip tos set 0 pipe csum ip pipe mirred egress redirect dev ifb4%s\n" % (intf.get('device'),intf.get('device')))
                        file.write("tc filter add dev %s parent ffff: protocol ip prio 4 u32 match mark 0x00020000 0x00ff0000 flowid :1 action pedit munge ip tos set 64 pipe csum ip pipe mirred egress redirect dev ifb4%s\n" % (intf.get('device'),intf.get('device')))
                        file.write("tc filter add dev %s parent ffff: protocol ip prio 5 u32 match mark 0x00010000 0x00ff0000 flowid :1 action pedit munge ip tos set 224 pipe csum ip pipe mirred egress redirect dev ifb4%s\n" % (intf.get('device'),intf.get('device')))
                        file.write("tc filter add dev %s parent ffff: protocol all prio 6 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev ifb4%s\n" % (intf.get('device'),intf.get('device')))
                        file.write("\n")

        except:
            print("ERROR:")
            traceback.print_exception()
        finally:
            file.write("exit 0")
            file.write("\n")
            file.flush()
            file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        if verbosity > 0: print("QosManager: Wrote %s" % filename)
        return

    def sync_settings( self, settings, prefix, delete_list, verbosity=0 ):
        self.write_qos_rules_sys_file(settings, prefix, verbosity)
        pass
    
registrar.register_manager(QosManager())
