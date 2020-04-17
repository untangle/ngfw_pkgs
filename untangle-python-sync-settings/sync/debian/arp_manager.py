import os
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar, Manager

# This class is responsible for writing /etc/untangle/post-network-hook.d/025-arp
# based on the settings object passed from sync-settings


class ArpManager(Manager):
    filename = "/etc/untangle/post-network-hook.d/025-arp"

    def initialize(self):
        registrar.register_settings_file("network", self)
        registrar.register_file(self.filename, "restart-networking", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        self.write_arp(settings_file.settings, prefix)
        return

    def write_arp(self, settings, prefix):
        filename = prefix + self.filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/bin/dash")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        file.write("# Force send ARP to the gateways to update MAC table" + "\n")
        file.write("# This is necessary for malfunctioning ISP routers that have permanent ARP caches" + "\n")
        file.write("\n")
        for intf in settings['interfaces']:
            if intf.get('v4ConfigType') == 'STATIC':
                if 'v4StaticGateway' in intf and 'v4StaticAddress' in intf:
                    file.write("# Static IP of interface %i\n" % intf.get('interfaceId'))
                    file.write("arping -U -c 1 -I %s -s %s %s >/dev/null &\n" % (intf.get('systemDev'), intf.get('v4StaticAddress'), intf.get('v4StaticGateway')))
                    if intf.get('v4Aliases') != None:
                        for alias in intf.get('v4Aliases'):
                            file.write("# Alias IPs of interface %i\n" % intf.get('interfaceId'))
                            file.write("arping -U -c 1 -I %s -s %s %s >/dev/null &\n" % (intf.get('systemDev'), alias.get('staticAddress'), intf.get('v4StaticGateway')))

        file.write("\n\n")

        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("ArpManager: Wrote %s" % filename)

        return


registrar.register_manager(ArpManager())
