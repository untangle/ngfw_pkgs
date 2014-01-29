import os
import sys
import subprocess
import datetime
import traceback
import re
from netd.network_util import NetworkUtil

# This class is responsible for writing:
# /etc/untangle-netd/post-network-hook.d/200-vrrp
# based on the settings object passed from sync-settings.py
class VrrpManager:
    keepalivedConfFilename = "/etc/keepalived/keepalived.conf"
    postNetworkHookFilename = "/etc/untangle-netd/post-network-hook.d/200-vrrp"
    iptablesHookFilename = "/etc/untangle-netd/iptables-rules.d/241-vrrp-rules"
    vrrp_enabled = False

    def write_keepalivd_conf( self, settings, prefix="", verbosity=0 ):
        
        filename = prefix + self.keepalivedConfFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        vrrp_interfaces = []
        for interface_settings in settings['interfaces']['list']:
            if interface_settings.get('vrrpEnabled'):
                if not interface_settings.get('vrrpId') or not interface_settings.get('vrrpPriority') or not interface_settings.get('vrrpAddress'):
                    print "Missing VRRP Config: %s, %s, %s" % (str(vrrpId), str(vrrpPriority), str(vrrpAddress))
                    continue
                vrrp_interfaces.append( interface_settings )

        file = open( filename, "w+" )
        file.write("! Auto Generated on %s\n" % datetime.datetime.now());
        file.write("! DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        if len(vrrp_interfaces) < 1:
            file.flush()
            file.close()
            if verbosity > 0: print "VrrpManager: Wrote %s" % filename
            return

        file.write(r"""
global_defs {
}
""")
        file.write("\n\n");

        file.write("vrrp_sync_group VRRPGROUP {" + "\n")
        file.write("\tgroup {" + "\n")
        for intf in vrrp_interfaces:
            file.write("\t\tVI_" + str(intf.get('interfaceId')) + "\n")
        file.write("\t}" + "\n")
        file.write("}" + "\n")
        file.write("\n\n");

        for intf in vrrp_interfaces:
            file.write("vrrp_instance VI_" + str(intf.get('interfaceId')) + " {" + "\n")
            file.write("\tstate MASTER" + "\n")
            file.write("\tinterface %s" % str(intf.get('systemDev')) + "\n")
            file.write("\tlvs_sync_daemon_interface %s" % str(intf.get('systemDev')) + "\n")
            file.write("\tvirtual_router_id %s" % str(intf.get('vrrpId')) + "\n")
            file.write("\tpriority %s" % str(intf.get('vrrpPriority')) + "\n")
            file.write("\tadvert_int 1" + "\n")
            file.write("\tvirtual_ipaddress {" + "\n")
            file.write("\t\t%s" % str(intf.get('vrrpAddress')) + "\n")
            file.write("\t}" + "\n")
            file.write("}" + "\n")
            file.write("\n\n");
        file.write("\n\n");

        file.flush()
        file.close()
        if verbosity > 0: print "VrrpManager: Wrote %s" % filename
        return
        
    def write_post_network_hook( self, settings, prefix="", verbosity=0 ):

        filename = prefix + self.postNetworkHookFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        file.write(r"""
if [ ! -z "`pidof keepalived`" ] ; then
    killall keepalived
fi
""")
        file.write("\n\n");

        self.vrrp_enabled = False
        for interface_settings in settings['interfaces']['list']:
            if interface_settings.get('vrrpEnabled'):
                if not interface_settings.get('vrrpId') or not interface_settings.get('vrrpPriority') or not interface_settings.get('vrrpAddress'):
                    print "Missing VRRP Config: %s, %s, %s" % (str(vrrpId), str(vrrpPriority), str(vrrpAddress))
                    continue
                self.vrrp_enabled = True

        if self.vrrp_enabled:
            file.write("if lsmod | grep -q ip_vs ; then" + "\n")
            file.write("\ttrue # do nothing" + "\n")         
            file.write("else" + "\n")
            file.write("\techo Loading ip_vs kernel module..." + "\n")
            file.write("\tmodprobe ip_vs" + "\n")
            file.write("fi" + "\n")
            file.write("\n")

            file.write("/usr/sbin/keepalived --vrrp -f /etc/keepalived/keepalived.conf --dump-conf --log-console --log-detail" + "\n")
        else:
            file.write("if lsmod | grep -q ip_vs ; then" + "\n")
            file.write("\techo Unloading ip_vs kernel module..." + "\n")
            file.write("\tmodprobe -r ip_vs" + "\n")
            file.write("else" + "\n")
            file.write("\ttrue # do nothing" + "\n")
            file.write("fi" + "\n")
            file.write("\n")

        file.write("\n\n");

        file.flush()
        file.close()

        os.system("chmod a+x %s" % filename)
        if verbosity > 0: print "VrrpManager: Wrote %s" % filename

        return

    def write_iptables_hook( self, settings, prefix="", verbosity=0 ):

        filename = prefix + self.iptablesHookFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        if self.vrrp_enabled:
            file.write("${IPTABLES} -t filter -I filter-rules-input -p vrrp -m comment --comment \"Allow VRRP\" -j RETURN" + "\n");

        file.flush()
        file.close()

        os.system("chmod a+x %s" % filename)
        if verbosity > 0: print "VrrpManager: Wrote %s" % filename

        return

    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "VrrpManager: sync_settings()"
        
        self.write_keepalivd_conf( settings, prefix, verbosity )
        self.write_post_network_hook( settings, prefix, verbosity )
        self.write_iptables_hook( settings, prefix, verbosity )

        return

