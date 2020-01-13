import os
import stat
import sys
import subprocess
import datetime
import traceback
import re
from sync.network_util import NetworkUtil
from sync import registrar, Manager

# This class is responsible for writing:
# /etc/dhcp/dhclient-enter-hooks.d/untangle-dhclient-enter-hook
# /etc/dhcp/dhclient-exit-hooks.d/untangle-dhclient-exit-hook
# based on the settings object passed from sync-settings


class DhcpManager(Manager):
    enter_hook_filename = "/etc/dhcp/dhclient-enter-hooks.d/untangle-dhclient-enter-hook"
    exit_hook_filename = "/etc/dhcp/dhclient-exit-hooks.d/untangle-dhclient-exit-hook"
    pre_network_hook_filename = "/etc/untangle/pre-network-hook.d/035-dhcp"
    dhcp_conf_filename = "/etc/dhcp/dhclient.conf"
    ddclient_hook_filename = "/etc/dhcp/dhclient-exit-hooks.d/ddclient"

    def initialize(self):
        registrar.register_settings_file("network", self)
        registrar.register_file(self.enter_hook_filename, "restart-networking", self)
        registrar.register_file(self.exit_hook_filename, "restart-networking", self)
        registrar.register_file(self.pre_network_hook_filename, "restart-networking", self)
        registrar.register_file(self.dhcp_conf_filename, "restart-networking", self)
        registrar.register_file(self.ddclient_hook_filename, "restart-networking", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        self.write_exit_hook(settings_file.settings, prefix)
        self.write_enter_hook(settings_file.settings, prefix)
        self.write_pre_network_hook(settings_file.settings, prefix)
        self.write_dhcp_ddclient_file(settings_file.settings, prefix)

        # 14.0 delete obsolete file (can be removed in 14.1)
        delete_list.append("/etc/dhcp/dhclient-exit-hooks.d/netd-dhclient-exit-hook")
        delete_list.append("/etc/dhcp/dhclient-enter-hooks.d/netd-dhclient-enter-hook")

    def write_enter_hook(self, settings, prefix=""):
        filename = prefix + self.enter_hook_filename
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

""")

        for interface_settings in settings['interfaces']:
            if interface_settings['configType'] == 'ADDRESSED' and interface_settings['v4ConfigType'] == 'AUTO':

                file.write("if [ \"$interface\" = \"%s\" ] || [ \"$interface\" = \"%s\" ] ; then" % (interface_settings['systemDev'], interface_settings['symbolicDev']) + "\n")
                file.write("    DHCP_INTERFACE_INDEX=%s" % interface_settings['interfaceId'] + "\n")

                if 'v4AutoAddressOverride' in interface_settings and interface_settings['v4AutoAddressOverride'] != None and interface_settings['v4AutoAddressOverride'].strip() != "":
                    file.write("    DHCP_ADDRESS_OVERRIDE=\"%s\"" % interface_settings['v4AutoAddressOverride'] + "\n")

                if 'v4AutoNetmaskOverride' in interface_settings and interface_settings['v4AutoNetmaskOverride'] != None and interface_settings['v4AutoNetmaskOverride'].strip() != "":
                    file.write("    DHCP_NETMASK_OVERRIDE=\"%s\"" % interface_settings['v4AutoNetmaskOverride'] + "\n")

                if 'v4AutoGatewayOverride' in interface_settings and interface_settings['v4AutoGatewayOverride'] != None and interface_settings['v4AutoGatewayOverride'].strip() != "":
                    file.write("    DHCP_GATEWAY_OVERRIDE=\"%s\"" % interface_settings['v4AutoGatewayOverride'] + "\n")

                if 'v4AutoDns1Override' in interface_settings and interface_settings['v4AutoDns1Override'] != None and interface_settings['v4AutoDns1Override'].strip() != "":
                    file.write("    DHCP_DNS_OVERRIDES=\"%s\"" % interface_settings['v4AutoDns1Override'] + "\n")

                if 'v4AutoDns2Override' in interface_settings and interface_settings['v4AutoDns2Override'] != None and interface_settings['v4AutoDns2Override'].strip() != "":
                    file.write("    DHCP_DNS_OVERRIDES=\"${DHCP_DNS_OVERRIDES} %s\"" % interface_settings['v4AutoDns2Override'] + "\n")

                file.write("fi " + "\n")
                file.write("\n")

        file.write(r"""
## Debug function
#DEBUG=/bin/true
DEBUG=debug

debug()
{
    #/bin/echo -e "[DEBUG: `date`] ${*}"
    /bin/echo -e "${*}" | logger -t uvmdhcp
}

## Return a list of interfaces that are in bridge. 
bridge_port_list()
{
    local l_bridge="$1"
    
    test -n "${l_bridge}" && {
        find /sys/class/net/${l_bridge}/brif/ -maxdepth 1 -mindepth 1 -exec basename {} \; 2>/dev/null
    }
}

wait_for_bridge()
{
    ## Wait bridge check attempts for the bridge to come up(if this is a bridge)
    BRIDGE_CHECK_ATTEMPTS=15
    ## This is the time to wait in between checking the bridge status
    BRIDGE_CHECK_INTERVAL=1
    local t_interface
    local t_ready="${BRIDGE_CHECK_ATTEMPTS}"
    local t_count=0
    

    while [ "$t_count" -lt $BRIDGE_CHECK_ATTEMPTS ] ; do 
        t_ready="true";
        ## Iterate all of the interfaces in the bridge
        for t_interface in `bridge_port_list ${interface}`; do
            ## Skip the files that don't exist.
            test -f /sys/class/net/${t_interface}/brport/state || continue ;
            
            ## Search for interfaces that are disabled or forwarding
            grep -q "[03]" /sys/class/net/${t_interface}/brport/state || t_ready="false"  ;
        done
        
        ${t_ready} && break ;
        
        sleep ${BRIDGE_CHECK_INTERVAL} ;
        t_count = $(($t_count + 1))  
        
    done 

    if [ ${t_count} -gt 0 ] ; then
        debug "Waited ${t_count} counts for the bridge(s) before configuring ${interface}."
    fi
}

${DEBUG} "dhclient-enter-hooks.d/untangle-dhclient-enter-hook ENTER [ reason: \"$reason\" interface: \"$interface\" ]"
${DEBUG} "dhclient-enter-hooks.d/untangle-dhclient-enter-hook ENTER [ old_ip_address: \"$old_ip_address\" ]"
${DEBUG} "dhclient-enter-hooks.d/untangle-dhclient-enter-hook ENTER [ new_ip_address: \"$new_ip_address\" ]"
${DEBUG} "dhclient-enter-hooks.d/untangle-dhclient-enter-hook ENTER [ new_domain_name_servers: \"$new_domain_name_servers\" ]"
${DEBUG} "dhclient-enter-hooks.d/untangle-dhclient-enter-hook ENTER [ new_domain_name: \"$new_domain_name\" ]"
${DEBUG} "dhclient-enter-hooks.d/untangle-dhclient-enter-hook ENTER [ DHCP_INTERFACE_INDEX: \"$DHCP_INTERFACE_INDEX\" ]"
${DEBUG} "dhclient-enter-hooks.d/untangle-dhclient-enter-hook ENTER [ DHCP_ADDRESS_OVERRIDE: \"$DHCP_ADDRESS_OVERRIDE\" ]"
${DEBUG} "dhclient-enter-hooks.d/untangle-dhclient-enter-hook ENTER [ DHCP_NETMASK_OVERRIDE: \"$DHCP_NETMASK_OVERRIDE\" ]"
${DEBUG} "dhclient-enter-hooks.d/untangle-dhclient-enter-hook ENTER [ DHCP_GATEWAY_OVERRIDE: \"$DHCP_GATEWAY_OVERRIDE\" ]"
${DEBUG} "dhclient-enter-hooks.d/untangle-dhclient-enter-hook ENTER [ DHCP_DNS_OVERRIDES: \"$DHCP_DNS_OVERRIDES\" ]"

${DEBUG} "Overriding make_resolv_conf()."

# Override this function to change the behavior dhclient-script later call it to write resolv.conf
make_resolv_conf() 
{ 
    # we used to store this config in dnsmasq.conf in 11.0 and prior (remove it if it still exists)
    sed -i -e "/^#*\s*server=.*uplink.${DHCP_INTERFACE_INDEX}$/d" /etc/dnsmasq.conf

    # remove this interfaces line from list of servers
    if [ ! -f /etc/dnsmasq.d/dhcp-upstream-dns-servers ] ; then
        touch /etc/dnsmasq.d/dhcp-upstream-dns-servers
    fi
    sed -i -e "/^#*\s*server=.*uplink.${DHCP_INTERFACE_INDEX}$/d" /etc/dnsmasq.d/dhcp-upstream-dns-servers

    if [ -n "$new_domain_name" -o -n "$new_domain_name_servers" ]; then
        local t_hash="`md5sum /etc/dnsmasq.d/dhcp-upstream-dns-servers`"
        
        if [ -n "$new_domain_name_servers" ]; then
            for nameserver in $new_domain_name_servers ; do
                /bin/echo -e "server=${nameserver} # uplink.${DHCP_INTERFACE_INDEX}" >> /etc/dnsmasq.d/dhcp-upstream-dns-servers
            done
        fi

        local t_new_hash="`md5sum /etc/dnsmasq.d/dhcp-upstream-dns-servers`"
                    
        ## Reststart DNS MASQ if necessary
        if [ "${t_hash}x" != "${t_new_hash}x" ]; then
            /bin/echo -e "[DEBUG: `date`] /etc/dnsmasq.d/dhcp-upstream-dns-servers changed. Restarting dnsmasq..."
            systemctl --no-block restart dnsmasq
            /bin/echo -e "[DEBUG: `date`] /etc/dnsmasq.d/dhcp-upstream-dns-servers changed. Restarting dnsmasq...done"
        fi
    fi

    return 0
}

## Wait for the bridge to come up
wait_for_bridge

case ${reason} in
    BOUND|RENEW|REBIND|REBOOT)
        ${DEBUG} "Enabling overrides on dhcp reason \"${reason}\""

        new_ip_address=${DHCP_ADDRESS_OVERRIDE:-${new_ip_address}}

        if [ -n "${DHCP_NETMASK_OVERRIDE}" ] ; then
            new_subnet_mask=${DHCP_NETMASK_OVERRIDE}
            new_subnet_arg="netmask ${DHCP_NETMASK_OVERRIDE}"
        fi

        untangle_new_routers=${DHCP_GATEWAY_OVERRIDE:-${new_routers}}
        new_routers=""

        new_domain_name_servers=${DHCP_DNS_OVERRIDES:-${new_domain_name_servers}}
        ;;
    *)
        ${DEBUG} "Ignoring overrides for dhcp reason \"${reason}\""
        ;;
esac

${DEBUG} "dhclient-enter-hooks.d/untangle-dhclient-enter-hook EXIT  [ reason: \"$reason\" interface: \"$interface\" ]"

""")

        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("DhcpManager: Wrote %s" % filename)

        return

    def write_exit_hook(self, settings, prefix=""):

        filename = prefix + self.exit_hook_filename
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

## Debug function
#DEBUG=/bin/true
DEBUG=debug

debug()
{
    #/bin/echo -e "[DEBUG: `date`] ${*}"
    /bin/echo -e "${*}" | logger -t uvmdhcp
}

refresh_routes()
{
    # point to point
	if [ "$new_subnet_mask" = "255.255.255.255" ]; then
	    for router in $untangle_new_routers; do
	    	route add -host $router dev $interface
	    done
	fi
    
    for router in $untangle_new_routers; do
        /usr/share/untangle-sync-settings/bin/add-uplink.sh ${interface} ${router} "uplink.${DHCP_INTERFACE_INDEX}" -4 
        /usr/share/untangle-sync-settings/bin/add-source-route.sh ${new_ip_address} "uplink.${DHCP_INTERFACE_INDEX}" -4
    done
}

run_post_networking_hook()
{
    if [ "`/sbin/runlevel | cut -d " " -f 2`" -lt "5" ] ; then 
        # if the runlevel is < 5, we are either in bootup or shutdown
        $DEBUG "Skipping post-network-hook.d hooks - still booting."
    elif pgrep -f 'run-parts.*post-network-hook.d' >/dev/null 2>&1 ; then
        # if we already see post-network-hook.d running, do not run it again
        $DEBUG "Skipping post-network-hook.d hooks - post-network hooks already running."
    elif pgrep -f 'ifup.*-a' >/dev/null 2>&1 ; then
        # if we already see ifup -a then it will run these scripts
        $DEBUG "Skipping post-network-hook.d hooks - "ifup -a" running."
    elif pgrep -f 'ifdown.*-a' >/dev/null 2>&1 ; then
        # if we already see ifdown -a then it will run these scripts
        $DEBUG "Skipping post-network-hook.d hooks - "ifdown -a" running."
    else
        run-parts -v /etc/untangle/post-network-hook.d
    fi
}

write_status_file()
{
    local t_interface="$1"
    local t_index="$2"
    ( [ -z "$t_interface" ] || [ -z "$t_index" ] ) && {
        return 0
    }

    $DEBUG "writing /var/lib/interface-status/interface-${t_index}-status.js"
    /usr/share/untangle-sync-settings/bin/write-interface-status.py -I ${t_interface} -i ${t_index} -w /var/lib/interface-status/interface-${t_index}-status.js

    $DEBUG "writing /var/lib/interface-status/interface-${t_interface}-status.js"
    /usr/share/untangle-sync-settings/bin/write-interface-status.py -I ${t_interface} -i ${t_index} -w /var/lib/interface-status/interface-${t_interface}-status.js
}

${DEBUG} "dhclient-exit-hooks.d/untangle-dhclient-exit-hook EXIT [ reason: \"$reason\" interface: \"$interface\" ]"
${DEBUG} "dhclient-exit-hooks.d/untangle-dhclient-exit-hook EXIT [ old_ip_address: \"$old_ip_address\" ]"
${DEBUG} "dhclient-exit-hooks.d/untangle-dhclient-exit-hook EXIT [ new_ip_address: \"$new_ip_address\" ]"
${DEBUG} "dhclient-exit-hooks.d/untangle-dhclient-exit-hook EXIT [ new_domain_name_servers: \"$new_domain_name_servers\" ]"
${DEBUG} "dhclient-exit-hooks.d/untangle-dhclient-exit-hook EXIT [ new_domain_name: \"$new_domain_name\" ]"
${DEBUG} "dhclient-exit-hooks.d/untangle-dhclient-exit-hook EXIT [ DHCP_INTERFACE_INDEX: \"$DHCP_INTERFACE_INDEX\" ]"
${DEBUG} "dhclient-exit-hooks.d/untangle-dhclient-exit-hook EXIT [ DHCP_ADDRESS_OVERRIDE: \"$DHCP_ADDRESS_OVERRIDE\" ]"
${DEBUG} "dhclient-exit-hooks.d/untangle-dhclient-exit-hook EXIT [ DHCP_NETMASK_OVERRIDE: \"$DHCP_NETMASK_OVERRIDE\" ]"
${DEBUG} "dhclient-exit-hooks.d/untangle-dhclient-exit-hook EXIT [ DHCP_GATEWAY_OVERRIDE: \"$DHCP_GATEWAY_OVERRIDE\" ]"
${DEBUG} "dhclient-exit-hooks.d/untangle-dhclient-exit-hook EXIT [ DHCP_DNS_OVERRIDES: \"$DHCP_DNS_OVERRIDES\" ]"

# Execute the operation
case "$reason" in

    MEDIUM|ARPCHECK|ARPSEND)
        # Do nothing
        ;;

    PREINIT|FAIL)
        # Do nothing
        ;;

    REBOOT)
        refresh_routes
        write_status_file ${interface} ${DHCP_INTERFACE_INDEX}
        # Do not run post networking hooks (we are booting up and about to run them)
        ;;

    BOUND)
        refresh_routes
        write_status_file ${interface} ${DHCP_INTERFACE_INDEX}
        run_post_networking_hook 
        ;;

    RENEW|REBIND)
        # if we have a different address, then restart networking, otherwise do nothing
        if [ "$old_ip_address" != "$new_ip_address" ]; then
            refresh_routes
            write_status_file ${interface} ${DHCP_INTERFACE_INDEX}
            run_post_networking_hook
        fi
        ;;

    EXPIRE|RELEASE|STOP)
        write_status_file ${interface} ${DHCP_INTERFACE_INDEX}
        run_post_networking_hook
        ;;

    TIMEOUT)
        set -- $untangle_new_routers
        first_router="$1"

        if [ -z "$first_router" ] || ping -q -c 1 $first_router; then
            if [ "$new_ip_address" != "$alias_ip_address" -a -n "$alias_ip_address" ]; then
                ifconfig $interface:0 inet $alias_ip_address $alias_subnet_arg
                route add -host $alias_ip_address dev $interface:0
            fi
	    
            for router in $untangle_new_routers; do
                /usr/share/untangle-sync-settings/bin/add-uplink.sh ${interface} ${router} "uplink.${DHCP_INTERFACE_INDEX}" -4 
            done

            make_resolv_conf
        else
            # Changed from 'ifconfig $interface inet 0 down' - see Debian bug #144666
            ifconfig $interface inet 0
            exit_with_hooks 2 "$@"
        fi

        write_status_file ${interface} ${DHCP_INTERFACE_INDEX}
        run_post_networking_hook
        ;;

esac

${DEBUG} "dhclient-exit-hooks.d/untangle-dhclient-exit-hook EXIT  [ reason: \"$reason\" interface: \"$interface\" ]"

true

""")

        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("DhcpManager: Wrote %s" % filename)

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

        file.write("# Kill any running dhcp client" + "\n")
        file.write("pkill -QUIT '(dhclient|dhclient3|pump)' && { sleep 1 ; pkill '(dhclient|dhclient3|pump)'; }")
        file.write("\n\n")

        file.write("# Delete old DHCP dns servers (this will be recreated)" + "\n")
        file.write("rm -f /etc/dnsmasq.d/dhcp-upstream-dns-servers" + "\n")
        file.write("\n\n")

        file.write("true" + "\n")

        file.flush()
        file.close()
        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("DhcpManager: Wrote %s" % filename)

    def write_dhcp_conf_file(self, settings, prefix=""):
        filename = prefix + self.dhcp_conf_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        file.write("timeout 40;" + "\n")
        file.write("retry 15;" + "\n")
        file.write("\n\n")
        hostname = settings.get('hostName')
        if hostname != None:
            file.write("send host-name \"%s\";" % hostname + "\n")

        file.flush()
        file.close()
        print("DhcpManager: Wrote %s" % filename)

    def write_dhcp_ddclient_file(self, settings, prefix=""):
        filename = prefix + self.ddclient_hook_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/bin/sh")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")

        file.write("\n\n")
        file.write("# The dhcp exit hook packaged with ddclient has syntax error" + "\n")
        file.write("# Since the DHCP hooks are sources, syntax erros break DHCP" + "\n")
        file.write("# This blank script is written to replace it" + "\n")

        file.flush()
        file.close()
        print("DhcpManager: Wrote %s" % filename)


registrar.register_manager(DhcpManager())
