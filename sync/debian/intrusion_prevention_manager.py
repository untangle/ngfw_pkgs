import os
import stat
import pwd
import grp
import sys
from sync.iptables_util import IptablesUtil
from sync import registrar,Manager

class IntrusionPreventionManager(Manager):
    """
    This class is responsible for writing intrusion prevention iptables entries
    based on the settings object passed from sync-settings
    """
    suricata_iptables_file_name = "/etc/untangle/iptables-rules.d/740-suricata"
    in_file_name = suricata_iptables_file_name
    out_file_name = suricata_iptables_file_name
    in_file = None
    out_file = None
    iptables_tables = ["raw", "mangle"]
    iptables_chains = ["suricata-scanning"]
    in_bypass_rules = False

    crond_signature_update_file_name = "/etc/cron.d/untangle-update-ips-signatures"

    crontab_default_times = {
        'hour': 0,
        'minute': 0
    }

    day_map = {
        "Sunday": 0,
        "Monday": 1,
        "Tuesday": 2,
        "Wednesday": 3,
        "Thursday": 4,
        "Friday": 5,
        "Saturday": 6
    }

    # Mapping of script variable name to settings variable to use
    script_to_settings = {
        "intrusion-prevention": {
            "SETTINGS_INTRUSIONPREVENTION_IPTABLESPROCESSING": "iptablesProcessing",
            "SETTINGS_INTRUSIONPREVENTION_IPTABLESNFQNUMBER": "iptablesNfqNumber",
            "SETTINGS_INTRUSIONPREVENTION_IPTABLESMAXSCANSIZE": "iptablesMaxScanSize"
        }
    }

    def initialize(self):
        """ Register settings of interest and our file """
        registrar.register_settings_file("network", self)
        registrar.register_settings_file("intrusion-prevention", self)
        registrar.register_file(self.suricata_iptables_file_name, "restart-suricata", self)
        registrar.register_file(self.crond_signature_update_file_name, None, self)

    def sync_settings(self, settings_file, prefix, delete_list):
        """
        Synchronize our file by modifying.  This is different than how other managers.
        """
        self.write_out_suricata_file(settings_file, prefix, delete_list)
        if settings_file.id == "intrusion-prevention":
            self.write_out_signature_update_cron(settings_file, prefix, delete_list)

    def write_out_suricata_file(self, settings_file, prefix, delete_list):
        """
        Write out suricata file
        """
        self.out_file_name = prefix + self.suricata_iptables_file_name
        self.out_file_dir = os.path.dirname(self.out_file_name)
        if not os.path.exists(self.out_file_dir):
            os.makedirs(self.out_file_dir)

        if os.path.isfile(self.out_file_name):
            # Found the last time we were in here on this run
            # (e.g.,network and intrusion-prevention settings both specified)
            # Rename and modify this file instead of the live file.
            self.in_file_name = self.out_file_name + '.last'
            os.rename(self.out_file_name, self.in_file_name)
        else:
            self.in_file_name = self.suricata_iptables_file_name
        
        self.in_file = open(self.in_file_name, "r")
        self.out_file = open(self.out_file_name, "w+")

        # By default, process the file by passing each line to a settings specific updater.
        # The update can replace the line and write their modification and if they do, they'll
        # set write_line to False
        write_line = True
        for line in self.in_file:
            if settings_file.id == "network":
                # Process network settings
                write_line = self.update_suricata_iptables_file_network(settings_file, line)
            elif settings_file.id == "intrusion-prevention":
                # Process intrusion prevention settings
                write_line = self.update_suricata_iptables_file_intrusion_prevention(settings_file, line)

            if write_line == True:
                self.out_file.write(line)

            # Write the next line unless overidden by an updater.
            write_line = True

        self.out_file.flush()
        self.out_file.close()
        if self.in_file_name.endswith(".last"):
            os.remove(self.in_file_name)
        os.chmod(self.out_file_name, os.stat(self.out_file_name).st_mode | stat.S_IEXEC)
        print("IntrusionPreventionManager: Wrote %s" % self.out_file_name)

    def update_suricata_iptables_file_network(self, settings_file, line):
        """
        Replace network bypass block with system network bypass rules.
        """
        write_line = True
        write_line = self.update_suricata_iptables_file_bypass(settings_file, line, 'SETTINGS_NETWORK_BYPASSRULES', "Network")
        return write_line

    def update_suricata_iptables_file_intrusion_prevention(self, settings_file, line):
        """
        Replace ips script variables for nfq, size, processing.
        Replace ips bypass block with ips bypass rules.
        """
        write_line = True

        matched = False
        script_to_settings = self.script_to_settings[settings_file.id]
        for key in script_to_settings:
            if line.rstrip().startswith(key + "="):
                self.out_file.write("{key}={value}\n".format(key=key, value=str(settings_file.settings[script_to_settings[key]])))
                write_line = False
                matched = True

        if matched == False:
            write_line = self.update_suricata_iptables_file_bypass(settings_file, line, 'SETTINGS_INTRUSIONPREVENTION_BYPASSRULES', "IPS")

        return write_line

    def update_suricata_iptables_file_bypass(self, settings_file, line, script_variable, comment_prefix):
        """
        General bypass block detecton and replacer.
        """
        write_line = True

        if line.rstrip().startswith(script_variable + '=') and line.rstrip().endswith(script_variable + '_EOF'):
            # Found the beginning of the block.
            if settings_file.settings == None or 'bypassRules' not in settings_file.settings:
                print("ERROR: Missing Bypass Rules")
                return True

            self.in_bypass_rules = True
            self.out_file.write(line)

            bypass_rules = settings_file.settings['bypassRules']
            for table in self.iptables_tables:
                for chain in self.iptables_chains:
                    for bypass_rule in bypass_rules:
                        try:
                            self.write_bypass_rule(bypass_rule, table, chain, comment_prefix)
                        except Exception as e:
                            traceback.print_exc()
            write_line = False
        elif line.rstrip() == script_variable + '_EOF':
            # Found end of the block.
            self.in_bypass_rules = False

        if self.in_bypass_rules:
            write_line = False

        return write_line

    def write_bypass_rule(self, bypass_rule, table, chain, comment_prefix):
        """
        Convert the bypass rule to iptables notation (possibly expanding to multiple commands
        for multiple protocols)
        """
        if 'enabled' in bypass_rule and not bypass_rule['enabled']:
            return
        if 'conditions' not in bypass_rule:
            return
        if 'ruleId' not in bypass_rule:
            return

        target = None
        if 'bypass' in bypass_rule and bypass_rule['bypass']:
            target = " -j RETURN "
        elif 'bypass' in bypass_rule and not bypass_rule['bypass']:
            # bypass is not enabled; do nothing to let it be processed
            return
        else:
            print("ERROR: invalid bypass target: %s" + str(bypass_rule))
            return

        description = comment_prefix + " Bypass Rule #%i" % int(bypass_rule['ruleId'])
        commands = IptablesUtil.conditions_to_prep_commands(bypass_rule['conditions'], description)
        conditions = IptablesUtil.conditions_to_iptables_string(bypass_rule['conditions'], description)
        for condition in conditions:
            commands += ["${{IPTABLES}} -t {table} -A {chain} {conditions}{target}".format(table=table, chain=chain, conditions=condition, target=target)]

        for cmd in commands:
            self.out_file.write( cmd + "\n")

        return

    def write_out_signature_update_cron(self, settings_file, prefix, delete_list):
        self.get_crontab_default_times()
        filename = prefix + self.crond_signature_update_file_name
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file_contents = None
        if settings_file.settings['updateSignatureFrequency'] == "Daily":
            file_contents = self.write_out_signature_update_daily_cron(settings_file.settings)
        if settings_file.settings['updateSignatureFrequency'] == "Weekly":
            file_contents = self.write_out_signature_update_weekly_cron(settings_file.settings)

        if file_contents:
            file.write(file_contents)
            file.write('\n')
        file.flush()
        file.close()
        print("%s: Wrote %s" % (self.__class__.__name__, filename))

    def write_out_signature_update_daily_cron(self, settings):
        file_contents = ""
        for day in settings['updateSignatureSchedule']:
            if day['enabled']:
                file_contents += self.generate_day_cron_line(day)
                file_contents += '\n'
        return file_contents.strip()

    def write_out_signature_update_weekly_cron(self, settings):
        return self.generate_day_cron_line(settings['updateSignatureWeekly'])

    def generate_day_cron_line(self, day):
        day_line = ""
        if day['minute'] != -1:
            day_line = day_line + str(day['minute']) + " "
        else:
            day_line = day_line + self.crontab_default_times['minute'] + " "
        if day['hour'] != -1:
            day_line = day_line + str(self.convert_hour_to_24_format(day)) + " "
        else:
            day_line = day_line + self.crontab_default_times['hour'] + " "
        day_line = day_line + "* * "
        day_value = str(self.day_map[day['day']])
        day_line = day_line + day_value + " "
        day_line = day_line + "root /usr/share/untangle/bin/intrusion-prevention-get-updates "
        day_line = day_line + ">/dev/null 2>&1"
        return day_line

    def get_crontab_default_times(self):
        crontab_file = open('/etc/crontab', 'r')
        crontab_file_contents = crontab_file.readlines()

        for line in crontab_file_contents:
            if line.find('/etc/cron.daily') != -1:
                line_split = line.split(' ')
                self.crontab_default_times['minute'] = line_split[0]
                self.crontab_default_times['hour'] = line_split[1]
                if self.crontab_default_times['hour'].find('\t') != -1:
                    self.crontab_default_times['hour'] = self.crontab_default_times['hour'].split('\t')[0] 
                break

        crontab_file.close()

    def convert_hour_to_24_format(self, day):
        hour = day['hour']
        isAm = day['isAm']
        military_hour = hour
        if isAm and hour == 12:
            military_hour = 0
        if not isAm and hour < 12:
            military_hour = hour + 12
        return military_hour

registrar.register_manager(IntrusionPreventionManager())
