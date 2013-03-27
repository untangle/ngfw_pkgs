import os
import sys
import subprocess
import datetime
import traceback
import re
from netd.network_util import NetworkUtil

# This class is responsible for writing:
# /etc/dhcp/dhclient-enter-hooks.d/netd-dhclient-enter-hook
# /etc/dhcp/dhclient-exit-hooks.d/netd-dhclient-exit-hook
# based on the settings object passed from sync-settings.py
class DhcpManager:
    enterHookFilename = "/etc/dhcp/dhclient-enter-hooks.d/netd-dhclient-enter-hook"
    exitHookFilename = "/etc/dhcp/dhclient-exit-hooks.d/netd-dhclient-exit-hook"
    preNetworkHookFilename = "/etc/untangle-netd/pre-network-hook.d/035-dhcp"

    def write_enter_hook( self, settings, prefix="", verbosity=0 ):

        filename = prefix + self.enterHookFilename
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

mkdir -p /var/log/uvm/
exec >> /var/log/uvm/dhcp.log 2>&1
""")

        for interface_settings in settings['interfaces']['list']:
            if interface_settings['v4ConfigType'] == 'AUTO':

                file.write("if [ \"$interface\" = \"%s\" ] ; then" % interface_settings['systemDev'] + "\n")
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
                file.write("\n");

        file.write(r"""
## Debug function
#DEBUG=/bin/true
DEBUG=debug

debug()
{
    /bin/echo -e "[DEBUG: `date`] ${*}"
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
    
    for (( t_count = 0 ; t_count < ${BRIDGE_CHECK_ATTEMPTS} ; t_count++ )) {
        t_ready="true"
        ## Iterate all of the interfaces in the bridge
        for t_interface in `bridge_port_list ${interface}`; do
            ## Skip the files that don't exist.
            test -f /sys/class/net/${t_interface}/brport/state || continue
            
            ## Search for interfaces that are disabled or forwarding
            grep -q "[03]" /sys/class/net/${t_interface}/brport/state || t_ready="false" 
        done
        
        ${t_ready} && break
        
        sleep ${BRIDGE_CHECK_INTERVAL}
    }
 
    if [ ${t_count} -gt 0 ] ; then
        debug "Waited ${t_count} counts for the bridge(s) before configuring ${interface}."
    fi
}

${DEBUG} "dhclient-enter-hooks.d/netd_dhclient-enter-hook ENTER [ reason: \"$reason\" interface: \"$interface\" ]"
${DEBUG} "dhclient-enter-hooks.d/netd-dhclient-enter-hook ENTER [ old_ip_address: \"$old_ip_address\" ]"
${DEBUG} "dhclient-enter-hooks.d/netd-dhclient-enter-hook ENTER [ new_ip_address: \"$new_ip_address\" ]"
${DEBUG} "dhclient-enter-hooks.d/netd-dhclient-enter-hook ENTER [ DHCP_INTERFACE_INDEX: \"$DHCP_INTERFACE_INDEX\" ]"
${DEBUG} "dhclient-enter-hooks.d/netd-dhclient-enter-hook ENTER [ DHCP_ADDRESS_OVERRIDE: \"$DHCP_ADDRESS_OVERRIDE\" ]"
${DEBUG} "dhclient-enter-hooks.d/netd-dhclient-enter-hook ENTER [ DHCP_NETMASK_OVERRIDE: \"$DHCP_NETMASK_OVERRIDE\" ]"
${DEBUG} "dhclient-enter-hooks.d/netd-dhclient-enter-hook ENTER [ DHCP_GATEWAY_OVERRIDE: \"$DHCP_GATEWAY_OVERRIDE\" ]"
${DEBUG} "dhclient-enter-hooks.d/netd-dhclient-enter-hook ENTER [ DHCP_DNS_OVERRIDES: \"$DHCP_DNS_OVERRIDES\" ]"

${DEBUG} "Overriding make_resolv_conf()."

# Override this function to change the behavior dhclient-script later call it to write resolv.conf
make_resolv_conf() 
{ 
    if [ -n "$new_domain_name" -o -n "$new_domain_name_servers" ]; then
        local t_hash="`md5sum /etc/dnsmasq.conf`"
        
        if [ -n "$new_domain_name_servers" ]; then
            for nameserver in $new_domain_name_servers ; do
                /bin/echo -e "#new_name_server=${nameserver} # uplink.${DHCP_INTERFACE_INDEX}" >> /etc/dnsmasq.conf
            done
            
            sed -i -e "/^#*\s*server=.*uplink.${DHCP_INTERFACE_INDEX}$/d" -e 's/^#new_name_server=/server=/' /etc/dnsmasq.conf
        fi

        local t_new_hash="`md5sum /etc/dnsmasq.conf`"
                    
        ## Reststart DNS MASQ if necessary
        if [ "${t_hash}x" != "${t_new_hash}x" ]; then
            /bin/echo -e "[DEBUG: `date`] /etc/dnsmasq.conf changed. Restarting dnsmasq..."
            /etc/init.d/dnsmasq restart
            /bin/echo -e "[DEBUG: `date`] /etc/dnsmasq.conf changed. Restarting dnsmasq...done"
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

        netd_new_routers=${DHCP_GATEWAY_OVERRIDE:-${new_routers}}
        new_routers=""

        new_domain_name_servers=${DHCP_DNS_OVERRIDES:-${new_domain_name_servers}}
        ;;
    *)
        ${DEBUG} "Ignoring overrides for dhcp reason \"${reason}\""
        ;;
esac


${DEBUG} "dhclient-enter-hooks.d/netd_dhclient-enter-hook EXIT  [ reason: \"$reason\" interface: \"$interface\" ]"

return 0

""")

        file.flush()
        file.close()

        os.system("chmod a+x %s" % filename)
        if verbosity > 0: print "DhcpManager: Wrote %s" % filename

        return

    def write_exit_hook( self, settings, prefix="", verbosity=0 ):

        filename = prefix + self.exitHookFilename
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

mkdir -p /var/log/uvm/
exec >> /var/log/uvm/dhcp.log 2>&1

## Debug function
#DEBUG=/bin/true
DEBUG=debug

debug()
{
    /bin/echo -e "[DEBUG: `date`] ${*}"
}

refresh_routes()
{
    # point to point
	if [ "$new_subnet_mask" == "255.255.255.255" ]; then
	    for router in $netd_new_routers; do
	    	route add -host $router dev $interface
	    done
	fi
    
    for router in $netd_new_routers; do
        /usr/share/untangle-netd/bin/add-uplink.sh ${interface} ${router} "uplink.${DHCP_INTERFACE_INDEX}"
    done
}

run_post_networking_hook()
{
    run-parts /etc/untangle-netd/post-network-hook.d
}

write_status_file()
{
    local t_interface="$1"
    local t_index="$2"
    ( [ -z "$t_interface" ] || [ -z "$t_index" ] ) && {
        return 0
    }

    $DEBUG "writing /var/lib/untangle-netd/interface-${t_index}-status.js"
    /usr/share/untangle-netd/bin/write-interface-status.py -I ${t_interface} -i ${t_index} -w /var/lib/untangle-netd/interface-${t_index}-status.js

    $DEBUG "writing /var/lib/untangle-netd/interface-${t_interface}-status.js"
    /usr/share/untangle-netd/bin/write-interface-status.py -I ${t_interface} -i ${t_index} -w /var/lib/untangle-netd/interface-${t_interface}-status.js
}

${DEBUG} "dhclient-exit-hooks.d/netd-dhclient-exit-hook ENTER [ reason: \"$reason\" interface: \"$interface\" ]"

# Execute the operation
case "$reason" in

    MEDIUM|ARPCHECK|ARPSEND)
        # Do nothing
        ;;

    PREINIT|FAIL)
        # Do nothing
        ;;

    BOUND|REBOOT)
        refresh_routes
        # dhclient is currently running, so networking is being restarted, no need to call this
        # run_post_networking_hook 
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
        run_post_networking_hook
        ;;

    TIMEOUT)
        set -- $netd_new_routers
        first_router="$1"

        if [ -z "$first_router" ] || ping -q -c 1 $first_router; then
            if [ "$new_ip_address" != "$alias_ip_address" -a -n "$alias_ip_address" ]; then
                ifconfig $interface:0 inet $alias_ip_address $alias_subnet_arg
                route add -host $alias_ip_address dev $interface:0
            fi
	    
            for router in $netd_new_routers; do
                /usr/share/untangle-netd/bin/add-uplink.sh ${interface} ${router} "uplink.${DHCP_INTERFACE_INDEX}"
            done

            make_resolv_conf
        else
            # Changed from 'ifconfig $interface inet 0 down' - see Debian bug #144666
            ifconfig $interface inet 0
            exit_with_hooks 2 "$@"
        fi

        run_post_networking_hook
        ;;

esac

${DEBUG} "dhclient-exit-hooks.d/netd-dhclient-exit-hook EXIT  [ reason: \"$reason\" interface: \"$interface\" ]"

true

""")
        
        file.flush()
        file.close()

        os.system("chmod a+x %s" % filename)
        if verbosity > 0: print "DhcpManager: Wrote %s" % filename

        # FIXME lenny support - can remove
        if os.path.exists('/etc/dhcp3'):
            os.system("cp -f %s /etc/dhcp3/dhclient-exit-hooks.d/netd-dhclient-exit-hook" % filename)
            if verbosity > 0: print "DhcpManager: Wrote %s" % "/etc/dhcp3/dhclient-exit-hooks.d/netd-dhclient-exit-hook"

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

        file.write("pkill -QUIT '(dhclient3|pump|dhclient)' && { sleep 1 ; pkill '(dhclient3|pump|dhclient)'; }")
        file.write("\n\n");
        
        file.flush()
        file.close()
        os.system("chmod a+x %s" % filename)

        if verbosity > 0: print "DhcpManager: Wrote %s" % filename


    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "DhcpManager: sync_settings()"
        
        self.write_exit_hook( settings, prefix, verbosity )
        self.write_enter_hook( settings, prefix, verbosity )
        self.write_pre_network_hook( settings, prefix, verbosity )

        return

