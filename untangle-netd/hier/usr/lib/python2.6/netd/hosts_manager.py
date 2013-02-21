import os
import sys
import subprocess
import datetime
import traceback
import re
from netd.network_util import NetworkUtil

# This class is responsible for writing /etc/hosts and /etc/hostname
# based on the settings object passed from sync-settings.py
class HostsManager:
    hostsFile = "/etc/hosts"
    hostnameFile = "/etc/hostname"

    def write_hosts_file( self, settings, prefix, verbosity ):

        filename = prefix + self.hostsFile
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");

        file.write(r"""
127.0.0.1  localhost localhost.localdomain

# The following lines are desirable for IPv6 capable hosts
# (added automatically by netbase upgrade)

::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts

""")
        if 'hostName' in settings:

            hostname = settings['hostName']
            matcher = re.match( '.*?\.', hostname )

            # write hostname
            file.write("127.0.0.1\t%s" % hostname + "\n")

            if matcher:
                # if hostname is fully qualified
                # also write shortname and shortname.domain
                shortname = matcher.group(0).replace('.','')
                file.write("127.0.0.1\t%s" % shortname + "\n")
                if 'domainName' in settings:
                    file.write("127.0.0.1\t%s.%s" % ( shortname, settings['domainName'] ) + "\n" )
            else:
                # if hostname isn't fully qualified 
                # also write hostname.domainname
                if 'domainName' in settings:
                    file.write("127.0.0.1\t%s.%s" % ( hostname, settings['domainName'] ) + "\n" )

        file.write("\n")

        file.flush()
        file.close()

        if verbosity > 0: print "HostsManager: Wrote %s" % filename
        return

    def write_hostname_file( self, settings, prefix, verbosity ):

        if 'hostName' not in settings:
            print "ERROR: Missing hostname setting"
            return

        filename = prefix + self.hostnameFile
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("%s\n" % settings['hostName'])

        file.flush()
        file.close()

        # also set the hostname using '/bin/hostname'
        os.system("/bin/hostname %s" % settings['hostName'])

        if verbosity > 0: print "HostsManager: Wrote %s" % filename
        return

    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "HostsManager: sync_settings()"
        
        self.write_hostname_file( settings, prefix, verbosity )
        self.write_hosts_file( settings, prefix, verbosity )

        return
