import os
import sys
import subprocess
import datetime
import traceback
import re
from netd.network_util import NetworkUtil

# This class is responsible for writing /etc/ddclient.conf
# and others based on the settings object passed from sync-settings.py
class DdclientManager:
    ddclientConfigFilename = "/etc/ddclient.conf"
    ddclientDefaultFilename = "/etc/default/ddclient"

    def write_ddclient_config_file( self, settings, prefix="", verbosity=0 ):

        filename = prefix + self.ddclientConfigFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        try:
            config = {
                "zoneedit" : [ "zoneedit1", "dynamic.zoneedit.com", False ],
                "easydns" : [ "easydns", "members.easydns.com", False ],
                "dslreports" : [ "dslreports1", "www.dslreports.com", False ],
                "dnspark" : [ "dnspark", "www.dnspark.com", False ],
                "namecheap" : [ "namecheap", "dynamicdns.park-your-domain.com", False ],
                "dyndns" : [ "dyndns2", "members.dyndns.org", False ],
                "no-ip" : [ "dyndns2", "dynupdate.no-ip.com", False ],
                "dnsomatic" : [ "dyndns2", "updates.dnsomatic.com", False ],
                "cloudflare" : [ "cloudflare", "www.cloudflare.com", True ]
                }

            if not settings.get('dynamicDnsServiceEnabled'):
                return

            serviceName = settings.get('dynamicDnsServiceName')
            if serviceName not in config:
                print "ERROR: Missing configuration information for \"%s\" DNS service." % serviceName
                return

            protocol = config[serviceName][0]
            server = config[serviceName][1]
            use_ssl = config[serviceName][2]
            use_str = "web, web=checkip.dyndns.com/, web-skip='IP Address'"  

            file.write("pid=/var/run/ddclient.pid" + "\n")
            file.write("use=%s" % use_str + "\n")
            if use_ssl:
                file.write("ssl=yes" + "\n")
            file.write("protocol=%s" % protocol + "\n")
            file.write("login=%s" % str(settings.get('dynamicDnsServiceUsername')) + "\n")
            file.write("password=%s" % str(settings.get('dynamicDnsServicePassword')) + "\n")
            file.write("server=%s %s" % (server, str(settings.get('dynamicDnsServiceHostnames'))) + "\n")

        except Exception,e:
            traceback.print_exc(e)

        finally:
            file.flush()
            file.close()

            os.system("chmod a+x %s" % filename)
            if verbosity > 0: print "DdclientManager: Wrote %s" % filename
            
            return


    def write_ddclient_default_file( self, settings, prefix="", verbosity=0 ):

        filename = prefix + self.ddclientDefaultFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");


        try:
            file.write("daemon_interval=300" + "\n")
            file.write("run_daemon=%s" % str(settings.get('dynamicDnsServiceEnabled')).lower()+ "\n")

        except Exception,e:
            traceback.print_exc(e)

        finally:
            file.flush()
            file.close()

            os.system("chmod a+x %s" % filename)
            if verbosity > 0: print "DdclientManager: Wrote %s" % filename
            
            return

    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "DdclientManager: sync_settings()"
        
        self.write_ddclient_config_file( settings, prefix, verbosity )
        self.write_ddclient_default_file( settings, prefix, verbosity )

        if settings.get('dynamicDnsServiceEnabled'):
            os.system('/usr/sbin/update-rc.d ddclient defaults >/dev/null 2>&1')
            os.system('/etc/init.d/ddclient restart >/dev/null 2>&1')
        else:
            os.system('/usr/sbin/update-rc.d -f ddclient remove >/dev/null 2>&1')
            # this doesn't work because it checks /etc/default/ddclient first
            # use killall instead
            # os.system('/etc/init.d/ddclient stop >/dev/null 2>&1')
            os.system('killall ddclient >/dev/null 2>&1')

        return
