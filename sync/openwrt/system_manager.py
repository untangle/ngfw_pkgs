"""This class is responsible for writing the system settings"""
# pylint: disable=unused-argument
# pylint: disable=no-self-use
import os
import stat
from sync import registrar
from sync import board_util

class SystemManager:
    """SystemManager manages the system settings"""
    timezone_setter_filename = "/etc/config/startup.d/010-timezone"
    watchdog_disabler_filename = "/etc/config/startup.d/030-disable-watchdog"
    rpfilter_disabler_filename = "/etc/config/startup.d/040-disable-rpfilter"
    hostname_setter_filename = "/etc/config/startup.d/050-hostname"
    autoupgrade_filename = "/etc/crontabs/autoupgrade"

    def initialize(self):
        """initialize this module"""
        registrar.register_file(self.timezone_setter_filename, "startup-scripts", self)
        registrar.register_file(self.watchdog_disabler_filename, "startup-scripts", self)
        registrar.register_file(self.rpfilter_disabler_filename, "startup-scripts", self)
        registrar.register_file(self.hostname_setter_filename, "startup-scripts", self)
        registrar.register_file(self.autoupgrade_filename, "restart-cron", self)

    def sanitize_settings(self, settings):
        """sanitizes settings"""
        return

    def validate_settings(self, settings):
        """validates settings"""
        autoupgrade_settings = settings.get('autoUpgrade')
        if autoupgrade_settings is not None:
            if autoupgrade_settings.get('enabled') is None:
                raise Exception("Missing required autoUpgrade setting \"enabled\"")

    def create_settings(self, settings, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        settings['system'] = {}
        settings['system']['hostName'] = 'mfw'
        settings['system']['domainName'] = 'example.com'
        settings['system']['timeZone'] = {
            "displayName": "UTC",
            "value": "UTC"
        }
        settings['system']['cloud'] = {
            "enabled": True,
            "supportAccessEnabled": True,
            "cloudServers": ["cmd.untangle.com"]
        }
        if board_util.is_docker():
            settings['system']['setupWizard'] = {"completed": True}
        else:
            settings['system']['setupWizard'] = {"completed": False}

    def sync_settings(self, settings, prefix, delete_list):
        """syncs settings"""

        if board_util.is_docker():
            self.write_watchdog_disabler(prefix)
            self.write_rpfilter_disabler(prefix)

        system = settings.get('system')
        if system is None:
            return

        hostname = system.get('hostName')
        if hostname is not None:
            self.write_hostname_setter(hostname, prefix)

        autoupgrade = system.get('autoUpgrade')
        self.write_autoupgrade_file(autoupgrade, prefix)

        time_zone = system.get('timeZone')
        if time_zone is None:
            return
        # If the timezone is just a string, use that
        # In old settings.json, time_zone was just a string
        if isinstance(time_zone, str):
            self.write_timezone_setter(time_zone, prefix)
            return
        if isinstance(time_zone, dict):
            time_zone_value = time_zone.get('value')
            if time_zone_value is None:
                return
            self.write_timezone_setter(time_zone_value, prefix)
            return

    def write_hostname_setter(self, hostname, prefix):
        """Write the script to set the hostname in /etc/config/system"""
        filename = prefix + self.hostname_setter_filename
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
        file.write(r'''/bin/sed -e "s/option hostname .*/option hostname '%s'/" /etc/config/system > $TMPFILE''' % hostname)
        file.write('\n\n')

        file.write('if ! diff /etc/config/system $TMPFILE >/dev/null 2>&1 ; then cp $TMPFILE /etc/config/system ; fi\n')
        file.write('\n')

        file.write('rm -f $TMPFILE')
        file.write('\n')

        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("SystemManager: Wrote %s" % filename)

    def write_autoupgrade_file(self, autoupgrade_settings, prefix):
        """Write the autoupgrade file"""
        enabled = True
        day = 6
        hour = 0
        minute = 0
        if autoupgrade_settings is None:
            enabled = False
        else:
            if autoupgrade_settings.get('enabled') is None or autoupgrade_settings.get('enabled') is False:
                enabled = False
            day = autoupgrade_settings.get('dayOfWeek')
            hour = autoupgrade_settings.get('hourOfDay')
            minute = autoupgrade_settings.get('minuteOfHour')

        filename = prefix + self.autoupgrade_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")

        if enabled:
            file.write("%i %i * * %i /usr/bin/upgrade.sh\n" % (minute, hour, day))

        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("SystemManager: Wrote %s" % filename)

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

    def write_watchdog_disabler(self, prefix):
        """Write the script to disable watchdog in docker containers"""
        filename = prefix + self.watchdog_disabler_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/bin/sh")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        file.write("ubus call system watchdog \'{\"magicclose\": true,\"stop\": true}'\n")
        file.write("\n")

        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("SystemManager: Wrote %s" % filename)

    def write_rpfilter_disabler(self, prefix):
        """Write the script to disable rpfilter in docker containers"""
        filename = prefix + self.rpfilter_disabler_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/bin/sh")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        file.write("find /proc/sys/net/ipv4/conf/*/rp_filter | while read conf ; do\n")
        file.write("\techo 0 > $conf\n")
        file.write("done\n")
        file.write("\n")

        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("SystemManager: Wrote %s" % filename)

registrar.register_manager(SystemManager())
