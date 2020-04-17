import os
import stat
import sys
import subprocess
import datetime
import traceback
import re
from sync import registrar,Manager
from sync.network_util import NetworkUtil

# This class is responsible for writing PPPoE related conf files
# based on the settings object passed from sync-settings


class PPPoEManager(Manager):
    pap_secrets_filename = "/etc/ppp/pap-secrets"
    chap_secrets_filename = "/etc/ppp/chap-secrets"
    peers_directory = "/etc/ppp/peers/"
    connection_base_name = "connection.intf"
    pre_network_hook_filename = "/etc/untangle/pre-network-hook.d/040-pppoe"
    ppp_ip_up_filename = "/etc/ppp/ip-up.d/99-untangle"

    def initialize(self):
        registrar.register_settings_file("network", self)
        registrar.register_file(self.pap_secrets_filename, "restart-networking", self)
        registrar.register_file(self.chap_secrets_filename, "restart-networking", self)  # FIXME
        registrar.register_file(self.peers_directory+".*", "restart-networking", self)
        registrar.register_file(self.pre_network_hook_filename, "restart-networking", self)
        registrar.register_file(self.ppp_ip_up_filename, "restart-networking", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        self.write_pppoe_connection_files(settings_file.settings, delete_list, prefix)
        self.write_secret_files(settings_file.settings, prefix)
        self.write_pre_network_hook(settings_file.settings, prefix)
        self.write_ppp_ipup_hook(settings_file.settings, prefix)
        # 14.0 delete obsolete file (can be removed in 14.1)
        delete_list.append("/etc/ppp/ip-up.d/99-netd")

    def write_pppoe_connection_files(self, settings, delete_list, prefix=""):
        for interface_settings in settings.get('interfaces'):
            if "PPPOE" == interface_settings.get('v4ConfigType'):
                # open this pppoe config file for this connection
                filename = prefix + self.peers_directory + self.connection_base_name + str(interface_settings.get('interfaceId'))
                file_dir = os.path.dirname(filename)
                if not os.path.exists(file_dir):
                    os.makedirs(file_dir)

                conffile = open(filename, "w+")
                conffile.write("## Auto Generated\n")
                conffile.write("## DO NOT EDIT. Changes will be overwritten.\n")
                conffile.write("\n")

                conffile.write(r"""
noipdefault
hide-password
noauth
persist
maxfail 0

""")
                conffile.write("# PPPoE settings for %s." % interface_settings.get('systemDev') + "\n")

                # Check for the parent device's MTU setting
                # If it is set, set the ppp interface mtu to the same value
                if settings.get('devices') != None:
                    for deviceSettings in settings.get('devices'):
                        if interface_settings.get('physicalDev') == deviceSettings.get('deviceName'):
                            if deviceSettings.get('mtu') != None:
                                conffile.write("mtu %s" % (deviceSettings.get('mtu')) + "\n")

                if interface_settings.get('v4PPPoERootDev') != None:
                    conffile.write("plugin rp-pppoe.so %s" % interface_settings.get('v4PPPoERootDev') + "\n")
                else:
                    conffile.write("plugin rp-pppoe.so %s" % interface_settings.get('physicalDev') + "\n")
                conffile.write("user \"%s\"" % interface_settings.get('v4PPPoEUsername') + "\n")

                if (interface_settings.get('v4PPPoEUsePeerDns') == True):
                    conffile.write("usepeerdns" + "\n")

                conffile.flush()
                conffile.close()

                print("PPPoEManager: Wrote %s" % filename)
            else:
                # interface is not PPPoE, remove any existing peer file
                filename = self.peers_directory + self.connection_base_name + str(interface_settings.get('interfaceId'))
                if os.path.exists(filename):
                    delete_list.append(filename)

        return

    def write_secret_files(self, settings, prefix=""):
        secrets = ""
        secrets += "## Auto Generated\n"
        secrets += "## DO NOT EDIT. Changes will be overwritten.\n"
        secrets += "\n"

        pppoe_found = False
        for interface_settings in settings.get('interfaces'):
            if "PPPOE" == interface_settings.get('v4ConfigType'):
                pppoe_found = True
                secrets += "\"%s\" * \"%s\" *\n" % (interface_settings.get('v4PPPoEUsername'), interface_settings.get('v4PPPoEPassword'))

        if not pppoe_found:
            return

        filename = prefix + self.pap_secrets_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        pap_secrets_file = open(filename, "w+")
        pap_secrets_file.write(secrets)
        pap_secrets_file.flush()
        pap_secrets_file.close()
        print("PPPoEManager: Wrote %s" % self.pap_secrets_filename)

        filename = prefix + self.chap_secrets_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        chap_secrets_file = open(filename, "w+")
        chap_secrets_file.write(secrets)
        chap_secrets_file.flush()
        chap_secrets_file.close()
        print("PPPoEManager: Wrote %s" % self.chap_secrets_filename)

        return

    def write_pre_network_hook(self, settings, prefix=""):
        filename = prefix + self.pre_network_hook_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/bin/dash")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        file.write("# Stop all active PPP Connections." + "\n")
        file.write("poff -a >/dev/null 2>&1" + "\n")
        file.write("\n\n")
        file.write("true" + "\n")

        file.write("# Delete old PPPoE dns servers (this will be recreated)" + "\n")
        file.write("rm -f /etc/dnsmasq.d/pppoe-upstream-dns-servers" + "\n")
        file.write("\n\n")

        file.flush()
        file.close()
        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)

        print("PPPoEManager: Wrote %s" % filename)

    def write_ppp_ipup_hook(self, settings, prefix=""):
        filename = prefix + self.ppp_ip_up_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/bin/dash")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        file.write(r"""
# These variables are for the use of the scripts run by run-parts
# PPP_IFACE="$1"
# PPP_TTY="$2"
# PPP_SPEED="$3"
# PPP_LOCAL="$4"
# PPP_REMOTE="$5"
# PPP_IPPARAM="$6"

# redirect to logfile and stdout
LOGFILE="/var/log/pppoe.log"
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

    /bin/echo -e "[DEBUG: `date`] Writing /var/lib/interface-status/interface-${t_index}-status.js"
    /usr/share/untangle-sync-settings/bin/write-interface-status.py -I ${t_interface} -i ${t_index} -w /var/lib/interface-status/interface-${t_index}-status.js

    /bin/echo -e "[DEBUG: `date`] Writing /var/lib/interface-status/interface-${t_interface}-status.js"
    /usr/share/untangle-sync-settings/bin/write-interface-status.py -I ${t_interface} -i ${t_index} -w /var/lib/interface-status/interface-${t_interface}-status.js
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
            systemctl --no-block restart dnsmasq
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

        print("PPPoEManager: Wrote %s" % filename)


registrar.register_manager(PPPoEManager())
