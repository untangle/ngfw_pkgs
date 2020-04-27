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

# This class is responsible for updating bdadmserver.conf

class BdamserverManager(Manager):
    update_uri = 'http://bd.untangle.com/'

    bdadmserver_conf_file_name = "/etc/bdamserver/bdamserver.conf"
    bdadmserver_conf_update_url_antivirus = re.compile(r'^(UpdateURLAntivirus=)(https?:\/\/[^?\/\s]+[?\/])(.*)')

    def initialize(self):
        registrar.register_settings_file("uris", self)
        # operation to restart badadmserver
        registrar.register_file(self.bdadmserver_conf_file_name, "restart-bdamserver", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        """
        Synchronize our file by modifying.
        """
        self.out_file_name = prefix + self.bdadmserver_conf_file_name
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
            self.in_file_name = self.bdadmserver_conf_file_name
        
        self.in_file = open(self.in_file_name, "r")
        self.out_file = open(self.out_file_name, "w+")

        # By default, process the file by passing each line to a settings specific updater.
        # The update can replace the line and write their modification and if they do, they'll
        # set write_line to False
        write_line = True
        for line in self.in_file:
            if settings_file.id == "uris":
                match = re.search(self.bdadmserver_conf_update_url_antivirus, line)
                if match:
                    config_option=match.group(1)
                    path="/" + match.group(3)
                    for uri in settings_file.settings['uriTranslations']:
                        if uri['uri'] == self.update_uri:
                            new_uri = copy.deepcopy(uri)
                            uri['path'] = path
                            new_uri = UriUtil.build_uri(self.update_uri, uri)
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
        print("BdamserverManager: Wrote %s" % self.out_file_name)
        return

registrar.register_manager(BdamserverManager())
