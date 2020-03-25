import os
import stat
import pwd
import grp
import re
import sys

from collections import OrderedDict
from sync.iptables_util import IptablesUtil
from sync import registrar,Manager,NetworkUtil

class WireguardManager(Manager):
    """
    This class is responsible for generating wireguard configuration
    based on the settings object passed from sync-settings
    """
    wireguard_vpn_conf = '/etc/wireguard/wg0.conf'
    wireguard_iptables_script = '/etc/untangle/iptables-rules.d/720-wireguard-vpn'

    delete_rule_template = "$IPTABLES -t {table} -D {chain} {rule} >/dev/null 2>&1"
    add_rule_template = "$IPTABLES -t {table} -A {chain} {rule}"
    insert_rule_template = "$IPTABLES -t {table} -I {chain} {index} {rule}"

    iptables_rule_comment_re = re.compile(r'--comment "([^"]+)"')

    iptables_table_format_map = {
        'src_mark': '0xf9/0xff',
        'dst_mark': '0xf900/0xff00',
        'wireguard_ip_address': '',
        # wan_mark is a special case that needs to duplicate the rule
        # for as many wan interfaces are available.
        'wan_mark': '{wan_mark}'
    }

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
            }]
        },
        "nat": {
            "nat-rules": [{
                'new': 'add',
                'rule': '-m mark --mark {src_mark} -j MASQUERADE -m comment --comment "nat wireguard vpn traffic to the server"'
            },{
                'new': 'insert',
                'rule': '-m mark --mark {wan_mark}/0xffff -j MASQUERADE -m comment --comment "NAT WAN-bound wireguard vpn traffic"'
            }],
            "port-forward-rules": [{
                'new': 'insert',
                'rule': '-p tcp -d {wireguard_ip_address} --destination-port 443 -j REDIRECT --to-ports 443 -m comment --comment "Send wireguard VPN to apache http"'
            },{
                'new': 'insert',
                'rule': '-p tcp -d {wireguard_ip_address} --destination-port 80 -j REDIRECT --to-ports 80 -m comment --comment "Send wireguard to apache https"'
            }]
        },
        "filter": {
            "nat-reverse-filter": [{
                'new': 'insert',
                'rule': '-m mark --mark {src_mark} -j RETURN -m comment --comment "Allow wireguard vpn"'
            }]
        }
    }

    def initialize(self):
        """
        Register settings of interest and our file
        """
        registrar.register_settings_file("wireguard-vpn", self)
        registrar.register_file(self.wireguard_vpn_conf, "restart-wireguard", self)
        registrar.register_file(self.wireguard_iptables_script, "restart-iptables", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        """
        Synchronize our file by modifying.  This is different than how other managers.
        """
        self.write_wireguard_vpn_configuration(settings_file, prefix)
        self.write_wireguard_iptables_scriptiguration(settings_file, prefix)

    def write_wireguard_vpn_configuration(self, settings_file, prefix):
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
        self.out_file.write("Address={address}\n".format(address=settings_file.settings.get('addressPool')))
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
                self.out_file.write("Endpoint={endpointAddress}:{endpointPort}\n".format(endpointAddress=tunnel.get('endpointAddress'), endpointPort=tunnel.get('endpointPort')))
            allowedIps = tunnel.get('networks')
            allowedIps.insert(0, tunnel.get('peerAddress'))
            self.out_file.write("AllowedIPs={allowedIps}\n".format(allowedIps=','.join(allowedIps)))
            if keepaliveInterval != 0:
                self.out_file.write("PersistentKeepalive={keepaliveInterval}\n".format(keepaliveInterval=keepaliveInterval))

            self.out_file.write("\n")


        self.out_file.flush()
        self.out_file.close()
        os.chmod(self.out_file_name, os.stat(self.out_file_name).st_mode | stat.S_IEXEC)

        print("WireguardManager: Wrote %s" % self.out_file_name)

    def write_wireguard_iptables_scriptiguration(self, settings_file, prefix):
        """
        Write wireguard configuration for wg-quick
        """
        if bool(NetworkUtil.settings) is False:
            # Network settings must be specified
            raise Exception("Network settings not specified")

        wan_marks = []
        for interface_id in NetworkUtil.wan_list():
            wan_marks.append(hex((interface_id << 8) + 0x00fa))
        
        self.iptables_table_format_map['wireguard_ip_address'] = settings_file.settings.get('addressPool').split('/')[0]

        delete_rules = []
        new_rules = []
        for table in sorted(self.iptables_table_chain_rules.keys()):
            for chain in sorted(self.iptables_table_chain_rules[table].keys()):
                format_map = {'table': table, 'chain': chain}
                for rule in self.iptables_table_chain_rules[table][chain]:
                    updated_rule = rule['rule'].format_map(self.iptables_table_format_map)

                    format_map['comment'] = None
                    if 'comment' in rule:
                        format_map['comment'] = rule['comment']
                    else:
                        match = re.search(self.iptables_rule_comment_re, rule['rule'])
                        if match:
                            format_map['comment'] = match.group(1)

                    if format_map['comment'] is not None:
                        delete_rules.append('## {comment}'.format_map(format_map))
                        new_rules.append('## {comment}'.format_map(format_map))

                    if '{wan_mark}' in updated_rule:
                        for wan_mark in wan_marks:
                            format_map['rule'] = updated_rule.format(wan_mark=wan_mark)
                            delete_rules.append(self.delete_rule_template.format_map(format_map))
                            new_rules.append(self.create_new_rule(rule, format_map))
                    else:
                        format_map['rule'] = updated_rule
                        delete_rules.append(self.delete_rule_template.format_map(format_map))
                        new_rules.append(self.create_new_rule(rule, format_map))

                    delete_rules.append("")
                    new_rules.append("")

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

    def create_new_rule(self, rule, format_map):
        """
        Create a new (add or insert) iptables rule
        """
        template = self.add_rule_template
        if 'new' in rule and rule['new'] == 'insert':
            template = self.insert_rule_template
            if 'index' in rule:
                format_map['index'] = rule['index']
            else:
                format_map['index'] = ''

        new_rule = template.format_map(format_map)
        if 'index' in rule:
            del rule['index']
        return new_rule
        
registrar.register_manager(WireguardManager())
