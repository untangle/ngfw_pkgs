import os
import stat
import sys
import subprocess
import datetime
import traceback
import re
from sync.network_util import NetworkUtil

# This class is responsible for writing PPPoE related conf files
# based on the settings object passed from sync-settings.py
#
#
class PPPoEManager:
    papSecretsFilename = "/etc/ppp/pap-secrets"
    chapSecretsFilename = "/tmp/chap-secrets.pppoe"
    peersDirectory = "/etc/ppp/peers/"
    connectionBaseName = "connection.intf"
    preNetworkHookFilename = "/etc/untangle/pre-network-hook.d/040-pppoe"
    pppIpUpFilename = "/etc/ppp/ip-up.d/99-untangle"

    def write_pppoe_connection_files( self, settings, prefix="", verbosity=0 ):

        for interface_settings in settings.get('interfaces').get('list'):
            if "PPPOE" == interface_settings.get('v4ConfigType'):
                # open this pppoe config file for this connection
                fileName = self.peersDirectory + self.connectionBaseName + str(interface_settings.get('interfaceId'))
                conffile = open( fileName, "w+" )
                conffile.write("## Auto Generated\n");
                conffile.write("## DO NOT EDIT. Changes will be overwritten.\n");
                conffile.write("\n");

                conffile.write(r"""
noipdefault
hide-password
noauth
persist
maxfail 0

""")
                conffile.write("# PPPoE settings for %s." % interface_settings.get('systemDev') + "\n");

                # Check for the parent device's MTU setting
                # If it is set, set the ppp interface mtu to the same value
                if settings.get('devices') != None and settings.get('devices').get('list') != None:
                    for deviceSettings in settings.get('devices').get('list'):
                        if interface_settings.get('physicalDev') == deviceSettings.get('deviceName'):
                            if deviceSettings.get('mtu') != None:
                                conffile.write("mtu %s" % (deviceSettings.get('mtu')) + "\n")

                if interface_settings.get('v4PPPoERootDev') != None:
                    conffile.write("plugin rp-pppoe.so %s" % interface_settings.get('v4PPPoERootDev') + "\n")
                else:
                    conffile.write("plugin rp-pppoe.so %s" % interface_settings.get('physicalDev') + "\n")
                conffile.write("user \"%s\"" % interface_settings.get('v4PPPoEUsername') + "\n")

                if ( interface_settings.get('v4PPPoEUsePeerDns') == True ):
                    conffile.write("usepeerdns" + "\n")

                conffile.flush()
                conffile.close()

                if verbosity > 0:
                    print("PPPoEManager: Wrote %s" % fileName)
            else:
                # interface is not PPPoE, remove any existing peer file
                fileName = self.peersDirectory + self.connectionBaseName + str(interface_settings.get('interfaceId'))
                os.system("/bin/rm -f %s" % fileName)

        return

    def write_secret_files( self, settings, prefix="", verbosity=0 ):

        secrets = ""
        secrets += "## Auto Generated\n"
        secrets += "## DO NOT EDIT. Changes will be overwritten.\n"
        secrets += "\n"

        pppoe_found = False
        for interface_settings in settings.get('interfaces').get('list'):
            if "PPPOE" == interface_settings.get('v4ConfigType'):
                pppoe_found = True
                secrets += "\"%s\" * \"%s\" *\n" % ( interface_settings.get('v4PPPoEUsername'), interface_settings.get('v4PPPoEPassword') )

        if not pppoe_found:
            return

        papSecretsFile = open( self.papSecretsFilename, "w+" )
        papSecretsFile.write(secrets)
        papSecretsFile.flush();
        papSecretsFile.close();
        if verbosity > 0:
            print("PPPoEManager: Wrote %s" % self.papSecretsFilename)

        chapSecretsFile = open( self.chapSecretsFilename, "w+" )
        chapSecretsFile.write(secrets)
        chapSecretsFile.flush();
        chapSecretsFile.close();
        if verbosity > 0:
            print("PPPoEManager: Wrote %s" % self.chapSecretsFilename)
        # FIXME - this modifies the filesystem directly! FIXME
        os.system("/usr/share/untangle/bin/ut-chap-manager PPPOE %s" % self.chapSecretsFilename)

        return

    def write_pre_network_hook( self, settings, prefix="", verbosity=0 ):

        filename = prefix + self.preNetworkHookFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        file.write("# Stop all active PPP Connections." + "\n")
        file.write("poff -a >/dev/null 2>&1" + "\n")
        file.write("\n\n");
        file.write("true" + "\n")

        file.write("# Delete old PPPoE dns servers (this will be recreated)" + "\n")
        file.write("rm -f /etc/dnsmasq.d/pppoe-upstream-dns-servers" + "\n")
        file.write("\n\n");
        
        file.flush()
        file.close()
        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)

        if verbosity > 0: print("PPPoEManager: Wrote %s" % filename)


    def write_ppp_ipup_hook( self, settings, prefix="", verbosity=0 ):

        filename = prefix + self.pppIpUpFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        file.write(r"""
# These variables are for the use of the scripts run by run-parts
# PPP_IFACE="$1"
# PPP_TTY="$2"
# PPP_SPEED="$3"
# PPP_LOCAL="$4"
# PPP_REMOTE="$5"
# PPP_IPPARAM="$6"

# redirect to logfile and stdout
mkdir -p /var/log/uvm/
LOGFILE="/var/log/uvm/pppoe.log"
mkfifo ${LOGFILE}.pipe
tee < ${LOGFILE}.pipe $LOGFILE &
exec >> ${LOGFILE}.pipe 2>&1
rm ${LOGFILE}.pipe

if [ "$PPP_IPPARAM" = "L2TP" ]; then
    /bin/echo -e "[INFO: `date`] Ignoring ${PPP_IFACE} because it is an L2TP instance"
    exit
fi

write_status_file()
{
    local t_interface="$1"
    local t_index="$2"
    ( [ -z "$t_interface" ] || [ -z "$t_index" ] ) && {
        return 0
    }

    /bin/echo -e "[DEBUG: `date`] Writing /var/lib/untangle-interface-status/interface-${t_index}-status.js"
    /usr/share/untangle-sync-settings/bin/write-interface-status.py -I ${t_interface} -i ${t_index} -w /var/lib/untangle-interface-status/interface-${t_index}-status.js

    /bin/echo -e "[DEBUG: `date`] Writing /var/lib/untangle-interface-status/interface-${t_interface}-status.js"
    /usr/share/untangle-sync-settings/bin/write-interface-status.py -I ${t_interface} -i ${t_index} -w /var/lib/untangle-interface-status/interface-${t_interface}-status.js
}

make_resolv_conf() {
    ## This guarantees that ${t_new_domain_name_servers} will just be " "
    local t_new_domain_name_servers="`echo "${DNS1}\n${DNS2}" | sort | uniq`"

    ## Check MS_DNSx if the DNS servers were not specified in DNS1 and DNS2
    test -z "${t_new_domain_name_servers}" && {
        t_new_domain_name_servers=`echo "${MS_DNS1}\n${MS_DNS2}" | sort | uniq`
    }

    ## only update the dns server when instructed to.
    if [ -n "${t_new_domain_name_servers}" ] && [ "${USEPEERDNS}x" = "1x" ]; then
        if [ ! -f /etc/dnsmasq.d/pppoe-upstream-dns-servers ] ; then
            touch /etc/dnsmasq.d/pppoe-upstream-dns-servers
        fi
        local t_hash="`md5sum /etc/dnsmasq.d/pppoe-upstream-dns-servers`"

        if [ -n "$t_new_domain_name_servers" ]; then
            for nameserver in $t_new_domain_name_servers ; do
                /bin/echo -e "#new_name_server=${nameserver} # uplink.${PPPOE_UPLINK_INDEX}" >> /etc/dnsmasq.d/pppoe-upstream-dns-servers
            done

            sed -i -e "/^#*\s*server=.*uplink.${PPPOE_UPLINK_INDEX}/d" -e 's/^#new_name_server=/server=/' /etc/dnsmasq.d/pppoe-upstream-dns-servers
        fi

        local t_new_hash="`md5sum /etc/dnsmasq.d/pppoe-upstream-dns-servers`"
                    
        ## Reststart DNS MASQ if necessary
        if [ "${t_hash}x" != "${t_new_hash}x" ]; then
            /bin/echo -e "[DEBUG: `date`] /etc/dnsmasq.d/pppoe-upstream-dns-servers changed. Restarting dnsmasq..."
            systemctl restart dnsmasq
            /bin/echo -e "[DEBUG: `date`] /etc/dnsmasq.d/pppoe-upstream-dns-servers changed. Restarting dnsmasq...done"
        fi
    fi

    return 0
}

PPP_PID=`cat /var/run/${PPP_IFACE}.pid`
/bin/echo -e "[DEBUG: `date`] PPP pid: ${PPP_PID}"

CONNECTION_FILE=`cat "/proc/${PPP_PID}/cmdline" | tr '\000' '\n' | awk '/^connection./ { print ; exit }'`
/bin/echo -e "[DEBUG: `date`] Connection file: ${CONNECTION_FILE}"

PPPOE_UPLINK_INDEX=`echo ${CONNECTION_FILE} | sed -e 's/connection\.intf//'`
/bin/echo -e "[DEBUG: `date`] Interface index: ${PPPOE_UPLINK_INDEX}"

if [ -z "${PPPOE_UPLINK_INDEX}" ]; then
    /bin/echo -e "[DEBUG: `date`] Unknown interface index! Quitting..."
    return
fi

make_resolv_conf

/usr/share/untangle-sync-settings/bin/add-uplink.sh ${PPP_IFACE} ${PPP_REMOTE} "uplink.${PPPOE_UPLINK_INDEX}" -4 
/usr/share/untangle-sync-settings/bin/add-source-route.sh ${PPP_LOCAL} "uplink.${PPPOE_UPLINK_INDEX}" -4

write_status_file ${PPP_IFACE} ${PPPOE_UPLINK_INDEX}

# XXX - should we run this here?
# run-parts /etc/untangle/post-network-hook.d

true
""")

        file.flush()
        file.close()
        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)

        if verbosity > 0: print("PPPoEManager: Wrote %s" % filename)



    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print("PPPoEManager: sync_settings()")

        self.write_pppoe_connection_files( settings, prefix, verbosity )
        self.write_secret_files( settings, prefix, verbosity )
        self.write_pre_network_hook( settings, prefix, verbosity )
        self.write_ppp_ipup_hook( settings, prefix, verbosity )

        # move 0000usepeerdns file, we will handle usepeerdns option
        # bug #11185
        # FIXME - this modifies the filesystem directly! FIXME
        os.system("if [ -f /etc/ppp/ip-up.d/0000usepeerdns ] ; then mv -f /etc/ppp/ip-up.d/0000usepeerdns /etc/ppp/ip-up.d/0000usepeerdns.disabled ; fi")

        return
