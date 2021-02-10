"""This class is responsible for managing threat prevention settings"""
# pylint: disable=unused-argument
import os
import stat
from sync import registrar, Manager

class ThreatPreventionManager(Manager):
    """ThreatPreventionManager manages the threat prevention settings"""
    bctid_filename = "/etc/config/bcti.cfg"

    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.bctid_filename, "restart-bctid", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        """syncs settings"""

        self.write_bctid_file(settings_file.settings, prefix)

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
