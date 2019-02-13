"""This class is responsible for writing the system settings"""
# pylint: disable=unused-argument
import os
import stat
from sync import registrar

class SystemManager:
    """SystemManager manages the system settings"""
    timezone_setter_filename = "/etc/config/startup.d/010-timezone"

    def initialize(self):
        """initialize this module"""
        registrar.register_file(self.timezone_setter_filename, "startup-scripts", self)

    def sanitize_settings(self, settings):
        """sanitizes settings"""
        pass

    def validate_settings(self, settings):
        """validates settings"""
        pass

    def create_settings(self, settings, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        settings['system'] = {}
        settings['system']['hostName'] = 'mfw'
        settings['system']['domainName'] = 'example.com'
        settings['system']['timeZone'] = 'UTC'
        settings['system']['setupWizard'] = {"completed": False}

    def sync_settings(self, settings, prefix, delete_list):
        """syncs settings"""
        system = settings.get('system')
        if system is None:
            return
        time_zone = system.get('timeZone')
        if time_zone is None:
            return
        self.write_timezone_setter(time_zone, prefix)

    def write_timezone_setter(self, time_zone, prefix):
        """Write the script to set the timezone in /etc/config/system"""
        filename = prefix + self.timezone_setter_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/bin/sh")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        file.write('TMPFILE="/tmp/system"\n')
        file.write(r'''/bin/sed -e "s/option timezone .*/option timezone '%s'/" /etc/config/system > $TMPFILE''' % time_zone)
        file.write('\n\n')

        file.write('if ! diff /etc/config/system $TMPFILE >/dev/null 2>&1 ; then cp $TMPFILE /etc/config/system ; fi\n')
        file.write('\n')

        file.write('rm -f $TMPFILE')
        file.write('\n')

        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("SystemManager: Wrote %s" % filename)
        return

registrar.register_manager(SystemManager())
