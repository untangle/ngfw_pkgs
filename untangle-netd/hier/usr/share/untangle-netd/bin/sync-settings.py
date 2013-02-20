#!/usr/bin/env python

# Sync Settings is takes the netork settings JSON file and "syncs" it to the operating system
# It reads through the settings and writes the appropriate operating system files such as
# /etc/network/interfaces
# /etc/untangle-netd/iptables-rules.d/010-flush
# /etc/untangle-netd/iptables-rules.d/200-nat-rules
# /etc/untangle-netd/iptables-rules.d/210-port-forward-rules
# /etc/untangle-netd/iptables-rules.d/220-bypass-rules
# /etc/dnsmasq.conf
# /etc/hosts
# etc etc
#
# This script should be called after changing the settings file to "sync" the settings to the OS.
# Afterwards it will be necessary to restart certain services so the new settings will take effect

import sys
sys.path.insert(0, sys.path[0] + "/" + "../" + "../" + "../" + "lib/" + "python2.6/")

import getopt
import signal
import os
import traceback

# python2.6 includes json, python2.5 uses simplejson
try: import simplejson as json
except ImportError: import json

from   netd import *

class ArgumentParser(object):
    def __init__(self):
        self.file = '/etc/untangle-netd/network.js'
        self.prefix = ''
        self.verbosity = 0

    def set_file( self, arg ):
        self.file = arg

    def set_prefix( self, arg ):
        self.prefix = arg

    def increase_verbosity( self, arg ):
        self.verbosity += 1

    def parse_args( self ):
        handlers = {
            '-f' : self.set_file,
            '-p' : self.set_prefix,
            '-v' : self.increase_verbosity
        }

        try:
            (optlist, args) = getopt.getopt(sys.argv[1:], 'f:p:v')
            for opt in optlist:
                handlers[opt[0]](opt[1])
            return args
        except getopt.GetoptError, exc:
            print exc
            printUsage()
            exit(1)

def printUsage():
    sys.stderr.write( """\
%s Usage:
  optional args:
    -f <file>   : settings file to sync to OS
    -p <prefix> : prefix to append to output files
    -v          : verbose (can be specified more than one time)
""" % sys.argv[0] )

# sanity check settings
def checkSettings( settings ):
    if settings is None:
        raise Exception("Invalid Settings: null")
    if 'interfaces' not in settings:
        raise Exception("Invalid Settings: missing interfaces")
    if 'list' not in settings['interfaces']:
        raise Exception("Invalid Settings: missing interfaces list")
    interfaces = settings['interfaces']['list']

    for intf in interfaces:
        for key in ['interfaceId', 'name', 'systemDev', 'symbolicDev', 'physicalDev', 'config']:
            if key not in intf:
                raise Exception("Invalid Interface Settings: missing key %s" % key)
            

# remove unused fields for safety
def cleanupSettings( settings ):
    interfaces = settings['interfaces']['list']
    
    # remove disabled interfaces
    new_interfaces = [ intf for intf in interfaces if intf['config'] != 'disabled' ]
    settings['interfaces']['list'] = new_interfaces
    
    
parser = ArgumentParser()
parser.parse_args()
settings = None

try:
    settingsFile = open(parser.file, 'r')
    settingsData = settingsFile.read()
    settingsFile.close()
    settings = json.loads(settingsData)
except IOError,e:
    print "Unable to read settings file: ",e
    exit(1)

# print settings
    
print "Syncing %s to system..." % parser.file

try:
    checkSettings(settings)
    cleanupSettings(settings)
except Exception,e:
    traceback.print_exc(e)
    exit(1)

IptablesUtil.settings = settings
NetworkUtil.settings = settings

for module in [ InterfacesManager(), IptablesRulesManager(), NatRulesManager(), PortForwardManager(), BypassRuleManager(), EthernetManager(), FindDevManager(), SysctlManager(), ArpManager() ]:
    try:
        module.sync_settings( settings, prefix=parser.prefix, verbosity=parser.verbosity )
    except Exception,e:
        traceback.print_exc(e)
    

print "Done."
