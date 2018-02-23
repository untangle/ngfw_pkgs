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
    mailnameFile = "/etc/mailname"
    resolvFile = "/etc/resolv.conf"

    def write_hosts_file( self, settings, prefix, verbosity ):

        filename = prefix + self.hostsFile
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");

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
            matcher = re.match( '.*?\.', hostname )

            # write hostname
            file.write("127.0.0.1\t%s" % hostname + "\n")
            if settings.get('domainName') != None:
                file.write("127.0.0.1\t%s.%s" % ( hostname, settings.get('domainName') ) + "\n" )
            file.write("\n")

        file.write("# user-defined static entries \n")
        if ( settings.get('dnsSettings') != None and 
             settings.get('dnsSettings').get('staticEntries') != None and 
             settings.get('dnsSettings').get('staticEntries').get('list') != None ):
            for entry in settings.get('dnsSettings').get('staticEntries').get('list'):
                if entry.get('name') != None and entry.get('address') != None:
                    file.write("%s\t%s" % ( entry.get('address'), entry.get('name') ) + "\n" )
            file.write("\n")
                        

        file.write("\n")

        file.flush()
        file.close()

        if verbosity > 0: print("HostsManager: Wrote %s" % filename)
        return

    def write_hostname_file( self, settings, prefix, verbosity ):

        if 'hostName' not in settings:
            print("ERROR: Missing hostname setting")
            return

        fqdnHostname = settings['hostName']
        if 'domainName' in settings:
            fqdnHostname = fqdnHostname + "." + settings['domainName']
        filename = prefix + self.hostnameFile
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("%s\n" % fqdnHostname)

        file.flush()
        file.close()

        # also set the hostname using '/bin/hostname'
        os.system("/bin/hostname %s" % fqdnHostname)

        if verbosity > 0: print("HostsManager: Wrote %s" % filename)
        return

    def write_mailname_file( self, settings, prefix, verbosity ):

        if 'domainName' not in settings:
            print("ERROR: Missing domainName setting")
            return

        filename = prefix + self.mailnameFile
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("%s.%s\n" % (settings.get('hostName'),settings.get('domainName')))

        file.flush()
        file.close()

        if verbosity > 0: print("HostsManager: Wrote %s" % filename)
        return

    def write_resolve_file( self, settings, prefix, verbosity ):

        if 'hostName' not in settings:
            print("ERROR: Missing hostname setting")
            return

        filename = prefix + self.resolvFile
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        
        file.write("\n")
        file.write("nameserver 127.0.0.1" + "\n")
        if settings.get('domainName') != None:
            file.write("search %s" % settings.get('domainName')+ "\n" )
        file.write("\n")

        file.flush()
        file.close()

        if verbosity > 0: print("HostsManager: Wrote %s" % filename)
        return

    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print("HostsManager: sync_settings()")
        
        self.write_hostname_file( settings, prefix, verbosity )
        self.write_hosts_file( settings, prefix, verbosity )
        self.write_resolve_file( settings, prefix, verbosity )
        self.write_mailname_file( settings, prefix, verbosity )

        return
