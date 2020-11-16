"""This class is responsible for writing the system settings"""
# pylint: disable=unused-argument
# pylint: disable=no-self-use
import os
import stat
import json
from sync import registrar, Manager
from sync import board_util

class SystemManager(Manager):
    """SystemManager manages the system settings"""
    timezone_setter_filename = "/etc/config/startup.d/010-timezone"
    watchdog_disabler_filename = "/etc/config/startup.d/030-disable-watchdog"
    rpfilter_disabler_filename = "/etc/config/startup.d/040-disable-rpfilter"
    hostname_setter_filename = "/etc/config/startup.d/050-hostname"
    wizard_status_filename = "/etc/config/wizard-status.json"
    reload_system_filename = "/etc/config/startup.d/zzz-reload-system"
    nic_setter_filename = "/etc/config/startup.d/060-nic-settings"
    cron_filename = "/etc/crontabs/root"

    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.timezone_setter_filename, "startup-scripts", self)
        registrar.register_file(self.watchdog_disabler_filename, "startup-scripts", self)
        registrar.register_file(self.rpfilter_disabler_filename, "startup-scripts", self)
        registrar.register_file(self.hostname_setter_filename, "startup-scripts", self)
        registrar.register_file(self.wizard_status_filename, "restart-pyconnector", self)
        registrar.register_file(self.reload_system_filename, "startup-scripts", self)
        registrar.register_file(self.cron_filename, "restart-cron", self)
        registrar.register_file(self.nic_setter_filename, "restart-nic-setting", self)

    def validate_settings(self, settings_file):
        """validates settings"""
        system_settings = settings_file.settings.get('system')
        if system_settings is None:
            raise Exception("Missing required system settings")
        autoupgrade_settings = system_settings.get('autoUpgrade')
        if autoupgrade_settings is not None:
            if autoupgrade_settings.get('enabled') is None:
                raise Exception("Missing required autoUpgrade setting \"enabled\"")

    def create_settings(self, settings_file, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        settings_file.settings['system'] = {}
        settings_file.settings['system']['hostName'] = 'mfw'
        settings_file.settings['system']['domainName'] = 'example.com'
        settings_file.settings['system']['timeZone'] = {
            "displayName": "UTC",
            "value": "UTC"
        }
        settings_file.settings['system']['cloud'] = {
            "enabled": True,
            "supportAccessEnabled": True,
            "cloudServers": ["cmd.untangle.com"]
        }
        if board_util.is_docker():
            settings_file.settings['system']['setupWizard'] = {"completed": True}
        else:
            settings_file.settings['system']['setupWizard'] = {"completed": False}

        settings_file.settings['system']['autoUpgrade'] = {
            "dayOfWeek": 6,
            "hourOfDay": 0,
            "minuteOfHour": 0,
            "enabled": True,
        }

    def sync_settings(self, settings_file, prefix, delete_list):
        """syncs settings"""

        if board_util.is_docker():
            self.write_watchdog_disabler(prefix)
            self.write_rpfilter_disabler(prefix)

        system = settings_file.settings.get('system')
        if system is None:
            return

        hostname = system.get('hostName')
        if hostname is not None:
            self.write_hostname_setter(hostname, prefix)

        self.write_cron_file(settings_file.settings, prefix)

        self.write_wizard_status(settings_file.settings, prefix)

        self.write_system_reloader(prefix)

        network = settings_file.settings.get('network')
        self.write_nic_setter(network['interfaces'], prefix)

        time_zone = system.get('timeZone')
        if time_zone is None:
            pass
        # If the timezone is just a string, use that
        # In old settings.json, time_zone was just a string
        elif isinstance(time_zone, str):
            self.write_timezone_setter(time_zone, prefix)
        elif isinstance(time_zone, dict):
            time_zone_value = time_zone.get('value')
            if time_zone_value is not None:
                self.write_timezone_setter(time_zone_value, prefix)

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

    def write_wizard_status(self, settings, prefix):
        """Write the wizard status in /etc/config/wizard-status.json"""
        filename = prefix + self.wizard_status_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")

        file.write(json.dumps(settings['system']['setupWizard'].get('completed')))
        file.write('\n')

        file.flush()
        file.close()

        print("SystemManager: Wrote %s" % filename)

    def write_cron_file(self, settings, prefix):
        """Write the cron file"""
        enabled = True
        day = 6
        hour = 0
        minute = 0
        autoupgrade_settings = settings.get('system').get('autoUpgrade')
        if autoupgrade_settings is None:
            enabled = False
        else:
            if autoupgrade_settings.get('enabled') is None or autoupgrade_settings.get('enabled') is False:
                enabled = False
            if autoupgrade_settings.get('dayOfWeek') is not None:
                day = autoupgrade_settings.get('dayOfWeek')
            if autoupgrade_settings.get('hourOfDay') is not None:
                hour = autoupgrade_settings.get('hourOfDay')
            if autoupgrade_settings.get('minuteOfHour') is not None:
                minute = autoupgrade_settings.get('minuteOfHour')

        filename = prefix + self.cron_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")

        if enabled:
            file.write("%i %i * * %i /usr/bin/upgrade.sh >/dev/null 2>&1\n" % (minute, hour, day))

        file.write("0 */12 * * * /usr/bin/fetch-licenses.sh >/dev/null 2>&1\n")
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
        file.write(r'''/bin/sed -e "s@option timezone .*@option timezone '%s'@" /etc/config/system > $TMPFILE''' % time_zone)
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

    def write_system_reloader(self, prefix):
        """Write the script to reload system service"""
        filename = prefix + self.reload_system_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/bin/sh")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")
        file.write("/etc/init.d/system reload\n")
        file.write("\n")

        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("SystemManager: Wrote %s" % filename)

    def write_nic_setter(self, interfaces, prefix):
        """
        Write the NIC speed/duplex and autoneg settings
        
        :param interfaces: list of interface objects
        :param prefix: filename prefix
        """

        filename = prefix + self.nic_setter_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/bin/sh")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        for intf in interfaces:
            if 'ethAutoneg' in intf and 'ethSpeed' in intf and 'ethDuplex' in intf:
                autoneg = 'on' if intf['ethAutoneg'] else 'off'
                if autoneg is 'off':       
                    file.write("/usr/sbin/ethtool -s {} speed {} duplex {} autoneg {}\n"
                        .format(intf['device'], intf['ethSpeed'], intf['ethDuplex'], autoneg))
                else:       
                    file.write("/usr/sbin/ethtool -s {} autoneg {}\n"
                        .format(intf['device'], autoneg))
      
        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("SystemManager: Wrote %s" % filename)


registrar.register_manager(SystemManager())
