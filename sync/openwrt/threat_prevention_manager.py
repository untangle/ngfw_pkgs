"""This class is responsible for managing threat prevention settings"""
# pylint: disable=unused-argument
import os
import stat
import json
from sync import registrar, Manager

class ThreatPreventionManager(Manager):
    """ThreatPreventionManager manages the threat prevention settings"""
    bctid_filename = "/etc/config/bcti.cfg"
    tp_rules_sys_filename = "/etc/config/nftables-rules.d/207-tp-rules"

    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.bctid_filename, "restart-bctid", self)
        registrar.register_file(self.tp_rules_sys_filename, "restart-nftables-rules", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        """syncs settings"""

        self.write_bctid_file(settings_file.settings, prefix)
        self.write_tp_net_rules(settings_file.settings, prefix)

    def create_settings(self, settings_file, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        settings_file.settings['threatprevention'] = {}
        settings_file.settings['threatprevention'] = {
            "enabled": True,
            "passList": [],
            "sensitivity" : "25",
            "redirect" : False,
        }

    def get_uid(self):
        "Get the system's uid"
        file = open("/etc/config/uid", "r")
        uid = file.read()
        file.close()
        return uid

    def write_bctid_file(self, settings, prefix):
        "write the bctid file"
        filename = prefix + self.bctid_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        # grab the 'stock' bcti.cfg
        stock = open("/usr/share/untangle-bctid/bcti.cfg", "r")
        contents = stock.read()
        stock.close()

        # Add this device UID
        contents = contents.replace('UID=XXX','UID=' + self.get_uid())

        # write it to /etc/config
        file = open(filename, "w+")
        file.write(contents)
        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("ThreatPreventionManager: Wrote %s" % filename)
        return

    def write_tp_net_rules(self, settings, prefix):
        "write the tp rules file"
        filename = prefix + self.tp_rules_sys_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/bin/sh")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")
        file.write(r"""
nft flush chain ip nat tp-prerouting
nft delete set ip nat tp_redirect

nft add set ip nat tp_redirect "{ type ct_id; flags timeout; timeout 15m; gc-interval 20m; }"
nft add chain nat tp-prerouting "{ type nat hook prerouting priority -100; }"
nft add rule nat tp-prerouting ct id @tp_redirect ip protocol {icmp, udp} drop
""")
        lan_ip = os.popen("ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | head -1").read().rstrip()
        redirect = settings.get('threatprevention').get('redirect')

        print(f"lan_ip {lan_ip}, redirect {redirect}")

        if redirect:
            file.write(r"""
nft add rule nat tp-prerouting ct id @tp_redirect tcp dport 1-79 drop
nft add rule nat tp-prerouting ct id @tp_redirect tcp dport 81-442 drop
nft add rule nat tp-prerouting ct id @tp_redirect tcp dport 444-65535 drop
""")
            file.write(f"nft add rule nat tp-prerouting ct id @tp_redirect tcp dport 443 dnat {lan_ip}:8486\n")
            file.write(f"nft add rule nat tp-prerouting ct id @tp_redirect tcp dport 80 dnat {lan_ip}:8485\n")
        else:
            file.write("nft add rule nat tp-prerouting ct id @tp_redirect drop")

        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)

        print("ThreatPreventionManager: Wrote %s" % filename)
        return
        

registrar.register_manager(ThreatPreventionManager())
