import json
import os
import stat
import sys
import traceback
from sync import registrar, Manager
from sync.uri_util import UriUtil

class AptManager(Manager):
    """
    Build system apt sources list, accomodating customizations for oems.
    """
    default_update_uri = 'http://updates.untangle.com/'

    debian_version_file_name = "/etc/debian_version"
    uid_file_name = "/usr/share/untangle/conf/uid"
    pubversion_file_name = "/usr/share/untangle/lib/untangle-libuvm-api/PUBVERSION"
    updates_settings_file_name = "/usr/share/untangle/conf/updates.js"
    platform_settings_file_name = "/usr/share/untangle/conf/platform.js"

    apt_sources_untangle_file_name = "/etc/apt/sources.list.d/untangle.list"

    apt_sources_template = "deb %scheme%://%user%:%password%@%host%%path% %distribution% %components%"

    parameters = {
        "scheme": None,
        "user": None,
        "password": "untangle",
        "host": None,
        "port": None,
        "path": "/public/%debian_code_name%",
        "debian_code_name": None,
        "distribution": 'stable-%pubversion%',
        "components": "main non-free",

        "pubversion": None
    }

    def initialize(self):
        """
        Initialize
        """
        registrar.register_settings_file("uris", self)
        registrar.register_file(self.apt_sources_untangle_file_name, "apt-update", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        """
        Generate our apt sources file
        """
        # Build parameter list
        if self.build_parameters(settings_file) is False:
            # Unable to build neccessary parameters
            return

        # Build apt_sources from parameters
        apt_sources = AptManager.apt_sources_template
        for key in self.parameters:
            apt_sources = self.expand_parameter_value(apt_sources)

        # Create sources file
        self.out_file_name = prefix + self.apt_sources_untangle_file_name
        self.out_file_dir = os.path.dirname(self.out_file_name)
        if not os.path.exists(self.out_file_dir):
            # Create directory
            os.makedirs(self.out_file_dir)

        try:
            self.out_file = open(self.out_file_name, "w+")
            self.out_file.write("## Auto Generated\n")
            self.out_file.write("## DO NOT EDIT. Changes will be overwritten.\n\n");
            self.out_file.write(f"{apt_sources}\n")

            self.out_file.flush()
            self.out_file.close()
            os.chmod(self.out_file_name, os.stat(self.out_file_name).st_mode | stat.S_IEXEC)
        except Exception as exc:
            print(f'Unable to write source file {self.out_file_name}')
            traceback.print_exc()
            return False

        print("AptManager: Wrote %s" % self.out_file_name)
        return

    def build_parameters(self, settings_file):
        """
        Populate parameter dictionary
        """
        # Debian code name
        self.parameters["debian_code_name"] = self.get_debian_code_name()
        if self.parameters["debian_code_name"] is None:
            print("Unable to determine debian_code_name")
            return False

        # NGFW pubversion
        self.parameters["pubversion"] = self.get_pubversion()
        if self.parameters["pubversion"] is None:
            print("Unable to determine pubversion")
            return False

        # UID for user name
        try:
            with open(AptManager.uid_file_name, "r") as uid_file_name_file:
                self.parameters["user"] = uid_file_name_file.readline().strip()
        except Exception as exc:
            print(f'Unable to read uid file {AptManager.uid_file_name}')
            traceback.print_exc()
            return False

        # URI components
        uri = self.get_uri(settings_file)
        if uri is None:
            return False
        self.parameters["scheme"] = uri.scheme
        self.parameters["host"] = uri.host
        if "port" in uri:
            self.parameters["port"] = uri.port

        # Populate updates overrides
        self.overlay_updates()

        # Expand all parameters.
        while True:
            parameter_count = 0
            for key in self.parameters.keys():
                parameter = f'%{key}%'
                for key_sub in self.parameters:
                    value = self.parameters[key_sub]
                    if value is not None and parameter in value:
                        # At least one in this round
                        parameter_count += 1
                        self.parameters[key_sub] = self.expand_parameter_value(value)
            if parameter_count == 0:
                # Finished expanding
                break

        return True

    def get_debian_code_name(self):
        """
        Get debian code name
        """
        debian_code_name = None

        platform_settings = {}
        try:
            with open(AptManager.platform_settings_file_name, "r") as platform_settings_file:
                platform_settings = json.load(platform_settings_file)
        except Exception as exc:
            print(f'Unable to read platform settings {AptManager.platform_settings_file_name}')
            traceback.print_exc()
            return None

        try:
            with open(AptManager.debian_version_file_name, "r") as debian_version_file:
                debian_version = int(debian_version_file.readline().strip().split('.')[0])
        except Exception as exc:
            print(f'Unable to read debian version {AptManager.debian_version_file_name}')
            traceback.print_exc()
            return None

        for code_name in platform_settings['debian']:
            if "version" in platform_settings['debian'][code_name] and \
                platform_settings['debian'][code_name]["version"] == debian_version:
                debian_code_name = code_name
                break

        return debian_code_name

    def get_pubversion(self):
        """
        Get NGFW pubversion (e.g.,16.4) without dots (eg,.164).
        """
        pubversion = None

        try:
            with open(AptManager.pubversion_file_name, "r") as pubversion_file:
                pubversion = pubversion_file.readline().strip().replace(".","")
        except Exception as exc:
            print(f'Unable to read pubversion {AptManager.pubversion_file_name}')
            traceback.print_exc()
            return None

        return pubversion

    def get_uri(self, settings_file):
        """
        Get updates URI
        """
        uri = None

        uri_settings_file = settings_file

        uri_settings = {}
        if uri_settings_file is not None:
            for uri_settings in settings_file.settings['uriTranslations']:
                if uri_settings['uri'] == AptManager.default_update_uri:
                    break

        uri = UriUtil.build_uri(AptManager.default_update_uri, uri_settings)

        return uri

    def overlay_updates(self):
        """
        Read updates settings (if exists) and overlay keys under updates into parameters
        """
        if os.path.exists(AptManager.updates_settings_file_name) is False:
            return

        try:
            with open(AptManager.updates_settings_file_name, "r") as updates_settings_file:
                updates_settings = json.load(updates_settings_file)
        except Exception as exc:
            print(f'Unable to read updates settings {AptManager.pubversion_file_name}')
            traceback.print_exc()
            return None

        for key in updates_settings:
            print(key)
            if key in self.parameters:
                self.parameters[key] = self.expand_parameter_value(updates_settings[key])
            else:
                print("error unknown key")

        return

    def expand_parameter_value(self, value):
        """
        For a given value walk down parameter list and perform search/replace on parameters
        """
        for key in self.parameters:
            # Look for parameter enclosed in % characters like %key%
            parameter = f'%{key}%'
            if parameter in value:
                value = value.replace(parameter, self.parameters[key])
        return value

registrar.register_manager(AptManager())
