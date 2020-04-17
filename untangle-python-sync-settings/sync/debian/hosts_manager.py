import os
import stat
import sys
import subprocess
import datetime
import traceback
import re
from sync.network_util import NetworkUtil
from sync import registrar,Manager

# This class is responsible for writing /etc/hosts and /etc/hostname
# based on the settings object passed from sync-settings


class HostsManager(Manager):
    hosts_filename = "/etc/hosts"
    hostname_filename = "/etc/hostname"
    mailname_filename = "/etc/mailname"
    resolv_filename = "/etc/resolv.conf"
    pre_network_hook_filename = "/etc/untangle/pre-network-hook.d/001-sethostname"

    def initialize(self):
        registrar.register_settings_file("network", self)
        registrar.register_file(self.hosts_filename, None, self)
        registrar.register_file(self.hostname_filename, "update-hostname", self)
        registrar.register_file(self.mailname_filename, None, self)
        registrar.register_file(self.resolv_filename, None, self)
        registrar.register_file(self.pre_network_hook_filename, "restart-networking", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        self.write_hostname_file(settings_file.settings, prefix)
        self.write_hosts_file(settings_file.settings, prefix)
        self.write_resolve_file(settings_file.settings, prefix)
        self.write_mailname_file(settings_file.settings, prefix)
        self.write_pre_network_hook_file(settings_file.settings, prefix)
        return

    def write_hosts_file(self, settings, prefix):

        filename = prefix + self.hosts_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")

        file.write(r"""
127.0.0.1  localhost localhost.localdomain

::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts

""")
        if 'hostName' in settings:

            hostname = settings['hostName']
            matcher = re.match('.*?\.', hostname)

            # write hostname
            file.write("127.0.0.1\t%s" % hostname + "\n")
            if settings.get('domainName') != None:
                file.write("127.0.0.1\t%s.%s" % (hostname, settings.get('domainName')) + "\n")
            file.write("\n")

        file.write("# user-defined static entries \n")
        if (settings.get('dnsSettings') != None and
                settings.get('dnsSettings').get('staticEntries') != None):
            for entry in settings.get('dnsSettings').get('staticEntries'):
                if entry.get('name') != None and entry.get('address') != None:
                    file.write("%s\t%s" % (entry.get('address'), entry.get('name')) + "\n")
            file.write("\n")

        file.write("\n")

        file.flush()
        file.close()

        print("HostsManager: Wrote %s" % filename)
        return

    def write_hostname_file(self, settings, prefix):
        if 'hostName' not in settings:
            print("ERROR: Missing hostname setting")
            return

        fqdn_hostname = settings['hostName']
        if 'domainName' in settings:
            fqdn_hostname = fqdn_hostname + "." + settings['domainName']
        filename = prefix + self.hostname_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("%s\n" % fqdn_hostname)

        file.flush()
        file.close()

        print("HostsManager: Wrote %s" % filename)
        return

    def write_pre_network_hook_file(self, settings, prefix):
        if 'hostName' not in settings:
            print("ERROR: Missing hostname setting")
            return

        fqdn_hostname = settings['hostName']
        if 'domainName' in settings:
            fqdn_hostname = fqdn_hostname + "." + settings['domainName']
        filename = prefix + self.pre_network_hook_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/bin/dash")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        # file.write("/bin/hostname %s" % fqdn_hostname)
        file.write("/bin/hostname -F /etc/hostname")
        file.write("\n\n")

        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("HostsManager: Wrote %s" % filename)
        return

    def write_mailname_file(self, settings, prefix):

        if 'domainName' not in settings:
            print("ERROR: Missing domainName setting")
            return

        filename = prefix + self.mailname_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("%s.%s\n" % (settings.get('hostName'), settings.get('domainName')))

        file.flush()
        file.close()

        print("HostsManager: Wrote %s" % filename)
        return

    def write_resolve_file(self, settings, prefix):

        if 'hostName' not in settings:
            print("ERROR: Missing hostname setting")
            return

        filename = prefix + self.resolv_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")

        file.write("\n")
        file.write("nameserver 127.0.0.1" + "\n")
        if settings.get('domainName') != None:
            file.write("search %s" % settings.get('domainName') + "\n")
        file.write("\n")

        file.flush()
        file.close()

        print("HostsManager: Wrote %s" % filename)
        return


registrar.register_manager(HostsManager())
