"""qos_manager manages qos settings"""
# pylint: disable=unused-argument
# pylint: disable=no-self-use
# pylint: disable=too-many-statements
# pylint: disable=bare-except
# pylint: disable=too-many-branches
# pylint: disable=too-many-public-methods
# pylint: disable=too-many-locals
import os
import stat
import traceback
from sync import registrar

# This class is responsible for writing /etc/config/qos.d/* and
# /etc/config/nftables-rules.d/300-qos-rules-sys
# based on the settings object passed from sync-settings
class QosManager:
    """
    This class is responsible for writing all the qos-related settings files
    """
    qos_rules_sys_filename = "/etc/config/nftables-rules.d/300-qos-rules-sys"
    qos_file_path = "/etc/config/qos.d"

    def initialize(self):
        """initialize this module"""
        registrar.register_file(self.qos_rules_sys_filename, "restart-nftables-rules", self)
        registrar.register_file(self.qos_file_path + "/*", "restart-qos", self)

    def sanitize_settings(self, settings):
        """sanitizes removes blank settings"""
        return

    def validate_settings(self, settings):
        """validates settings"""
        return

    def create_settings(self, settings, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)

    def write_qos_files(self, settings, prefix, delete_list):
        """write /etc/config/qos.d files"""
        qos_interfaces = []
        interfaces = settings.get('network').get('interfaces')
        for intf in interfaces:
            if not intf.get('enabled'):
                continue
            if intf.get('wan'):
                qos_interfaces.append(intf.get('device'))
                filename_noprefix = self.qos_file_path + ("/10-disable-qos-wan-%s" % intf.get('device'))
                filename = prefix + filename_noprefix
                file_dir = os.path.dirname(filename)
                if not os.path.exists(file_dir):
                    os.makedirs(file_dir)

                try:
                    delete_list.remove(filename_noprefix)
                except:
                    pass

                file = open(filename, "w+")
                file.write("#!/bin/sh")
                file.write("\n\n")

                file.write("## Auto Generated\n")
                file.write("## DO NOT EDIT. Changes will be overwritten.\n")
                file.write("\n")

                if intf.get('qosEnabled'):
                    file.write("ip link set dev ifb4%s down 2> /dev/null\n" % intf.get('device'))
                    file.write("ip link delete ifb4%s type ifb 2> /dev/null\n" % intf.get('device'))
                    file.write("\n")
                    file.write("tc qdisc del dev %s root 2> /dev/null\n" % intf.get('device'))
                    file.write("\n")
                    file.write("tc qdisc del dev %s handle ffff: ingress 2> /dev/null\n" % intf.get('device'))
                    file.write("tc qdisc del dev ifb4%s root 2> /dev/null\n" % intf.get('device'))
                    file.write("\n")
                    file.write("exit 0")
                    file.write("\n")
                else:
                    file.write("nft delete table inet qos-%s 2> /dev/null\n" % intf.get('device'))
                    file.write("\n")
                    file.write("exit 0")
                    file.write("\n")

                file.flush()
                file.close()

                os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)

                print("QosManager: Wrote %s" % filename)

                filename_noprefix = self.qos_file_path + ("/20-enable-qos-wan-%s" % intf.get('device'))
                filename = prefix + filename_noprefix

                try:
                    delete_list.remove(filename_noprefix)
                except:
                    pass

                file = open(filename, "w+")
                file.write("#!/bin/sh")
                file.write("\n\n")

                file.write("## Auto Generated\n")
                file.write("## DO NOT EDIT. Changes will be overwritten.\n")
                file.write("\n")

                if intf.get('qosEnabled'):
                    file.write("""DOWN="`/usr/bin/interface-kbps %s 2>/dev/null`"\n""" % intf.get('downloadKbps'))
                    file.write("""UP="`/usr/bin/interface-kbps %s 2>/dev/null`"\n""" % intf.get('uploadKbps'))
                    file.write("\n")
                    file.write("ip link add name ifb4%s type ifb\n" % intf.get('device'))
                    file.write("\n")
                    file.write("tc qdisc add dev %s root cake bandwidth ${UP}kbit diffserv4\n" % intf.get('device'))
                    file.write("\n")
                    file.write("tc qdisc add dev %s handle ffff: ingress\n" % intf.get('device'))
                    file.write("tc qdisc add dev ifb4%s root cake bandwidth ${DOWN}kbit diffserv4\n" % intf.get('device'))
                    file.write("ip link set dev ifb4%s up\n" % intf.get('device'))
                    file.write("\n")
                    file.write("tc filter add dev %s parent ffff: protocol ip prio 1 u32 match u32 0 0 flowid :1 action connmark action pedit munge ip tos set 0 pipe csum ip continue\n" % intf.get('device'))
                    file.write("tc filter add dev %s parent ffff: protocol ip prio 2 u32 match mark 0x00040000 0x00ff0000 flowid :1 action pedit munge ip tos set 32 pipe csum ip pipe mirred egress redirect dev ifb4%s\n" % (intf.get('device'), intf.get('device')))
                    file.write("tc filter add dev %s parent ffff: protocol ip prio 3 u32 match mark 0x00030000 0x00ff0000 flowid :1 action pedit munge ip tos set 0 pipe csum ip pipe mirred egress redirect dev ifb4%s\n" % (intf.get('device'), intf.get('device')))
                    file.write("tc filter add dev %s parent ffff: protocol ip prio 4 u32 match mark 0x00020000 0x00ff0000 flowid :1 action pedit munge ip tos set 64 pipe csum ip pipe mirred egress redirect dev ifb4%s\n" % (intf.get('device'), intf.get('device')))
                    file.write("tc filter add dev %s parent ffff: protocol ip prio 5 u32 match mark 0x00010000 0x00ff0000 flowid :1 action pedit munge ip tos set 224 pipe csum ip pipe mirred egress redirect dev ifb4%s\n" % (intf.get('device'), intf.get('device')))
                    file.write("tc filter add dev %s parent ffff: protocol all prio 6 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev ifb4%s\n" % (intf.get('device'), intf.get('device')))
                    file.write("\n")
                    file.write("exit 0")
                    file.write("\n")
                else:
                    file.write("""DOWN="`/usr/bin/interface-kbps 100000000 2>/dev/null`"\n""")
                    file.write("""UP="`/usr/bin/interface-kbps 100000000 2>/dev/null`"\n""")
                    file.write("\n")
                    file.write("DOWN_KBYTES=$((DOWN / 8))\n")
                    file.write("UP_KBYTES=$((UP / 8))\n")
                    file.write("\n")
                    file.write("nft add table inet qos-%s\n" % intf.get('device'))
                    file.write("nft flush table inet qos-%s\n" % intf.get('device'))
                    file.write("nft add chain inet qos-%s upload \"{ type filter hook postrouting priority 0 ; }\"\n" % intf.get('device'))
                    file.write("nft add rule inet qos-%s upload oifname %s limit rate over $UP_KBYTES kbytes/second drop\n" % (intf.get('device'), intf.get('device')))
                    file.write("nft add chain inet qos-%s download \"{ type filter hook prerouting priority 0 ; }\"\n" % intf.get('device'))
                    file.write("nft add rule inet qos-%s download iifname %s limit rate over $DOWN_KBYTES kbytes/second drop\n" % (intf.get('device'), intf.get('device')))
                    file.write("\n")
                    file.write("exit 0")
                    file.write("\n")

                file.flush()
                file.close()

                os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)

                print("QosManager: Wrote %s" % filename)

        filename_noprefix = self.qos_file_path + "/15-disable-qos-all"
        filename = prefix + filename_noprefix
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        try:
            delete_list.remove(filename_noprefix)
        except:
            pass

        file = open(filename, "w+")
        file.write("#!/bin/sh")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n")
        file.write("# qos_interfaces:%s\n" % qos_interfaces)
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
        for qos_intf in qos_interfaces:
            file.write("nft delete table inet qos-%s 2> /dev/null\n" % qos_intf)
        file.write("\n")
        file.write("exit 0")
        file.write("\n")

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("QosManager: Wrote %s" % filename)

    def write_qos_rules_sys_file(self, settings, prefix):
        """write /etc/config/nftables-rules.d/300-qos-rules-sys"""
        filename = prefix + self.qos_rules_sys_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/usr/bin/nft_debug -f")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n")

        try:
            add_qos_rules = False
            interfaces = settings.get('network').get('interfaces')
            for intf in interfaces:
                if not intf.get('enabled'):
                    continue
                if intf.get('wan') and intf.get('qosEnabled'):
                    add_qos_rules = True

            if add_qos_rules:
                file.write("add table inet qos\n")
                file.write("flush table inet qos\n")
                file.write("add chain inet qos restore-priority-mark\n")
                file.write("add rule inet qos restore-priority-mark meta mark and 0xff0000 == 0x40000 ct mark set ct mark and 0xff00ffff or 0x40000 ip dscp set cs1 counter\n")
                file.write("add rule inet qos restore-priority-mark meta mark and 0xff0000 == 0x30000 ct mark set ct mark and 0xff00ffff or 0x30000 ip dscp set cs0 counter\n")
                file.write("add rule inet qos restore-priority-mark meta mark and 0xff0000 == 0x20000 ct mark set ct mark and 0xff00ffff or 0x20000 ip dscp set cs2 counter\n")
                file.write("add rule inet qos restore-priority-mark meta mark and 0xff0000 == 0x10000 ct mark set ct mark and 0xff00ffff or 0x10000 ip dscp set cs7 counter\n")
                file.write("add chain inet qos postrouting-qos { type filter hook postrouting priority 50 ; }\n")
                file.write("add rule inet qos postrouting-qos jump restore-priority-mark\n")
        except:
            print("ERROR:")
            traceback.print_exc()
        finally:
            file.write("\n")
            file.flush()
            file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("QosManager: Wrote %s" % filename)

    def sync_settings(self, settings, prefix, delete_list):
        """syncs settings"""
        self.write_qos_rules_sys_file(settings, prefix)
        for (dirpath, _, filenames) in os.walk(self.qos_file_path + "/"):
            for filename in filenames:
                full_name = dirpath + filename
                delete_list.append(full_name)
        # Write all the /etc/config/qos.d/* files
        self.write_qos_files(settings, prefix, delete_list)

registrar.register_manager(QosManager())
