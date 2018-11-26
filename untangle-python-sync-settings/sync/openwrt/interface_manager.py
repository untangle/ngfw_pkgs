import os
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar

# This class is responsible for writing FIXME
# based on the settings object passed from sync-settings


class InterfaceManager:
    interface_marks_filename = "/etc/config/nftables-rules.d/101-interface-marks"

    def initialize(self):
        registrar.register_file(self.interface_marks_filename, "restart-nftables-rules", self)
        pass

    def sanitize_settings(self, settings):
        pass

    def validate_settings(self, settings):
        pass

    def create_settings(self, settings, prefix, delete_list, filename):
        pass

    def bridged_interface(self, settings, interface):
        interfaces = settings.get('network').get('interfaces')
        for intf in interfaces:
            if intf.get('configType') == "BRIDGED" and intf.get('bridgedTo') == interface.get('interfaceId'):
                return True
        return False

    def write_interface_marks_file(self, settings, prefix):
        filename = prefix + self.interface_marks_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/bin/sh")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        try:
            file.write(r"""
nft delete table inet interface-marks 2>/dev/null || true
nft add table inet interface-marks
nft add chain inet interface-marks prerouting-interface-marks "{ type filter hook prerouting priority -150 ; }"
nft add chain inet interface-marks forward-interface-marks "{ type filter hook forward priority -150 ; }"
nft add chain inet interface-marks postrouting-interface-marks "{ type filter hook postrouting priority 0 ; }"
# nft add chain inet interface-marks output-interface-marks "{ type filter hook output priority 110 ; }"
nft add chain inet interface-marks restore-interface-marks
nft add chain inet interface-marks restore-interface-marks-original
nft add chain inet interface-marks restore-interface-marks-reply
nft add rule inet interface-marks restore-interface-marks ct direction original jump restore-interface-marks-original
nft add rule inet interface-marks restore-interface-marks ct direction reply jump restore-interface-marks-reply
nft add chain inet interface-marks mark-src-interface
nft add chain inet interface-marks mark-dst-interface
nft add chain inet interface-marks check-src-interface-mark
nft add chain inet interface-marks check-dst-interface-mark
nft add rule inet interface-marks prerouting-interface-marks jump restore-interface-marks
nft add rule inet interface-marks prerouting-interface-marks mark and 0x000000ff == 0 jump mark-src-interface
nft add rule inet interface-marks prerouting-interface-marks jump check-src-interface-mark
nft add rule inet interface-marks forward-interface-marks mark and 0x0000ff00 == 0 jump mark-dst-interface
nft add rule inet interface-marks postrouting-interface-marks mark and 0x0000ff00 == 0 jump mark-dst-interface
nft add rule inet interface-marks postrouting-interface-marks jump check-dst-interface-mark
#nft add rule inet interface-marks output-interface-marks jump restore-interface-marks
""")

            interfaces = settings.get('network').get('interfaces')
            for intf in interfaces:
                if intf.get('configType') == 'DISABLED':
                    continue
                if intf.get('configType') == 'BRIDGED':
                    continue
                if self.bridged_interface(settings, intf):
                    file.write("nft add rule inet interface-marks mark-src-interface iifname %s mark set \"mark&0xffffff00\" or \"0x%x&0x00ff\"\n" % ("br-b_" + intf.get('name'), intf.get('interfaceId')))
                    file.write("nft add rule inet interface-marks mark-src-interface iifname %s ct mark set \"ct mark&0xffffff00\" or \"0x%x&0x00ff\"\n" % ("br-b_" + intf.get('name'), intf.get('interfaceId')))
                    file.write("nft add rule inet interface-marks mark-dst-interface oifname %s mark set \"mark&0xffff00ff\" or \"0x%x&0xff00\"\n" % ("br-b_" + intf.get('name'), (intf.get('interfaceId') << 8)))
                    file.write("nft add rule inet interface-marks mark-dst-interface oifname %s ct mark set \"ct mark&0xffff00ff\" or \"0x%x&0xff00\"\n" % ("br-b_" + intf.get('name'), (intf.get('interfaceId') << 8)))
                else:
                    file.write("nft add rule inet interface-marks mark-src-interface iifname %s mark set \"mark&0xffffff00\" or \"0x%x&0x00ff\"\n" % (intf.get('netfilterDev'), intf.get('interfaceId')))
                    file.write("nft add rule inet interface-marks mark-src-interface iifname %s ct mark set \"ct mark&0xffffff00\" or \"0x%x&0x00ff\"\n" % (intf.get('netfilterDev'), intf.get('interfaceId')))
                    file.write("nft add rule inet interface-marks mark-dst-interface oifname %s mark set \"mark&0xffff00ff\" or \"0x%x&0xff00\"\n" % (intf.get('netfilterDev'), (intf.get('interfaceId') << 8)))
                    file.write("nft add rule inet interface-marks mark-dst-interface oifname %s ct mark set \"ct mark&0xffff00ff\" or \"0x%x&0xff00\"\n" % (intf.get('netfilterDev'), (intf.get('interfaceId') << 8)))

                file.write("nft add rule inet interface-marks restore-interface-marks-original ct mark and 0x000000ff == 0x%x mark set mark and 0xffffff00 or 0x%x\n" % (intf.get('interfaceId'), intf.get('interfaceId')))
                file.write("nft add rule inet interface-marks restore-interface-marks-original ct mark and 0x0000ff00 == 0x%x mark set mark and 0xffff00ff or 0x%x\n" % (((intf.get('interfaceId') << 8) & 0xff00), ((intf.get('interfaceId') << 8) & 0xff00)))
                file.write("nft add rule inet interface-marks restore-interface-marks-reply ct mark and 0x000000ff == 0x%x mark set mark and 0xffff00ff or 0x%x\n" % (intf.get('interfaceId'), ((intf.get('interfaceId') << 8) & 0xff00)))
                file.write("nft add rule inet interface-marks restore-interface-marks-reply ct mark and 0x0000ff00 == 0x%x mark set mark and 0xffffff00 or 0x%x\n" % (((intf.get('interfaceId') << 8) & 0xff00), intf.get('interfaceId')))

            file.write("nft add rule inet interface-marks check-dst-interface-mark mark and 0x0000ff00 == 0 oifname != \"lo\" log prefix \\\"WARNING: Unknown dst intf: \\\"\n")
            file.write("nft add rule inet interface-marks check-src-interface-mark mark and 0x000000ff == 0 iifname != \"lo\" log prefix \\\"WARNING: Unknown src intf: \\\"\n")

            file.write("\n")
        except:
            print("ERROR:")
            traceback.print_exception()
        finally:
            file.flush()
            file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("InterfaceManager: Wrote %s" % filename)
        return

    def sync_settings(self, settings, prefix, delete_list):
        self.write_interface_marks_file(settings, prefix)
        pass


registrar.register_manager(InterfaceManager())
