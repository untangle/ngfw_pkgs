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
if sys.version_info[0] == 3 and sys.version_info[1] == 5:
    sys.path.insert(0, sys.path[0] + "/" + "../lib/" + "python3.5/")

import getopt
import json
import os
import re
import shutil
import signal
import stat
import subprocess
import tempfile
import time
import traceback
import collections
import time

from   sync import *

if os.path.isfile('/etc/debian_version'):
    from   sync.debian import *
    

class ArgumentParser(object):
    def __init__(self):
        self.filename = '/usr/share/untangle/settings/untangle-vm/network.js'
        self.restart_services = True
        self.test_run = False

    def set_filename( self, arg ):
        self.filename = arg

    def set_norestart( self, arg ):
        self.restart_services = False

    def set_test_run( self, arg ):
        self.test_run = True

    def parse_args( self ):
        handlers = {
            '-f' : self.set_filename,
            '-n' : self.set_norestart,
            '-s' : self.set_test_run,
        }

        try:
            (optlist, args) = getopt.getopt(sys.argv[1:], 'f:ns')
            for opt in optlist:
                handlers[opt[0]](opt[1])
            return args
        except getopt.GetoptError as exc:
            print(exc)
            print_usage()
            exit(1)

def cleanup(code):
    global tmpdir
    if tmpdir != None:
        shutil.rmtree(tmpdir)
    exit(code)

def print_usage():
    sys.stderr.write( """\
%s Usage:
  optional args:
    -f <file>   : settings filename to sync to OS
    -n          : do not run restart commands (just copy files onto filesystem)
    -s          : do not copy or run restart commands (test run)
""" % sys.argv[0] )

def check_settings( settings ):
    """
    Sanity check the settings
    """
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
        for key in ['interfaceId', 'name']:
            if key not in intf:
                raise Exception("Invalid Virtual Interface Settings: missing key %s" % key)

def cleanup_settings( settings ):
    """
    This removes/disable hidden fields in the interface settings so we are certain they don't apply
    We do these operations here because we don't want to actually modify the settings
    For example, lets say you have DHCP enabled, but then you choose to bridge that interface to another instead.
    The settings will reflect that dhcp is still enabled, but to the user those fields are hidden.
    It is convenient to keep it enabled in the settings so when the user switches back to their previous settings
    everything is still the same. However, we need to make sure that we don't actually enable DHCP on that interface.

    This function runs through the settings and removes/disables settings that are hidden/disabled in the current configuration.
    """
    interfaces = settings['interfaces']['list']
    virtualInterfaces = settings['virtualInterfaces']['list']

    # Remove disabled interfaces from regular interfaces list
    # Save them in another field in case anyone needs them
    disabled_interfaces = [ intf for intf in interfaces if intf.get('configType') == 'DISABLED' ]
    new_interfaces = [ intf for intf in interfaces if intf.get('configType') != 'DISABLED' ]
    new_interfaces = sorted( new_interfaces, key=lambda x:x.get('interfaceId') )
    settings['interfaces']['list'] = new_interfaces
    settings['disabledInterfaces'] = { 'list': disabled_interfaces }

    disabled_virtual_interfaces = [ ]
    new_virtual_interfaces = [ intf for intf in virtualInterfaces ]
    new_virtual_interfaces = sorted( new_virtual_interfaces, key=lambda x:x.get('interfaceId') )
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

    # Remove bridgedTo settings if not bridged
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


def check_registrar_files(tmpdir):
    """
    This checks that all files written in tmpdir are properly registered
    in the registrar. If a file is missing in the registrar exit(1) is
    called to exit immediately
    """
    for root, dirs, files in os.walk(tmpdir):
        for filename in files:
            rootpath = os.path.join(root,filename).replace(tmpdir,"")
            result = registrar.registrar_check_file(rootpath)
            if not result:
                print("File missing in registrar: " + filename)
                cleanup(1)

def check_registrar_operations(operations):
    """
    Check that all operations in the ops list is in the registrar
    If an operation is missing in the registrar exit(1) is
    called to exit immediately
    """
    if operations == None:
        return
    if len(operations) > 0:
        print("Required operations: ")
    for op in operations:
        print(op)
        o = registrar.operations.get(op)
        if o == None:
            print("Operation missing from registrar: " + op)
            cleanup(1)
                
def calculate_changed_files(tmpdir):
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
            if not os.path.lexists(rootpath):
                new_files.append(rootpath)

    if len(changed_files) > 0:
        print("Changed files:")
        for f in changed_files:
            print(f)
    if len(new_files) > 0:
        print("New files:")
        for f in new_files:
            print(f)

    changes = []
    changes.extend(changed_files)
    changes.extend(new_files)
    if len(changes) == 0:
        print("No changed files.")

    return changes

def calculate_deleted_files(tmpdir_delete):
    """
    Calculate the list of files to be deleted by looking in the tmpdir
    """
    deleted_files = []
    for root, dirs, files in os.walk(tmpdir_delete):
        for file in files:
            rootpath = os.path.join(root,file).replace(tmpdir_delete,"")
            if os.path.lexists(rootpath):
                deleted_files.append(rootpath)
    if len(deleted_files) == 0:
        print("No deleted files.")
    else:
        print("Deleted files:")
        for f in deleted_files:
            print(f)
        
    return deleted_files

def run_cmd(cmd):
    """
    Run the specified command and print the ouput and return the result
    """
    stdin=open(os.devnull, 'rb')
    p = subprocess.Popen(["sh","-c","%s 2>&1" % (cmd)], stdout=subprocess.PIPE, stdin=stdin )
    for line in iter(p.stdout.readline, ''):
        if line == b'':
            break
        print( line.decode('ascii').strip() )
    p.wait()
    return p.returncode

def copy_files(tmpdir):
    """
    Copy the files from tmpdir into the root filesystem
    """
    cmd = "/bin/cp -ar --remove-destination " + tmpdir+"/*" + " /"
    result = run_cmd(cmd)
    if result != 0:
        print("Failed to copy results: " + str(result))
        return result
    run_cmd("/bin/sync")
    return 0

def delete_files(delete_list):
    """
    Delete the files in the list
    """
    print("Deleting files...")
    sum = 0;
    if delete_list == None:
        return
    for f in delete_list:
        try:
            cmd = "/bin/rm -f " + f
            result = run_cmd(cmd)
            if result != 0:
                print("Failed to delete: " + str(result))
                sum += result
        except Exception as e:
            print("Error deleting file: " + f,e)

    return sum

def run_commands(ops, key):
    """
    Run all the commands for the specified operations
    """
    if not parser.restart_services:
        print("Skipping operations " + key + "...")
        return 0
    print("Running operations " + key + "...")
    ret = 0
    for op in ops:
        o = registrar.operations.get(op)
        commands = o.get(key)
        if commands == None:
            continue
        for command in commands:
            if command == None:
                continue
            print("[" + op + "]: " + command)
            t1 = time.time()
            result = run_cmd(command)
            t2 = time.time()
            print("[" + op + "]: " + command + " done. [" + ("%.2f"%(t2-t1)) + "s]")
            if result != 0:
                print("Error[" + str(result) + "]: " + command)
            ret += result
    return ret

def tee_stdout_log():
    """
    Forks stdout to a log file
    """
    tee = subprocess.Popen(["tee", "-a", "/var/log/sync.log"], stdin=subprocess.PIPE)
    os.dup2(tee.stdin.fileno(), sys.stdout.fileno())
    os.dup2(tee.stdin.fileno(), sys.stderr.fileno())

def init_managers():
    """
    Call init() on all managers
    """
    for manager in sync.registrar.managers:
        try:
            manager.initialize()
        except Exception as e:
            traceback.print_exc()
            print("Abort. (errors)")
            cleanup(1)

def sync_to_tmpdirs(tmpdir, tmpdir_delete):
    """
    Call sync_settings on all manager
    """
    print("Syncing %s to system..." % parser.filename)

    delete_list=[]
    for manager in sync.registrar.managers:
        try:
            manager.sync_settings( settings, tmpdir, delete_list, verbosity=2 )
        except Exception as e:
            traceback.print_exc()
            return 1

    for filename in delete_list:
        path = tmpdir_delete + filename
        file_dir = os.path.dirname( path )
        if not os.path.exists( file_dir ):
            os.makedirs( file_dir )
        file = open( path, "w+" )
        file.write("\n\n");
        file.flush()
        file.close()

    return 0

def drop_permissions():
    """
    Set this process permissions to nobody (drop root permissions)
    """
    os.setegid(65534) # nogroup
    os.seteuid(65534) # nobody

def call_without_permissions(func, *args, **kw):
    """
    Call the specified function without root privs
    """
    pid = os.fork()
    if pid == 0:
        drop_permissions()
        result = func(*args, **kw)
        os._exit(result)
    else:
        (xpid, result) = os.waitpid(pid, 0)
        return result

def make_tmpdirs():
    """
    Make required tmp directories
    """
    global tmpdir, tmpdir_delete
    try:
        tmpdir = tempfile.mkdtemp()
        os.chmod(tmpdir, os.stat(tmpdir).st_mode | stat.S_IEXEC | stat.S_IRGRP | stat.S_IWGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IWOTH | stat.S_IXOTH)
        tmpdir_delete = tempfile.mkdtemp()
        os.chmod(tmpdir_delete, os.stat(tmpdir_delete).st_mode | stat.S_IEXEC | stat.S_IRGRP | stat.S_IWGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IWOTH | stat.S_IXOTH)
    except Exception as e:
        print("Error creating tmp directory.",e)
        traceback.print_exc()
        cleanup(1)

def read_settings():
    """
    Read and parse the settings file
    """
    global settings
    try:
        settingsFile = open(parser.filename, 'r')
        settingsData = settingsFile.read()
        settingsFile.close()
        settings = json.loads(settingsData, object_pairs_hook=collections.OrderedDict)
    except IOError as e:
        print("Unable to read settings file: ",e)
        cleanup(1)

# Duplicate all stdout to log
tee_stdout_log()

# argument parser
parser = ArgumentParser()
# The JSON settings object
settings = None
# tmpdir stores all files to be copied to the filesystem
tmpdir = None
# tmpdir_delete contains all the files to be delete (the content is irrelevent)
tmpdir_delete = None

parser.parse_args()

make_tmpdirs()

read_settings()

try:
    check_settings(settings)
    cleanup_settings(settings)
except Exception as e:
    traceback.print_exc()
    cleanup(1)

# Write the sanitized file for debugging
# sanitized_filename = (os.path.dirname(parser.filename) + "/network-sanitized.js")
# print("Writing sanitized settings: %s " % sanitized_filename)
# sanitized_file = open( sanitized_filename + ".tmp" , 'w' )
# json.dump(settings, sanitized_file)
# sanitized_file.flush()
# sanitized_file.close()
# os.system("python -m simplejson.tool %s.tmp > %s ; rm %s.tmp " % (sanitized_filename, sanitized_filename, sanitized_filename))

NetworkUtil.settings = settings

# Initialize all managers
init_managers()

print("")

# Call all the managers to "sync" settings to tmpdir
# We drop root permissions to call these functions so that
# the managers can't access the / filesystem directly
result = call_without_permissions(sync_to_tmpdirs,tmpdir,tmpdir_delete)
if result != 0:
    print("\nError during sync process. Abort.")
    cleanup(result)

print("")

# Check that all new files in the tmpdir are registered in the registrar
check_registrar_files(tmpdir)

# Calculate the changed files and the needed operations
changed_files = calculate_changed_files(tmpdir)
deleted_files = calculate_deleted_files(tmpdir_delete)
operations = registrar.calculate_required_operations(changed_files)
operations = registrar.reduce_operations(operations)

# Check that all operations are registered
check_registrar_operations(operations)

print("")
if parser.test_run:
    print("Test run complete.")
    # exit without cleanup
    exit(0)

# Copy in the files and delete any required files
if len(deleted_files) > 0:
    delete_files(deleted_files)
if len(operations) < 1:
    print("Copying files...")
    copy_files(tmpdir)
    print("Done.")
    cleanup(0)

copy_ret = 0
commands_ret = 0

# Run all pre commands
try:
    commands_ret += run_commands(operations, 'pre_commands')
except Exception as e:
    traceback.print_exc()

# Copy files to / filesystem
try:
    print("Copying files...")
    copy_ret = copy_files(tmpdir)
except Exception as e:
    traceback.print_exc()

# Run all post commands
try:
    commands_ret += run_commands(operations, 'post_commands')
except Exception as e:
    traceback.print_exc()

if copy_ret != 0:
    print("\nDone. (with critical errors)")
    cleanup(1)
elif commands_ret != 0:
    print("\nDone. (with non-critical errors)")
    cleanup(0) # exit 0 for non-critical errors
else:
    print("\nDone.")
    cleanup(0)


