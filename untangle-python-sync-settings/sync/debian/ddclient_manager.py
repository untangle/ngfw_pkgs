import os
import stat
import sys
import subprocess
import datetime
import traceback
import re
from sync.network_util import NetworkUtil
from sync import registrar, Manager

# This class is responsible for writing /etc/ddclient.conf
# and others based on the settings object passed from sync-settings


class DdclientManager(Manager):
    config_filename = "/etc/ddclient.conf"
    default_filename = "/etc/default/ddclient"
    restart_filename = "/etc/untangle/post-network-hook.d/990-restart-ddclient"

    def initialize(self):
        registrar.register_settings_file("network", self)
        registrar.register_file(self.config_filename, "restart-ddclient", self)
        registrar.register_file(self.default_filename, "restart-ddclient", self)
        registrar.register_file(self.restart_filename, "restart-networking", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        self.write_config_file(settings_file.settings, prefix)
        self.write_default_file(settings_file.settings, prefix)
        self.write_restart_file(settings_file.settings, prefix)

    def write_config_file(self, settings, prefix=""):
        filename = prefix + self.config_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")

        # https://sourceforge.net/p/ddclient/wiki/protocols/
        try:
            config = {
                "zoneedit": {"protocol": "zoneedit1", "server": "dynamic.zoneedit.com", "ssl": True},
                "easydns": {"protocol": "easydns", "server": "members.easydns.com", "ssl": True},
                "dslreports": {"protocol": "dslreports1", "server": "www.dslreports.com", "ssl": True},
                "dnspark": {"protocol": "dnspark", "server": "www.dnspark.com", "ssl": True},
                "namecheap": {"protocol": "namecheap", "server": "dynamicdns.park-your-domain.com", "ssl": True},
                "dyndns": {"protocol": "dyndns2", "server": "members.dyndns.org", "ssl": True},
                "no-ip": {"protocol": "dyndns2", "server": "dynupdate.no-ip.com", "ssl": True},
                "dnsomatic": {"protocol": "dyndns2", "server": "updates.dnsomatic.com", "ssl": True},
                "google": {"protocol": "dyndns2", "server": "domains.google.com", "ssl": True},
                "freedns": {"protocol": "freedns", "server": "freedns.afraid.org", "ssl": True},
                "cloudflare": {"protocol": "cloudflare", "server": "www.cloudflare.com", "ssl": True},
                "googledomains": {"protocol": "googledomains", "ssl": True},
                "duckdns": {"protocol": "duckdns", "server": "www.duckdns.org", "ssl": True}
            }

            if not settings.get('dynamicDnsServiceEnabled'):
                return

            service_name = settings.get('dynamicDnsServiceName')
            service = config.get(service_name)
            if service == None:
                print("ERROR: Missing configuration information for \"%s\" DNS service." % service_name)
                return

            ssl = service.get('ssl')
            protocol = service.get('protocol')
            server = service.get('server')

            login = str(settings.get('dynamicDnsServiceUsername'))
            password = str(settings.get('dynamicDnsServicePassword'))
            hostname = str(settings.get('dynamicDnsServiceHostnames'))

            if protocol == None or login == None or password == None or hostname == None:
                print("ERROR: Missing information for \"%s\" DNS service." % service_name)
                return

            file.write("pid=/var/run/ddclient.pid" + "\n")

            #file.write("use=cmd" + "\n")
            #file.write("cmd='/usr/bin/dig @204.69.234.1 +short whoami.ultradns.net'" + "\n")
            #file.write("use=web" + " " + "web=checkip.dyndns.com/, web-skip='IP Address'" + "\n")
            file.write("use=web" + " " + "web=myip.dnsomatic.com/" + "\n")

            file.write("protocol=%s" % protocol + "\n")
            file.write("login=%s" % login + "\n")
            file.write("password=%s" % password + "\n")
            if ssl != None:
                file.write("ssl=yes" + "\n")
            if server != None:
                file.write("server=%s" % (server) + "\n")
            file.write("%s" % hostname + "\n")

        except Exception as e:
            traceback.print_exc()

        finally:
            file.flush()
            file.close()

            os.chmod(filename, 600)
            print("DdclientManager: Wrote %s" % filename)

            return

    def write_default_file(self, settings, prefix=""):
        filename = prefix + self.default_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        try:
            file.write("daemon_interval=300" + "\n")
            file.write("run_daemon=%s" % str(settings.get('dynamicDnsServiceEnabled')).lower() + "\n")

        except Exception as e:
            traceback.print_exc()

        finally:
            file.flush()
            file.close()

            os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
            print("DdclientManager: Wrote %s" % filename)

            return

    def write_restart_file(self, settings, prefix=""):
        """
        Create network process extension to restart or stop daemon
        """
        filename = prefix + self.restart_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/bin/dash")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n")

        if not settings.get('dynamicDnsServiceEnabled'):
            file.write(r"""
# ddclient process changes its own name, no "pidof ddclient" does not work
DDCLIENT_PID="`pgrep ddclient`"

# Stop ddclient if running
if [ ! -z "$DDCLIENT_PID" ] ; then
    # systemctl --no-block stop ddclient 
    # Does not work
    # Likely because the ddclient process renames itself
    # Instead manually kill all process with ddclient in name
    pgrep ddclient | while read pid ; do kill $pid ; done
fi
""")
        else:
            file.write(r"""
# ddclient process changes its own name, no "pidof ddclient" does not work
DDCLIENT_PID="`pgrep ddclient`"

# Restart ddclient if it isnt found
# Or if ddclient.conf orhas been written since ddclient was started
if [ -z "$DDCLIENT_PID" ] ; then
    systemctl --no-block restart ddclient

# use not older than (instead of newer than) because it compares seconds and we want an equal value to still do a restart
elif [ ! /etc/ddclient.conf -ot /proc/$DDCLIENT_PID ] ; then
    systemctl --no-block restart ddclient
fi
""")

        file.write("\n")
        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("DdclientManager: Wrote %s" % filename)
        return


registrar.register_manager(DdclientManager())
