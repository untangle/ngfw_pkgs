import os
import sys
import subprocess
import datetime
import stat
import traceback
from sync import registrar,Manager

# This class is responsible for writing:
# /etc/untangle/post-network-hook.d/960-iptables
# /etc/untangle/iptables-rules.d/010-flush
# /etc/untangle/iptables-rules.d/100-interface-marks
#
# based on the settings object passed from sync-settings
#

class IptablesManager(Manager):
    flush_filename = "/etc/untangle/iptables-rules.d/010-flush"
    helpers_filename = "/etc/untangle/iptables-rules.d/011-helpers"
    post_network_filename = "/etc/untangle/post-network-hook.d/960-iptables"

    def initialize(self):
        registrar.register_settings_file("network", self)
        registrar.register_file(self.flush_filename, "restart-iptables", self)
        registrar.register_file(self.helpers_filename, "restart-iptables", self)
        registrar.register_file(self.post_network_filename, "restart-networking", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        self.write_flush_file(settings_file.settings, prefix)
        self.write_helpers_file(settings_file.settings, prefix)
        self.write_post_file(settings_file.settings, prefix)

        # 14.0 delete obsolete file (can be removed in 14.1)
        delete_list.append("/etc/untangle/iptables-rules.d/825-classd")

    def write_post_file(self, settings, prefix):
        filename = prefix + self.post_network_filename
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

#
# This script handles all the iptables rules
# It runs all the scripts in /etc/untangle/iptables.rules.d
# It logs both to stdout and the logfile

#LOGFILE="/var/log/iptables.log"
LOGFILE=""

IPTABLES_DIRECTORY=/etc/untangle/iptables-rules.d

#IPTABLES=/sbin/iptables
#IPTABLES="iptables_debug"
IPTABLES=iptables_debug_onerror

#IP6TABLES=/sbin/ip6tables
#IP6TABLES="ip6tables_debug"
IP6TABLES=ip6tables_debug_onerror

#EBTABLES=/sbin/ebtables
#EBTABLES=ebtables_debug
EBTABLES=ebtables_debug_onerror

LOCK_FILE=/tmp/generate-iptables-rules.lock

if [ ! -z "${LOGFILE}" ] ; then
    # switch stdout/stderr to tee for stdout and logfile
    mkfifo ${LOGFILE}.pipe
    tee < ${LOGFILE}.pipe $LOGFILE &
    exec >> ${LOGFILE}.pipe 2>&1
    rm ${LOGFILE}.pipe
fi

debug()
{
   /bin/echo -e "[`date`] 960-iptables ${*}"
}

iptables_debug()
{
   /bin/echo -e "[`date`] /sbin/iptables -w $@"
   /sbin/iptables -w "$@"
}

iptables_debug_onerror()
{
    # Ignore -N errors
    /sbin/iptables -w "$@" || {
        [ "${3}x" != "-Nx" ] && echo "[`date`] Failed: /sbin/iptables $@"
    }

    true
}

ip6tables_debug()
{
   /bin/echo -e "[`date`] /sbin/ip6tables $@"
   /sbin/ip6tables -w "$@"
}

ip6tables_debug_onerror()
{
    # Ignore -N errors
    /sbin/ip6tables -w "$@" || {
        [ "${3}x" != "-Nx" ] && echo "[`date`] Failed: /sbin/ip6tables $@"
    }

    true
}

ebtables_debug()
{
    /bin/echo -e "[`date`] /sbin/ebtables $@"
    /sbin/ebtables "$@"
}

ebtables_debug_onerror()
{
    # Ignore -N errors
    /sbin/ebtables "$@" || {
        echo "[`date`] Failed: /sbin/ebtables $@"
    }

    true
}

run_iptables_scripts()
{
    local t_script
    local t_ran_script=""

    if [ ! -d ${IPTABLES_DIRECTORY} ]; then
        debug "${IPTABLES_DIRECTORY} does not exist."
        return 0
    fi
    
    # Would use run-parts, but that doesn't maintain environment variables 
    # or the iptables_debug function.

    # Do not run any of the dpkg backup files.
    for t_script in `run-parts --list --lsbsysinit ${IPTABLES_DIRECTORY} | sort` ; do
        debug "${t_script} Running ..."
        START="`date +%s%N`"
        . ${t_script}
        RET=$?
        END="`date +%s%N`"
        TIME=$(( ($END-$START)/1000000 ))
        debug "${t_script} Complete: $RET (took $TIME msec)"
        t_ran_script="true"
    done
    
    if [ "${t_ran_script}x" != "truex" ]; then
        debug "${IPTABLES_DIRECTORY} is empty."
    fi
}

while true ; do
    if ( set -o noclobber; echo "$$" > "$LOCK_FILE" ) 2> /dev/null; then
      	trap 'rm -f "$LOCK_FILE"; exit $?' INT TERM EXIT
        
        # critical section
        debug "Running ${IPTABLES_DIRECTORY} scripts ..." 
        run_iptables_scripts
        debug "Running ${IPTABLES_DIRECTORY} scripts done." 
        
        rm -f "$LOCK_FILE"
        trap - INT TERM EXIT
        break
    else
        sleep .2
        
            # timeout
        t_count=$(($t_count+1))
        if [ $t_count -gt 1000 ] ; then 
            debug "ERROR: Failed to acquire lock file after 1000 tries."
            debug "ERROR: Removing \"stale\" lockfile..."
            rm -f "$LOCK_FILE" 
            continue;
        fi
    fi 
done


""")

        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("IptablesManager: Wrote %s" % filename)

    def write_flush_file(self, settings, prefix):
        filename = prefix + self.flush_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        file.write("## Flush all iptables rules\n")
        file.write("${IPTABLES} -t raw -F" + "\n")
        file.write("${IPTABLES} -t tune -F" + "\n")
        file.write("${IPTABLES} -t nat -F" + "\n")
        file.write("${IPTABLES} -t mangle -F" + "\n")
        file.write("${IPTABLES} -t filter -F" + "\n")
        if settings.get('blockDuringRestarts') != None and settings.get('blockDuringRestarts'):
            file.write("${IPTABLES} -t filter -I FORWARD -m conntrack --ctstate NEW -j DROP -m comment --comment \"drop sessions during restart\"\n")
            file.write("${IPTABLES} -t filter -I INPUT   -m conntrack --ctstate NEW -j DROP -m comment --comment \"drop sessions during restart\"\n")

        file.write("\n")

        file.write("## Flush all etables rules. (the only rules exist in the broute table)\n")
        file.write("${EBTABLES} -t broute -F" + "\n" + "\n")

        file.write("\n")
        file.write("\n")

        file.write("## Create and flush all chains.\n")
        file.write("## We create and insert rules to call all chains here so the order is always the same no matter the order the scripts are called in.\n")
        file.write("## The scripts are responsible for filling in the chains with the appropriate rules.\n")

        file.write("${IPTABLES} -t mangle -N prerouting-set-marks 2>/dev/null" + "\n")
        file.write("${IPTABLES} -t mangle -F prerouting-set-marks" + "\n")
        file.write("${IPTABLES} -t mangle -A PREROUTING -j prerouting-set-marks" + "\n")

        file.write("${IPTABLES} -t mangle -N forward-set-marks 2>/dev/null" + "\n")
        file.write("${IPTABLES} -t mangle -F forward-set-marks" + "\n")
        file.write("${IPTABLES} -t mangle -A FORWARD -j forward-set-marks" + "\n")

        file.write("${IPTABLES} -t mangle -N output-set-marks 2>/dev/null" + "\n")
        file.write("${IPTABLES} -t mangle -F output-set-marks" + "\n")
        file.write("${IPTABLES} -t mangle -A OUTPUT -j output-set-marks" + "\n")

        file.write("${IPTABLES} -t mangle -N output-untangle-vm 2>/dev/null" + "\n")
        file.write("${IPTABLES} -t mangle -F output-untangle-vm" + "\n")
        file.write("${IPTABLES} -t mangle -A OUTPUT -j output-untangle-vm" + "\n")

        file.write("${IPTABLES} -t mangle -N input-set-marks 2>/dev/null" + "\n")
        file.write("${IPTABLES} -t mangle -F input-set-marks" + "\n")
        file.write("${IPTABLES} -t mangle -A INPUT -j input-set-marks" + "\n")

        file.write("${IPTABLES} -t mangle -N input-untangle-vm 2>/dev/null" + "\n")
        file.write("${IPTABLES} -t mangle -F input-untangle-vm" + "\n")
        file.write("${IPTABLES} -t mangle -A INPUT -j input-untangle-vm" + "\n")

        file.write("${IPTABLES} -t mangle -N prerouting-untangle-vm 2>/dev/null" + "\n")
        file.write("${IPTABLES} -t mangle -F prerouting-untangle-vm" + "\n")
        file.write("${IPTABLES} -t mangle -A PREROUTING -j prerouting-untangle-vm" + "\n")

        file.write("${IPTABLES} -t mangle -N prerouting-qos 2>/dev/null" + "\n")
        file.write("${IPTABLES} -t mangle -F prerouting-qos" + "\n")
        file.write("${IPTABLES} -t mangle -A PREROUTING -j prerouting-qos" + "\n")

        file.write("${IPTABLES} -t mangle -N postrouting-qos 2>/dev/null" + "\n")
        file.write("${IPTABLES} -t mangle -F postrouting-qos" + "\n")
        file.write("${IPTABLES} -t mangle -A POSTROUTING -j postrouting-qos" + "\n")

        file.write("${IPTABLES} -t mangle -N prerouting-tunnel-vpn 2>/dev/null" + "\n")
        file.write("${IPTABLES} -t mangle -F prerouting-tunnel-vpn" + "\n")
        file.write("${IPTABLES} -t mangle -A PREROUTING -j prerouting-tunnel-vpn" + "\n")

        file.write("${IPTABLES} -t mangle -N prerouting-wan-balancer 2>/dev/null" + "\n")
        file.write("${IPTABLES} -t mangle -F prerouting-wan-balancer" + "\n")
        file.write("${IPTABLES} -t mangle -A PREROUTING -j prerouting-wan-balancer" + "\n")

        file.flush()
        file.close()

        print("IptablesManager: Wrote %s" % filename)

    def write_helpers_file(self, settings, prefix):

        filename = prefix + self.helpers_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        file.write("## Create all helper rules.\n")

        file.write("${IPTABLES} -t raw -N helpers 2>/dev/null" + "\n")
        file.write("${IPTABLES} -t raw -F helpers" + "\n")
        file.write("\n")

        file.write("${IPTABLES} -t raw -D PREROUTING -j helpers >/dev/null 2>&1" + "\n")
        file.write("${IPTABLES} -t raw -I PREROUTING -j helpers" + "\n")
        file.write("\n")

        # NGFW-11705
        # Newer kernel have non-automatic conntrack helper assignment
        # The below rules do conntrack helpers the "proper" way
        # However, it appears that this breaks Untangle layer-7 ftp  processing
        # When assigned manually it seems that the FTP helper tries to help in addition
        # to the userspace helper. Whereas the automatic helper does not do this for some reason
        # As such, we're force to just set the proc setting to get the old automatic behavior

        file.write("if [ -f /proc/sys/net/netfilter/nf_conntrack_helper ] ; then echo 1 > /proc/sys/net/netfilter/nf_conntrack_helper ; fi")

        # file.write("uname -r | grep -q '^4'" + "\n");
        # file.write("KERN_4_X=$?" + "\n");
        # file.write("\n");

        # file.write("if [ ${KERN_4_X} -eq 0 ] ; then" + "\n");
        # file.write("\n");

        # file.write("\t${IPTABLES} -t raw -A helpers -p udp --dport 1719 -j CT --helper RAS" + "\n");
        # file.write("\t${IPTABLES} -t raw -A helpers -p tcp --dport 1720 -j CT --helper Q.931" + "\n");
        # file.write("\n");

        # if settings.get('enableSipNatHelper'):
        #     file.write("\t${IPTABLES} -t raw -A helpers -p tcp --dport 5060 -j CT --helper sip" + "\n");
        #     file.write("\t${IPTABLES} -t raw -A helpers -p udp --dport 5060 -j CT --helper sip" + "\n");
        #     file.write("\t${IPTABLES} -t raw -A helpers -p tcp --dport 5061 -j CT --helper sip" + "\n");
        #     file.write("\t${IPTABLES} -t raw -A helpers -p udp --dport 5061 -j CT --helper sip" + "\n");
        #     file.write("\n");

        # # file.write("\t# only process bypassed sessions, the ftp-casing will handle scanned sessions" + "\n")
        # # file.write("\t${IPTABLES} -t raw -A helpers -m connmark --mark 0x01000000/0x01000000 -p tcp --dport 21 -j CT --helper ftp" + "\n");
        # file.write("\t${IPTABLES} -t raw -A helpers -p tcp --dport 21 -j CT --helper ftp" + "\n");
        # file.write("\n");

        # file.write("\t${IPTABLES} -t raw -A helpers -p tcp --dport 6667 -j CT --helper irc" + "\n");
        # file.write("\n");

        # # XXX - in testing it seems this PPTP helper does not work
        # # The GRE session does not get redirected
        # # the nf_nat_pptp and associated GRE plugin do work correctly, but is deprecated in newer kernels
        # file.write("\t${IPTABLES} -t raw -A helpers -p tcp --dport 1723 -j CT --helper pptp" + "\n");
        # file.write("\n");

        # file.write("\t${IPTABLES} -t raw -A helpers -p udp --dport 69 -j CT --helper tftp" + "\n");
        # file.write("\n");

        # file.write("\t${IPTABLES} -t raw -A helpers -p udp --dport 137 -j CT --helper netbios-ns" + "\n");
        # file.write("\n");

        # file.write("\t${IPTABLES} -t raw -A helpers -p udp --dport 161 -j CT --helper snmp" + "\n");
        # file.write("\n");

        # file.write("fi" + "\n");
        # file.write("\n");

        file.flush()
        file.close()

        print("IptablesManager: Wrote %s" % filename)


registrar.register_manager(IptablesManager())
