import os
import stat
import pwd
import grp
import re
import shutil
import sys

from collections import OrderedDict
from sync.iptables_util import IptablesUtil
from sync import registrar,Manager,NetworkUtil,Variables,IptablesUtil

class WireguardManager(Manager):
    """
    This class is responsible for generating wireguard configuration
    based on the settings object passed from sync-settings
    """
    wireguard_vpn_conf = '/etc/wireguard/wg0.conf'
    wireguard_remote_conf_dir = '/etc/wireguard/untangle'
    wireguard_iptables_script = '/etc/untangle/iptables-rules.d/720-wireguard-vpn'

    iptables_table_chain_rules = {
        "mangle": {
            # Set source interface mark 
            "mark-src-intf": [{
                'new': 'insert',
                'index': 3,
                'rule': '-i $WG_INTERFACE -j MARK --set-mark {src_mark} -m comment --comment "Set src interface mark for wireguard vpn"'
            }],
            "mark-dst-intf": [{
                'new': 'insert',
                'index': 3,
                'rule': '-o $WG_INTERFACE -j MARK --set-mark {dst_mark} -m comment --comment "Set dst interface mark for wireguard vpn"'
            }],
            "mark-dst-intf": [{
                'new': 'insert',
                'index': 3,
                'rule': '-o $WG_INTERFACE -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu -m comment --comment "Perform mss clamping for wireguard vpn"'
            }]
        },
    }

    def initialize(self):
        """
        Register settings of interest and our file
        """
        registrar.register_settings_file("wireguard-vpn", self)
        registrar.register_file(self.wireguard_vpn_conf, "restart-wireguard", self)
        registrar.register_file(self.wireguard_iptables_script, "restart-iptables", self)
        ## !! need to remove all files.  Maybe rsync instead of cp?
        registrar.register_file(self.wireguard_remote_conf_dir + "/*", "restart-wireguard", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        """
        Synchronize our file by modifying.  This is different than how other managers.
        """
        self.write_wireguard_vpn_local_configuration(settings_file, prefix)
        self.write_wireguard_vpn_remote_configuration(settings_file, prefix)
        self.write_wireguard_iptables_script(settings_file, prefix)

    def write_wireguard_vpn_local_configuration(self, settings_file, prefix):
        """
        Write wireguard configuration for wg-quick
        """
        if settings_file.id != 'wireguard-vpn':
            return

        self.out_file_name = prefix + self.wireguard_vpn_conf
        self.out_file_dir = os.path.dirname(self.out_file_name)
        if not os.path.exists(self.out_file_dir):
            os.makedirs(self.out_file_dir)
        self.out_file = open(self.out_file_name, "w+")

        # Interface
        self.out_file.write("[Interface]\n")
        self.out_file.write("PrivateKey={privateKey}\n".format(privateKey=settings_file.settings.get('privateKey')))
        address =  settings_file.settings.get('addressPool')
        if address is not None:
            self.out_file.write("Address={address}\n".format(address=address.split('/')[0]))
        self.out_file.write("ListenPort={listenPort}\n".format(listenPort=settings_file.settings.get('listenPort')))
        if settings_file.settings.get('mtu') != 0:
            self.out_file.write("MTU={mtu}\n".format(mtu=settings_file.settings.get('mtu')))
        self.out_file.write("\n")

        # Peers
        keepaliveInterval = settings_file.settings.get('keepaliveInterval')
        for tunnel in settings_file.settings.get('tunnels'):
            if tunnel.get('enabled') == False:
                continue
            self.out_file.write("[Peer]\n")
            self.out_file.write("# {name}\n".format(name=tunnel.get('description')))
            self.out_file.write("PublicKey={publicKey}\n".format(publicKey=tunnel.get('publicKey')))
            if tunnel.get('endpointDynamic') == False:
                self.out_file.write("Endpoint={endpointHostname}:{endpointPort}\n".format(endpointHostname=tunnel.get('endpointHostname'), endpointPort=tunnel.get('endpointPort')))
            allowedIps = []
            allowedIps.append(tunnel.get('peerAddress'))
            for network in tunnel.get('networks').split():
                allowedIps.append(network)
            self.out_file.write("AllowedIPs={allowedIps}\n".format(allowedIps=','.join(allowedIps)))

            # only enable keepalives for static endpoints
            if tunnel.get('endpointDynamic') == False and keepaliveInterval != 0:
                self.out_file.write("PersistentKeepalive={keepaliveInterval}\n".format(keepaliveInterval=keepaliveInterval))

            self.out_file.write("\n")


        self.out_file.flush()
        self.out_file.close()
        os.chmod(self.out_file_name, stat.S_IRUSR | stat.S_IWUSR)

        print("WireguardManager: Wrote %s" % self.out_file_name)

    def write_wireguard_vpn_remote_configuration(self, settings_file, prefix):
        """
        Write remote wireguard configuration for wg-quick
        """
        if settings_file.id != 'wireguard-vpn':
            return

        if "tunnels" not in settings_file.settings:
            return

        for tunnel in settings_file.settings.get("tunnels"):
            if tunnel.get('enabled') == False:
                continue

            self.out_file_name = prefix + self.wireguard_remote_conf_dir + "/remote-" + tunnel.get("publicKey").strip() + ".conf"
            self.out_file_dir = os.path.dirname(self.out_file_name)
            if not os.path.exists(self.out_file_dir):
                os.makedirs(self.out_file_dir)
            self.out_file = open(self.out_file_name, "w+")

            # Interface
            self.out_file.write("[Interface]\n")
            if tunnel.get("privateKey") != "":
                self.out_file.write("PrivateKey={privateKey}\n".format(privateKey=tunnel.get("privateKey")))
            else:
                self.out_file.write("PrivateKey=\n")
            self.out_file.write("Address={address}\n".format(address=tunnel.get("peerAddress")))
            if tunnel.get("endpointDynamic") == False:
                self.out_file.write("ListenPort={listenPort}\n".format(listenPort=tunnel.get('endpointPort')))
            if settings_file.settings.get("dnsServer") != "":
                self.out_file.write("DNS={dnsServer}\n".format(dnsServer=settings_file.settings.get("dnsServer")))

            self.out_file.write("\n")
            self.out_file.write("[Peer]\n")
            self.out_file.write("# {name}\n".format(name=Variables.get('wireguardHostname')))
            self.out_file.write("PublicKey={publicKey}\n".format(publicKey=settings_file.settings.get('publicKey')))
            self.out_file.write("Endpoint={endpointHostname}:{endpointPort}\n".format(endpointHostname=Variables.get("wireguardUrl").split(":")[0], endpointPort=settings_file.settings.get('listenPort')))
            allowedIps = []
            for network in settings_file.settings.get('networks'):
                allowedIps.append(network.get('address'))
            allowedIps.insert(0, settings_file.settings.get('addressPool').split("/")[0])
            self.out_file.write("AllowedIPs={allowedIps}\n".format(allowedIps=','.join(allowedIps)))

            self.out_file.write("\n")

            self.out_file.flush()
            self.out_file.close()
            os.chmod(self.out_file_name, stat.S_IRUSR | stat.S_IWUSR)
            print("WireguardManager: Wrote %s" % self.out_file_name)

        # shutil.rmtree(self.wireguard_remote_conf_dir)

    def write_wireguard_iptables_script(self, settings_file, prefix):
        """
        Write wireguard configuration for wg-quick
        """
        if bool(NetworkUtil.settings) is False:
            # Network settings must be specified
            raise Exception("Network settings not specified")

        delete_rules, new_rules = IptablesUtil.write_wireguard_iptables_rules(self.iptables_table_chain_rules)

        self.out_file_name = prefix + self.wireguard_iptables_script
        self.out_file_dir = os.path.dirname(self.out_file_name)
        if not os.path.exists(self.out_file_dir):
            os.makedirs(self.out_file_dir)
        self.out_file = open(self.out_file_name, "w+")

        self.out_file.write("#!/bin/dash\n")
        self.out_file.write("## DO NOT EDIT. Changes will be overwritten.\n\n")

        self.out_file.write('if [ -z "$IPTABLES" ] ; then IPTABLES=/sbin/iptables ; fi' + "\n\n")
        self.out_file.write('WG_INTERFACE=$(ip link show | grep "wg[[:digit:]]\+:" | cut -d\' \' -f2 | cut -d: -f1 | head -1)' + "\n\n")

        self.out_file.write('##'"\n")
        self.out_file.write('## Delete current rules'"\n")
        self.out_file.write('##'"\n")
        for rule in delete_rules:
            self.out_file.write(rule + "\n")

        self.out_file.write("\n"'##'"\n")
        self.out_file.write('## Add new rules'"\n")
        self.out_file.write('##'"\n")
        self.out_file.write('if [ "$WG_INTERFACE" != "" ] ; then ' + "\n")
        for rule in new_rules:
            self.out_file.write('    ' + rule + "\n")
        self.out_file.write('fi' + "\n")

        self.out_file.flush()
        self.out_file.close()
        os.chmod(self.out_file_name, os.stat(self.out_file_name).st_mode | stat.S_IEXEC)

        print("WireguardManager: Wrote %s" % self.out_file_name)
        
registrar.register_manager(WireguardManager())
