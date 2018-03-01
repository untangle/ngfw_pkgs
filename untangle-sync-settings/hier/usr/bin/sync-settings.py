#!/usr/bin/env python3

# Sync Settings is takes the netork settings JSON file and "syncs" it to the operating system
# It reads through the settings and writes the appropriate operating system files such as
# /etc/network/interfaces
# /etc/untangle/iptables-rules.d/010-flush
# /etc/untangle/iptables-rules.d/200-nat-rules
# /etc/untangle/iptables-rules.d/210-port-forward-rules
# /etc/untangle/iptables-rules.d/220-bypass-rules
# /etc/dnsmasq.conf
# /etc/hosts
# etc etc
#
# This script should be called after changing the settings file to "sync" the settings to the OS.
# Afterwards it will be necessary to restart certain services so the new settings will take effect

import sys
if sys.version_info[0] == 2 and sys.version_info[1] == 6:
    sys.path.insert(0, sys.path[0] + "/" + "../lib/" + "python2.6/")
if sys.version_info[0] == 2 and sys.version_info[1] == 7:
    sys.path.insert(0, sys.path[0] + "/" + "../lib/" + "python2.7/")
if sys.version_info[0] == 3 and sys.version_info[1] == 4:
    sys.path.insert(0, sys.path[0] + "/" + "../lib/" + "python3.4/")
if sys.version_info[0] == 3 and sys.version_info[1] == 5:
    sys.path.insert(0, sys.path[0] + "/" + "../lib/" + "python3.5/")

import getopt
import json
import os
import re
import shutil
import signal
import subprocess
import tempfile
import traceback

from   sync import *

class ArgumentParser(object):
    def __init__(self):
        self.file = '/usr/share/untangle/settings/untangle-vm/network.js'

    def set_file( self, arg ):
        self.file = arg

    def set_prefix( self, arg ):
        self.prefix = arg

    def parse_args( self ):
        handlers = {
            '-f' : self.set_file,
        }

        try:
            (optlist, args) = getopt.getopt(sys.argv[1:], 'f:p:v')
            for opt in optlist:
                handlers[opt[0]](opt[1])
            return args
        except getopt.GetoptError as exc:
            print(exc)
            printUsage()
            exit(1)

def cleanup(code):
    global tmpdir
    if tmpdir != None:
        shutil.rmtree(tmpdir)
    exit(code)

def printUsage():
    sys.stderr.write( """\
%s Usage:
  optional args:
    -f <file>   : settings file to sync to OS
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
        for key in ['interfaceId', 'name', 'systemDev', 'symbolicDev', 'physicalDev', 'configType']:
            if key not in intf:
                raise Exception("Invalid Interface Settings: missing key %s" % key)

    if 'virtualInterfaces' not in settings:
        raise Exception("Invalid Settings: missing virtualInterfaces")
    if 'list' not in settings['virtualInterfaces']:
        raise Exception("Invalid Settings: missing virtualInterfaces list")
    virtualInterfaces = settings['virtualInterfaces']['list']
    for intf in virtualInterfaces:
        for key in ['interfaceId', 'name', 'configType']:
            if key not in intf:
                raise Exception("Invalid Virtual Interface Settings: missing key %s" % key)
            

# This removes/disable hidden fields in the interface settings so we are certain they don't apply
# We do these operations here because we don't want to actually modify the settings
# For example, lets say you have DHCP enabled, but then you choose to bridge that interface to another instead.
# The settings will reflect that dhcp is still enabled, but to the user those fields are hidden.
# It is convenient to keep it enabled in the settings so when the user switches back to their previous settings
# everything is still the same. However, we need to make sure that we don't actually enable DHCP on that interface.
# 
# This function runs through the settings and removes/disables settings that are hidden/disabled in the current configuration.
#
def cleanupSettings( settings ):
    interfaces = settings['interfaces']['list']
    virtualInterfaces = settings['virtualInterfaces']['list']

    # Remove disabled interfaces from regular interfaces list
    # Save them in another field in case anyone needs them
    disabled_interfaces = [ intf for intf in interfaces if intf.get('configType') == 'DISABLED' ]
    new_interfaces = [ intf for intf in interfaces if intf.get('configType') != 'DISABLED' ]
    settings['interfaces']['list'] = new_interfaces
    settings['disabledInterfaces'] = { 'list': disabled_interfaces }

    disabled_virtual_interfaces = [ ]
    new_virtual_interfaces = [ intf for intf in virtualInterfaces ]
    settings['virtualInterfaces']['list'] = new_virtual_interfaces
    settings['disabledVirtualInterfaces'] = { 'list': disabled_virtual_interfaces }
    
    # Disable DHCP if if its a WAN or bridged to another interface
    for intf in interfaces:
        if intf['isWan'] or intf['configType'] == 'BRIDGED':
            for key in list(intf.keys()):
                if key.startswith('dhcp'):
                    del intf[key]

    # Disable NAT options on bridged interfaces
    for intf in interfaces:
        if intf['configType'] == 'BRIDGED':
            if 'v4NatEgressTraffic' in intf: del intf['v4NatEgressTraffic']
            if 'v4NatIngressTraffic' in intf: del intf['v4NatIngressTraffic']

    # Disable Gateway for non-WANs
    for intf in interfaces:
        if intf.get('isWan') != True:
            if 'v4StaticGateway' in intf: del intf['v4StaticGateway']
            if 'v6StaticGateway' in intf: del intf['v6StaticGateway']

    # Disable egress NAT on non-WANs
    # Disable ingress NAT on WANs
    for intf in interfaces:
        if intf['isWan']:
            if 'v4NatIngressTraffic' in intf: del intf['v4NatIngressTraffic']
        if not intf['isWan']:
            if 'v4NatEgressTraffic' in intf: del intf['v4NatEgressTraffic']

    # Remove PPPoE settings if not PPPoE intf
    for intf in interfaces:
        if intf['v4ConfigType'] != 'PPPOE':
            for key in list(intf.keys()):
                if key.startswith('v4PPPoE'):
                    del intf[key]

    # Remove static settings if not static intf
    for intf in interfaces:
        if intf['v4ConfigType'] != 'STATIC':
            for key in list(intf.keys()):
                if key.startswith('v4Static'):
                    del intf[key]

    # Remove auto settings if not auto intf
    for intf in interfaces:
        if intf['v4ConfigType'] != 'AUTO':
            for key in list(intf.keys()):
                if key.startswith('v4Auto'):
                    del intf[key]

    # Remove bridgedTo settincgs if not bridged
    for intf in interfaces:
        if intf['configType'] != 'BRIDGED':
            if 'bridgedTo' in intf: del intf['bridgedTo']

    # In 13.1 we renamed inputFilterRules to accessRules
    # Check for safety NGFW-10791
    # This can be removed after 13.1
    if settings.get('inputFilterRules') != None and settings.get('accessRules') == None:
        print("WARNING: accessRules missing - using inputFilterRules")
        settings['accessRules'] = settings.get('inputFilterRules')

    # In 13.1 we renamed forwardFilterRules to filterRules
    # Check for safety NGFW-10791
    # This can be removed after 13.1
    if settings.get('forwardFilterRules') != None and settings.get('filterRules') == None:
        print("WARNING: filterRules missing - using forwardFilterRules")
        settings['filterRules'] = settings.get('forwardFilterRules')
        
    return

def check_file(filename):
    """
    Checks that the specified filename is present in the registrar
    Exits with exit code 1 if filename is not found
    """
    for regex in registrar.files.keys():
        if filename == regex:
            return
    for regex in registrar.files.keys():
        if re.compile(regex).match(filename):
            return
    print("File missing in registrar: " + filename)
    cleanup(1)

def check_registrar(tmpdir):
    """
    This checks that all files written in tmpdir are properly registered
    in the registrar. If a file is missing in the registrar exit(1) is
    called to exit immediately
    """
    for root, dirs, files in os.walk(tmpdir):
        for file in files:
            rootpath = os.path.join(root,file).replace(tmpdir,"")
            check_file(rootpath)

def check_changes(tmpdir):
    """
    Compares the contents of tmpdir with the existing filesystem
    Returns a list of files that have changed (using root path)
    """
    cmd = "diff -rq / " + tmpdir + " | grep -v '^Only in' | awk '{print $2}'"
    process = subprocess.Popen(["sh","-c",cmd], stdout=subprocess.PIPE);
    out,err = process.communicate()
    
    changed_files = []
    for line in out.decode('ascii').split():
        if line.strip() != '':
            changed_files.append(line.strip())
    new_files = []
    for root, dirs, files in os.walk(tmpdir):
        for file in files:
            rootpath = os.path.join(root,file).replace(tmpdir,"")
            if not os.path.exists(rootpath):
                new_files.append(rootpath)

    if len(changed_files) > 0:
        print("\nChanged files:")
        for f in changed_files:
            print(f)
    if len(new_files) > 0:
        print("\nNew files:")
        for f in new_files:
            print(f)

    changes = []
    changes.extend(changed_files)
    changes.extend(new_files)
    if len(changes) == 0:
        print("\nNo changed files.")

    return changes

parser = ArgumentParser()
parser.parse_args()
settings = None
tmpdir = tempfile.mkdtemp()

try:
    settingsFile = open(parser.file, 'r')
    settingsData = settingsFile.read()
    settingsFile.close()
    settings = json.loads(settingsData)
except IOError as e:
    print("Unable to read settings file: ",e)
    cleanup(1)

try:
    checkSettings(settings)
    cleanupSettings(settings)
except Exception as e:
    traceback.print_exc(e)
    cleanup(1)

# Write the sanitized file for debugging
# sanitized_filename = (os.path.dirname(parser.file) + "/network-sanitized.js")
# print("Writing sanitized settings: %s " % sanitized_filename)
# sanitized_file = open( sanitized_filename + ".tmp" , 'w' )
# json.dump(settings, sanitized_file)
# sanitized_file.flush()
# sanitized_file.close()
# os.system("python -m simplejson.tool %s.tmp > %s ; rm %s.tmp " % (sanitized_filename, sanitized_filename, sanitized_filename))

NetworkUtil.settings = settings
erroc_occurred = False

modules = [ HostsManager(), DnsMasqManager(),
            InterfacesManager(), RouteManager(), 
            IptablesManager(), NatRulesManager(), 
            FilterRulesManager(), QosManager(),
            PortForwardManager(), BypassRuleManager(), 
            EthernetManager(), 
            SysctlManager(), ArpManager(),
            DhcpManager(), RadvdManager(),
            PPPoEManager(), DdclientManager(),
            KernelManager(), EbtablesManager(),
            VrrpManager(), WirelessManager(),
            UpnpManager(), NetflowManager()]

for module in modules:
    try:
        module.initialize()
    except Exception as e:
        traceback.print_exc()
        erroc_occurred = True

if erroc_occurred:
    print("Abort. (errors)")
    cleanup(1)
    
print("\nSyncing %s to system..." % parser.file)

for module in modules:
    try:
        module.sync_settings( settings, prefix=tmpdir, verbosity=2 )
    except Exception as e:
        traceback.print_exc()
        erroc_occurred = True

check_registrar(tmpdir)

changes = check_changes(tmpdir)

if len(changes) > 0:
    cmd = "/bin/cp -ar " + tmpdir+"/*" + " /"
    print(cmd)
    result = subprocess.call(cmd, shell=True)
    if result != 0:
        print("Failed to copy results.")
        cleanup(1)

if erroc_occurred:
    print("Done. (with errors)")
    cleanup(1)
else:
    print("Done.")
    cleanup(0)


