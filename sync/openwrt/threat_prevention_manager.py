"""This class is responsible for managing threat prevention settings"""
# pylint: disable=unused-argument
import os
import stat
import json
from sync import registrar, Manager

class ThreatPreventionManager(Manager):
    """ThreatPreventionManager manages the threat prevention settings"""
    bctid_filename = "/etc/config/bcti.cfg"
    defaultTPrules = [{
                "enabled": True,
                "description": "Accept HTTP 5455 TP on LANs (TCP/5455)",
                "ruleId": 18,
                "conditions": [{
                    "type": "DESTINATION_PORT",
                    "op": "==",
                    "value": "5455",
                    "port_protocol": 6
                }, {
                    "type": "SOURCE_INTERFACE_TYPE",
                    "op": "==",
                    "value": 2
                }],
                "action": {
                    "type": "ACCEPT"
                }
            },  {
                "enabled": True,
                "description": "Accept HTTPS 5456 TP on LANs (TCP/5456)",
                "ruleId": 19,
                "conditions": [{
                    "type": "DESTINATION_PORT",
                    "op": "==",
                    "value": "5456",
                    "port_protocol": 6
                }, {
                    "type": "SOURCE_INTERFACE_TYPE",
                    "op": "==",
                    "value": 2
                }],
                "action": {
                    "type": "ACCEPT"
                }
            }]

    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.bctid_filename, "restart-bctid", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        """syncs settings"""

        self.write_bctid_file(settings_file.settings, prefix)

    def create_settings(self, settings_file, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        settings_file.settings['threatprevention'] = {}
        settings_file.settings['threatprevention'] = {
            "enabled": True,
            "passList": [],
            "sensitivity" : "80"
        }

    def sanitize_settings(self, settings_file):
        """sanitize threatprevention creates default setting if none exists."""
        tpConfig = settings_file.settings.get('threatprevention')
        if tpConfig is None:
            settings_file.settings['threatprevention'] = {}
            settings_file.settings['threatprevention'] = {
                "enabled": True,
                "passList": [],
                "sensitivity" : "80"
            }
        tpConfig = settings_file.settings.get('threatprevention')

        # Need to enabled or add default rules to access list
        rule_enabled = tpConfig['enabled']
        rule_found = False
        accessrules = settings_file.settings['firewall']['tables']['access']['chains'][0]['rules']

        for accessrule in accessrules:
            conditions = accessrule['conditions']
            if len(conditions):
                if conditions[0]['type'] == "DESTINATION_PORT" and conditions[0]['value'] == "5455":
                    accessrule["enabled"] = rule_enabled
                    rule_found = True
                if conditions[0]['type'] == "DESTINATION_PORT" and conditions[0]['value'] == "5456":
                    accessrule["enabled"] = rule_enabled
                    rule_found = True
        if not rule_found:
            # Need insert default rules.
            # Making an assumption that last rule is the drop all rule..??
            accessrules[-1:-1] = self.defaultTPrules
            ruleindex = 1
            for accessrule in accessrules:
                accessrule['ruleId'] = ruleindex
                ruleindex += 1

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

registrar.register_manager(ThreatPreventionManager())
