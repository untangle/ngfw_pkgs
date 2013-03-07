import os
import sys
import subprocess
import datetime
import traceback
import re
from netd.network_util import NetworkUtil

# This class is responsible for writing 
# based on the settings object passed from sync-settings.py
class DnsMasqManager:
    dnsmasqConfFilename = "/etc/dnsmasq.conf"
    restartHookFilename = "/etc/untangle-netd/post-network-hook.d/99-restart-dnsmasq"

    def write_dnsmasq_conf( self, settings, prefix="", verbosity=0 ):
        
        filename = prefix + self.dnsmasqConfFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");
        
        # If its a static WAN then write the uplink DNS values
        for intf in settings['interfaces']['list']:
            if intf.get('configType') == 'ADDRESSED' and intf.get('isWan') == True and intf.get('v4ConfigType') == 'STATIC':
                if intf.get('v4StaticDns1') != None:
                    file.write("# Interface %s DNS 1" % str(intf.get('interfaceId')) + "\n")
                    file.write("server=%s # uplink.%s" % (intf.get('v4StaticDns1'), str(intf.get('interfaceId'))) + "\n")
                    file.write("\n");
                
        # Set globla options
        file.write("# Global DNS options\n")
        file.write("localise-queries\n");
        file.write("expand-hosts\n");
        file.write("\n");

        # Set global DHCP options
        file.write("# Global DHCP options\n")
        if (settings.get('dhcpAuthoritative') == True): file.write("dhcp-authoritative\n")
        file.write("dhcp-lease-max=5000\n"); # should this be configurable?
        file.write("\n");

        # Enable DHCP on internal NICs (where configured)
        for intf in settings['interfaces']['list']:
            if intf.get('configType') == 'ADDRESSED' and intf.get('isWan') == False:
                if intf.get('dhcpEnabled') == True:
                    leaseTime = 3600
                    if intf.get('dhcpLeaseDuration') != None and intf.get('dhcpLeaseDuration') != "":
                        try:
                            leaseTime = int(intf.get('dhcpLeaseDuration'))
                        except Exception,e:
                            pass
                    
                    # Use symbolicDev so the whole bridge is served if its a bridge
                    file.write("# Interface %s (%s) DHCP" % (str(intf.get('interfaceId')), intf.get('symbolicDev')) + "\n")
                    file.write("dhcp-range=interface:%s,%s,%s,%i" % (intf.get('symbolicDev'), str(intf.get('dhcpRangeStart')), str(intf.get('dhcpRangeEnd')), leaseTime) + "\n")
                    
                    # set gateway option 
                    # If the override value is specified, set it, otherwise use static address (ourselves) as gateway
                    if intf.get('dhcpGatewayOverride') != None and intf.get('dhcpGatewayOverride') != "":
                        file.write("dhcp-option=tag:%s,3,%s # gateway" % (intf.get('symbolicDev'), str(intf.get('dhcpGatewayOverride'))) + "\n")
                    else:
                        file.write("dhcp-option=tag:%s,3,%s # gateway" % (intf.get('symbolicDev'), str(intf.get('v4StaticAddress'))) + "\n")
                        
                    # set netmask option 
                    # If the override value is specified, set it, otherwise use static netmask 
                    if intf.get('dhcpNetmaskOverride') != None and intf.get('dhcpNetmaskOverride') != "":
                        file.write("dhcp-option=tag:%s,1,%s # netmask" % (intf.get('symbolicDev'), str(intf.get('dhcpNetmaskOverride'))) + "\n")
                    else:
                        file.write("dhcp-option=tag:%s,1,%s # netmask" % (intf.get('symbolicDev'), str(intf.get('v4StaticNetmask'))) + "\n")

                    # set dns option 
                    # If the override value is specified, set it, otherwise use static address (ourselves) as DNS 
                    if intf.get('dhcpDnsOverride') != None and intf.get('dhcpDnsOverride') != "":
                        file.write("dhcp-option=tag:%s,6,%s # dns" % (intf.get('symbolicDev'), str(intf.get('dhcpDnsOverride'))) + "\n")
                    else:
                        file.write("dhcp-option=tag:%s,6,%s # dns" % (intf.get('symbolicDev'), str(intf.get('v4StaticAddress'))) + "\n")


        # FIXME write static DNS entries
        # FIXME write static DHCP leases
        # FIXME write domain (ie domain=untangle.local)
        # FIXME write local DNS servers (ie local=/untangle.local/10.0.0.32)

        file.write("\n");
        file.flush()
        file.close()
    
        if verbosity > 0: print "DnsMasqManager: Wrote %s" % filename
        return

    def write_restart_dnsmasq_hook( self, settings, prefix="", verbosity=0 ):

        filename = prefix + self.restartHookFilename
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
DNSMASQ_PID="`pidof dnsmasq`"

# Restart dnsmasq if it isnt found
# Or if dnsmasq.conf has been written since dnsmasq was started
if [ -z "$DNSMASQ_PID" ] ; then
    /etc/init.d/dnsmasq restart
elif [ /etc/dnsmasq.conf -nt /proc/$DNSMASQ_PID/cmdline ] ; then
    /etc/init.d/dnsmasq restart
fi
""")

        file.flush()
        file.close()
    
        os.system("chmod a+x %s" % filename)
        if verbosity > 0: print "DnsMasqManager: Wrote %s" % filename
        return

    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "DnsMasqManager: sync_settings()"
        
        self.write_dnsmasq_conf( settings, prefix, verbosity )

        self.write_restart_dnsmasq_hook( settings, prefix, verbosity )

        return
