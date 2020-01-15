import os
import stat
import sys
import subprocess
import datetime
import traceback
import re
from sync.network_util import NetworkUtil
from sync import registrar,Manager

# This class is responsible for writing:
# /etc/radvd.conf
# based on the settings object passed from sync-settings


class RadvdManager(Manager):
    config_filename = "/etc/radvd.conf"
    restart_hook_filename = "/etc/untangle/post-network-hook.d/990-restart-radvd"

    def initialize(self):
        registrar.register_settings_file("network", self)
        registrar.register_file(self.config_filename, "restart-radvd", self)
        registrar.register_file(self.restart_hook_filename, "restart-networking", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        self.write_config_file(settings_file.settings, prefix)
        self.write_restart_radvd_hook(settings_file.settings, prefix)

    def write_config_file(self, settings, prefix=""):
        filename = prefix + self.config_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")

        for intf in settings.get('interfaces'):
            if not intf.get('raEnabled'):
                continue
            if intf.get('configType') != "ADDRESSED":
                continue
            if intf.get('v6ConfigType') != "STATIC":
                continue
            if intf.get('v6StaticAddress') == None or intf.get('v6StaticPrefixLength') == None:
                continue

            file.write("interface %s {" % intf.get('systemDev') + "\n")
            file.write("    IgnoreIfMissing on;" + "\n")
            file.write("    AdvSendAdvert on;" + "\n")
            file.write("    MinRtrAdvInterval 3;" + "\n")
            file.write("    MaxRtrAdvInterval 10;" + "\n")
            file.write("    prefix %s/%s {" % (intf.get('v6StaticAddress'), intf.get('v6StaticPrefixLength')) + "\n")
            file.write("        AdvOnLink on;" + "\n")
            file.write("        AdvAutonomous on;" + "\n")
            file.write("        AdvRouterAddr on;" + "\n")
            file.write("    };" + "\n")
            file.write("};" + "\n")

        file.flush()
        file.close()

        print("RadvdManager: Wrote %s" % filename)

    def write_restart_radvd_hook(self, settings, prefix=""):
        filename = prefix + self.restart_hook_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/bin/dash")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n")

        file.write(r"""
RADVD_PID="`pidof radvd`"

# Start radvd if it isnt found and is needed (config file is non-zero)
# Restart radvd if it is found and but is outdated and is needed (config file is non-zero)
# Stop if radvd is found, but no longer needed (config file is zero size)
# The reason we don't just stop and then start if needed if to avoid doing anything if nothing is required.
if [ -z "$RADVD_PID" ] && [ -s /etc/radvd.conf ] ; then
    systemctl --no-block start radvd
elif [ /etc/radvd.conf -nt /proc/$RADVD_PID ] && [ -s /etc/radvd.conf ] ; then
    systemctl --no-block restart radvd
elif [ ! -z "$RADVD_PID" ] && [ ! -s /etc/radvd.conf ] ; then
    systemctl --no-block stop radvd
fi
""")

        file.write("\n")
        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("RadvdManager: Wrote %s" % filename)
        return


registrar.register_manager(RadvdManager())
