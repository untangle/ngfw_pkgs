import os
import stat
import sys
import subprocess
import datetime
import traceback
import re
from sync.network_util import NetworkUtil
from sync import registrar

# This class is responsible for writing /etc/ddclient.conf
# and others based on the settings object passed from sync-settings.py
class DdclientManager:
    config_filename = "/etc/ddclient.conf"
    default_filename = "/etc/default/ddclient"
    restart_filename = "/etc/untangle/post-network-hook.d/990-restart-ddclient"

    def sync_settings( self, settings, prefix="", verbosity=0 ):
        if verbosity > 1: print("DdclientManager: sync_settings()")
        
        self.write_config_file( settings, prefix, verbosity )
        self.write_default_file( settings, prefix, verbosity )
        self.write_restart_file( settings, prefix, verbosity )

        # FIXME - this modifies the filesystem directly! FIXME
        if prefix == "":
            if settings.get('dynamicDnsServiceEnabled'):
                # FIXME - this modifies the filesystem directly! FIXME
                os.system('chmod 600 /etc/ddclient.conf')
                os.system('/usr/sbin/update-rc.d ddclient defaults >/dev/null 2>&1')
                os.system('systemctl restart ddclient >/dev/null 2>&1')
            else:
                # FIXME - this modifies the filesystem directly! FIXME
                os.system('/usr/sbin/update-rc.d -f ddclient remove >/dev/null 2>&1')
                # this doesn't work because it checks /etc/default/ddclient first
                # use killall instead
                # os.system('systemctl stop ddclient >/dev/null 2>&1')
                os.system('killall ddclient >/dev/null 2>&1')

        return
    
    def initialize( self ):
        registrar.register_file( self.config_filename, "restart-ddclient", self )
        registrar.register_file( self.default_filename, "restart-ddclient", self )
        registrar.register_file( self.restart_filename, "restart-networking", self )

    def write_config_file( self, settings, prefix="", verbosity=0 ):
        filename = prefix + self.config_filename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        # https://sourceforge.net/p/ddclient/wiki/protocols/
        try:
            config = {
                "zoneedit" : [ "zoneedit1", "dynamic.zoneedit.com", True ],
                "easydns" : [ "easydns", "members.easydns.com", True ],
                "dslreports" : [ "dslreports1", "www.dslreports.com", True ],
                "dnspark" : [ "dnspark", "www.dnspark.com", True ],
                "namecheap" : [ "namecheap", "dynamicdns.park-your-domain.com", True ],
                "dyndns" : [ "dyndns2", "members.dyndns.org", True ],
                "no-ip" : [ "dyndns2", "dynupdate.no-ip.com", True ],
                "dnsomatic" : [ "dyndns2", "updates.dnsomatic.com", True ],
                "google" : [ "dyndns2", "domains.google.com", True ],
                "freedns" : [ "dyndns2", "freedns.afraid.org", True ],
                "cloudflare" : [ "cloudflare", "www.cloudflare.com", True ]
                }

            if not settings.get('dynamicDnsServiceEnabled'):
                return

            serviceName = settings.get('dynamicDnsServiceName')
            if serviceName not in config:
                print("ERROR: Missing configuration information for \"%s\" DNS service." % serviceName)
                return

            protocol = config[serviceName][0]
            server = config[serviceName][1]
            use_ssl = config[serviceName][2]


            file.write("pid=/var/run/ddclient.pid" + "\n")

            file.write("use=cmd" + "\n")
            file.write("cmd='/usr/bin/dig @204.69.234.1 +short whoami.ultradns.net'" + "\n")

            if use_ssl:
                file.write("ssl=yes" + "\n")
            file.write("protocol=%s" % protocol + "\n")
            file.write("login=%s" % str(settings.get('dynamicDnsServiceUsername')) + "\n")
            file.write("password=%s" % str(settings.get('dynamicDnsServicePassword')) + "\n")
            file.write("server=%s %s" % (server, str(settings.get('dynamicDnsServiceHostnames'))) + "\n")

        except Exception as e:
            traceback.print_exc()

        finally:
            file.flush()
            file.close()

            os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
            if verbosity > 0: print("DdclientManager: Wrote %s" % filename)
            
            return

    def write_default_file( self, settings, prefix="", verbosity=0 ):
        filename = prefix + self.default_filename
        file_dir = os.path.dirname( filename )
        if not os.path.exists( file_dir ):
            os.makedirs( file_dir )

        file = open( filename, "w+" )
        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");


        try:
            file.write("daemon_interval=300" + "\n")
            file.write("run_daemon=%s" % str(settings.get('dynamicDnsServiceEnabled')).lower()+ "\n")

        except Exception as e:
            traceback.print_exc()

        finally:
            file.flush()
            file.close()

            os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
            if verbosity > 0: print("DdclientManager: Wrote %s" % filename)
            
            return

    def write_restart_file( self, settings, prefix="", verbosity=0 ):
        """
        Create network process extension to restart or stop daemon
        """
        filename = prefix + self.restart_filename
        file_dir = os.path.dirname( filename )
        if not os.path.exists( file_dir ):
            os.makedirs( file_dir )

        file = open( filename, "w+" )
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n");

        if not settings.get('dynamicDnsServiceEnabled'):
            file.write(r"""
# ddclient process changes its own name, no "pidof ddclient" does not work
DDCLIENT_PID="`pgrep ddclient`"

# Stop ddclient if running
if [ ! -z "$DDCLIENT_PID" ] ; then
    systemctl stop ddclient
    # For whatever reason this does not effectively stop ddclient processes
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
    systemctl start ddclient

# use not older than (instead of newer than) because it compares seconds and we want an equal value to still do a restart
elif [ ! /etc/ddclient.conf -ot /proc/$DDCLIENT_PID ] ; then
    systemctl stop ddclient
    # For whatever reason this does not effectively stop ddclient processes
    pgrep ddclient | while read pid ; do kill $pid ; done

    systemctl restart ddclient
fi
""")

        file.write("\n");
        file.flush()
        file.close()
    
        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        if verbosity > 0: print("DdclientManager: Wrote %s" % filename)
        return

