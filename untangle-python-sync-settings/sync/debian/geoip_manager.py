import copy
import os
import stat
import sys
import subprocess
import datetime
import re
import traceback
from sync import registrar, Manager
from sync.uri_util import UriUtil

# This class is responsible for updating geoip cron files.

class GeoIpManager(Manager):
    update_uri = 'https://downloads.untangle.com/download.php'

    geoip_update_untangle_file_name = "/etc/cron.monthly/geoip-update"
    geoip_update_untangle_source = re.compile(r'^(NETURL=)(.*)')

    def initialize(self):
        registrar.register_settings_file("uris", self)
        registrar.register_file(self.geoip_update_untangle_file_name, "geoip-update", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        """
        Synchronize our file by modifying.
        """
        self.out_file_name = prefix + self.geoip_update_untangle_file_name
        self.out_file_dir = os.path.dirname(self.out_file_name)
        if not os.path.exists(self.out_file_dir):
            os.makedirs(self.out_file_dir)

        if os.path.isfile(self.out_file_name):
            # Found the last time we were in here on this run
            # (e.g.,network and uri settings both specified)
            # Rename and modify this file instead of the live file.
            self.in_file_name = self.out_file_name + '.last'
            os.rename(self.out_file_name, self.in_file_name)
        else:
            self.in_file_name = self.geoip_update_untangle_file_name
        
        self.in_file = open(self.in_file_name, "r")
        self.out_file = open(self.out_file_name, "w+")

        # By default, process the file by passing each line to a settings specific updater.
        # The update can replace the line and write their modification and if they do, they'll
        # set write_line to False
        write_line = True
        for line in self.in_file:
            if settings_file.id == "uris":
                match = re.search(self.geoip_update_untangle_source, line)
                if match:
                    config_option=match.group(1)
                    current_uri=match.group(2)
                    for uri in settings_file.settings['uriTranslations']:
                        if uri['uri'] == self.update_uri:
                            new_uri = copy.deepcopy(uri)
                            # Use current URI to preserve existing auth
                            new_uri = UriUtil.build_uri(current_uri, uri)
                            line = "{config_option}{new_uri}\n".format(config_option=config_option,new_uri=new_uri)

            if write_line == True:
                self.out_file.write(line)

            # Write the next line unless overidden by an updater.
            write_line = True

        self.out_file.flush()
        self.out_file.close()
        if self.in_file_name.endswith(".last"):
            os.remove(self.in_file_name)
        os.chmod(self.out_file_name, os.stat(self.out_file_name).st_mode | stat.S_IEXEC)
        print("GeoipManager: Wrote %s" % self.out_file_name)
        return

registrar.register_manager(GeoIpManager())
