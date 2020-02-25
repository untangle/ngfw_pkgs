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

# This class is responsible for updating pyconnector files.

class PyconnectorManager(Manager):
    update_uri = 'https://cmd.untangle.com/'

    pyconnector_defaults_file_name = "/etc/default/untangle-pyconnector"
    pyconnector_defaults_default_server = re.compile(r'^(#DEFAULT_SERVER=)(.*)')
    pyconnector_defaults_default_port = re.compile(r'^(#DEFAULT_PORT=)(.*)')
    pyconnector_defaults_server = re.compile(r'^(SERVER=)(.*)')
    pyconnector_defaults_port = re.compile(r'^(PORT=)(.*)')

    # need defaults to fall back on

    def initialize(self):
        registrar.register_settings_file("uris", self)
        registrar.register_file(self.pyconnector_defaults_file_name, "restart-pyconnector", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        """
        Synchronize our file by modifying.
        """
        self.out_file_name = prefix + self.pyconnector_defaults_file_name
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
            self.in_file_name = self.pyconnector_defaults_file_name
        
        self.in_file = open(self.in_file_name, "r")
        self.out_file = open(self.out_file_name, "w+")

        parsed_uri = None
        for uri in settings_file.settings['uriTranslations']:
            if uri['uri'] == self.update_uri:
                built_uri = UriUtil.build_uri(self.update_uri, uri)
                parsed_uri = UriUtil.get_parsed_uri(self.update_uri)
                parsed_uri = UriUtil.get_parsed_uri(str(UriUtil.build_uri(self.update_uri, uri)))

        default_server=None
        default_port=None

        # By default, process the file by passing each line to a settings specific updater.
        # The update can replace the line and write their modification and if they do, they'll
        # set write_line to False
        write_line = True
        for line in self.in_file:
            if settings_file.id == "uris":
                match = re.search(self.pyconnector_defaults_default_server, line)
                if match:
                    default_server=match.group(2)
                match = re.search(self.pyconnector_defaults_default_port, line)
                if match:
                    default_port=match.group(2)
                match = re.search(self.pyconnector_defaults_server, line)
                if match:
                    default_server=match.group(1)
                    server=default_server
                    if parsed_uri.host is not None:
                        server = parsed_uri.host
                    line="{config_option}{server}\n".format(config_option=match.group(1),server=server)
                match = re.search(self.pyconnector_defaults_port, line)
                if match:
                    default_server=match.group(1)
                    port=default_port
                    if parsed_uri.port is not None:
                        port = parsed_uri.port
                    line="{config_option}{port}\n".format(config_option=match.group(1),port=port)

            if write_line == True:
                self.out_file.write(line)

            # Write the next line unless overidden by an updater.
            write_line = True

        self.out_file.flush()
        self.out_file.close()
        if self.in_file_name.endswith(".last"):
            os.remove(self.in_file_name)
        os.chmod(self.out_file_name, os.stat(self.out_file_name).st_mode | stat.S_IEXEC)
        print("PyconnectorManager: Wrote %s" % self.out_file_name)
        return

registrar.register_manager(PyconnectorManager())
