import os
import sys
import subprocess
import datetime
import traceback
import re
from netd.network_util import NetworkUtil

# This class is responsible for writing PPPoE related conf files
# based on the settings object passed from sync-settings.py
# 
# 
class PPPoEManager:
    papSecretsFilename = "/etc/ppp/pap-secrets"
    chapSecretsFilename = "/etc/ppp/chap-secrets"
    peersDirectory = "/etc/ppp/peers/"
    connectionBaseName = "connection.intf"
    preNetworkHookFilename = "/etc/untangle-netd/pre-network-hook.d/040-pppoe"
    pppIpUpFilename = "/etc/ppp/ip-up.d/99-netd"

    def write_pppoe_connection_files( self, settings, prefix="", verbosity=0 ):

        for interface_settings in settings.get('interfaces').get('list'):
            if "PPPOE" == interface_settings.get('v4ConfigType'):
                # open this pppoe config file for this connection
                fileName = self.peersDirectory + self.connectionBaseName + str(interface_settings.get('interfaceId'))
                conffile = open( fileName, "w+" )
                conffile.write("## Auto Generated on %s\n" % datetime.datetime.now());
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

                conffile.write("plugin rp-pppoe.so %s" % interface_settings.get('physicalDev') + "\n")
                conffile.write("user \"%s\"" % interface_settings.get('v4PPPoEUsername') + "\n")

                if ( interface_settings.get('v4PPPoEUsePeerDns') == True ):
                    conffile.write("usepeerdns" + "\n")

                conffile.flush()
                conffile.close()

                if verbosity > 0:
                    print "PPPoEManager: Wrote %s" % fileName

        return

    def write_secret_files( self, settings, prefix="", verbosity=0 ):

        secrets = ""
        secrets += "## Auto Generated on %s\n" % datetime.datetime.now()
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
            print "PPPoEManager: Wrote %s" % self.papSecretsFilename
        
        chapSecretsFile = open( self.chapSecretsFilename, "w+" )
        chapSecretsFile.write(secrets)
        chapSecretsFile.flush();
        chapSecretsFile.close();
        if verbosity > 0:
            print "PPPoEManager: Wrote %s" % self.chapSecretsFilename
        
        return

    def write_pre_network_hook( self, settings, prefix="", verbosity=0 ):

        filename = prefix + self.preNetworkHookFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        file.write("# Stop all active PPP Connections." + "\n")
        file.write("poff -a >/dev/null 2>&1" + "\n")
        file.write("\n\n");
        file.write("true" + "\n")
        
        file.flush()
        file.close()
        os.system("chmod a+x %s" % filename)

        if verbosity > 0: print "PPPoEManager: Wrote %s" % filename


    def write_ppp_ipup_hook( self, settings, prefix="", verbosity=0 ):

        filename = prefix + self.pppIpUpFilename
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

write_status_file()
{
    local t_interface="$1"
    local t_index="$2"
    ( [ -z "$t_interface" ] || [ -z "$t_index" ] ) && {
        return 0
    }

    /bin/echo -e "[DEBUG: `date`] Writing /var/lib/untangle-netd/interface-${t_index}-status.js"
    /usr/share/untangle-netd/bin/write-interface-status.py -I ${t_interface} -i ${t_index} -w /var/lib/untangle-netd/interface-${t_index}-status.js

    /bin/echo -e "[DEBUG: `date`] Writing /var/lib/untangle-netd/interface-${t_interface}-status.js"
    /usr/share/untangle-netd/bin/write-interface-status.py -I ${t_interface} -i ${t_index} -w /var/lib/untangle-netd/interface-${t_interface}-status.js
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
        local t_hash="`md5sum /etc/dnsmasq.conf`"
        
        if [ -n "$t_new_domain_name_servers" ]; then
            for nameserver in $t_new_domain_name_servers ; do
                /bin/echo -e "#new_name_server=${nameserver} # uplink.${PPPOE_UPLINK_INDEX}" >> /etc/dnsmasq.conf
            done
            
            sed -i -e "/^#*\s*server=.*uplink.${PPPOE_UPLINK_INDEX}/d" -e 's/^#new_name_server=/server=/' /etc/dnsmasq.conf
        fi

        local t_new_hash="`md5sum /etc/dnsmasq.conf`"
                    
        ## Reststart dnsmasq if necessary
        if [ "${t_hash}x" != "${t_new_hash}x" ]; then
            /bin/echo -e "[DEBUG: `date`] Restarting dnsmasq..."
            /etc/init.d/dnsmasq restart
        else
            /bin/echo -e "[DEBUG: `date`] Skipping dnsmasq restart"
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

/usr/share/untangle-netd/bin/add-uplink.sh ${PPP_IFACE} ${PPP_REMOTE} "uplink.${PPPOE_UPLINK_INDEX}"

write_status_file ${PPP_IFACE} ${PPPOE_UPLINK_INDEX}

# FIXME - should we run this here?
# run-parts /etc/untangle-netd/post-network-hook.d

true
""")
        
        file.flush()
        file.close()
        os.system("chmod a+x %s" % filename)

        if verbosity > 0: print "PPPoEManager: Wrote %s" % filename

        

    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "PPPoEManager: sync_settings()"
        
        self.write_pppoe_connection_files( settings, prefix, verbosity )
        self.write_secret_files( settings, prefix, verbosity )
        self.write_pre_network_hook( settings, prefix, verbosity )
        self.write_ppp_ipup_hook( settings, prefix, verbosity )

        # move 0000usepeerdns file, we will handle usepeerdns option
        # bug #11185
        os.system("if [ -f /etc/ppp/ip-up.d/0000usepeerdns ] ; then mv -f /etc/ppp/ip-up.d/0000usepeerdns /etc/ppp/ip-up.d/0000usepeerdns.disabled ; fi")

        return
