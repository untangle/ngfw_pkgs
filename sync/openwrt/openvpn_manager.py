"""This class is responsible for writing the openvpn settings"""
# pylint: disable=unused-argument
# pylint: disable=line-too-long
# pylint: disable=no-self-use
import os
import stat
from sync import registrar

class OpenvpnManager:
    """SystemManager manages the openvpn settings"""
    ifup_openvpn_filename = "/etc/config/ifup.d/30-openvpn"
    ifup_openvpn_file = None
    ifdown_openvpn_filename = "/etc/config/ifdown.d/30-openvpn"
    ifdown_openvpn_file = None

    def initialize(self):
        """initialize this module"""
        registrar.register_file(self.ifup_openvpn_filename, "restart-openvpn", self)
        registrar.register_file(self.ifdown_openvpn_filename, "restart-openvpn", self)

    def sanitize_settings(self, settings):
        """sanitizes settings"""
        pass

    def validate_settings(self, settings):
        """validates settings"""
        interfaces = settings.get('network').get('interfaces')
        for intf in interfaces:
            if enabled_openvpn(intf):
                if intf.get('openvpnConfFile') is None or intf.get('openvpnConfFile') == "":
                    raise Exception("No configuration file specified for openvpn interface " + intf.get('name'))

                if os.path.isfile(intf.get('openvpnConfFile')) is False:
                    raise Exception("Configuration file " + intf.get('openvpnConfFile') + " for openvpn interface " + intf.get('name') + " does not exist")

    def create_settings(self, settings, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)

    def sync_settings(self, settings, prefix, delete_list):
        """syncs settings"""
        print("%s: Syncing settings" % self.__class__.__name__)
        self.write_ifup_openvpn_file(settings, prefix)
        self.write_ifdown_openvpn_file(settings, prefix)

    def write_ifup_openvpn_file(self, settings, prefix=""):
        """write_ifup_openvpn_file writes /etc/config/ifup.d/30-openvpn"""
        filename = prefix + self.ifup_openvpn_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.ifup_openvpn_file = open(filename, "w+")
        file = self.ifup_openvpn_file
        file.write("#!/bin/sh")
        file.write("\n\n")
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n")
        file.write(". /lib/functions/network.sh\n")
        file.write("\n")
        file.write("INTERFACE=$1\n")
        file.write("DEVICE=$2\n")
        file.write("\n")

        file.write("[ loopback = \"$INTERFACE\" ] && {\n")
        interfaces = settings.get('network').get('interfaces')
        for intf in interfaces:
            if enabled_openvpn(intf):
                identifier = "%s-%s" % (intf.get('name'), intf.get('device'))
                file.write("\topenvpn --daemon %s --config %s --writepid /var/run/openvpn-%s.pid --status /var/run/openvpn-%s.status 10\n\n" % (intf.get('name'), intf.get('openvpnConfFile'), identifier, identifier))

        file.write("}\n")

        file.flush()
        file.close()
        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)

        print("%s: Wrote %s" % (self.__class__.__name__, filename))

    def write_ifdown_openvpn_file(self, settings, prefix=""):
        """write_ifdown_openvpn_file writes /etc/config/ifdown.d/30-openvpn"""
        filename = prefix + self.ifdown_openvpn_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.ifdown_openvpn_file = open(filename, "w+")
        file = self.ifdown_openvpn_file
        file.write("#!/bin/sh")
        file.write("\n\n")
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n")
        file.write(". /lib/functions/network.sh\n")
        file.write("\n")
        file.write("INTERFACE=$1\n")
        file.write("\n")

        file.write("[ loopback = \"$INTERFACE\" ] && {\n")
        interfaces = settings.get('network').get('interfaces')
        for intf in interfaces:
            if enabled_openvpn(intf):
                identifier = "%s-%s" % (intf.get('name'), intf.get('device'))
                file.write("\tkill -2 `cat /var/run/openvpn-%s.pid` > /dev/null 2>&1\n" % identifier)
                file.write("\trm -f /var/run/openvpn-%s.pid\n" % identifier)
                file.write("\trm -f /var/run/openvpn-%s.status\n\n" % identifier)
        file.write("}\n")

        file.flush()
        file.close()
        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)

        print("%s: Wrote %s" % (self.__class__.__name__, filename))

def enabled_openvpn(intf):
    """returns true if the interface is an enabled openvpn interface"""
    if intf.get('configType') != 'DISABLED' and intf.get('type') == 'OPENVPN':
        return True
    return False

registrar.register_manager(OpenvpnManager())
