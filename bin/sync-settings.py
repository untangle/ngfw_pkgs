#!/usr/bin/env python3.5

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

import sync
    
class ArgumentParser(object):
    def __init__(self):
        self.filename = '/usr/share/untangle/settings/untangle-vm/network.js'
        if os.path.isfile('/etc/debian_version'):
            self.os = 'debian'
        elif os.path.isfile('/etc/openwrt_version'):
            self.os = 'openwrt'
        self.restart_services = True
        self.test_run = False
        self.create_settings = False

    def set_filename( self, arg ):
        self.filename = arg

    def set_os( self, arg ):
        self.os = arg
        
    def set_norestart( self, arg ):
        self.restart_services = False

    def set_test_run( self, arg ):
        self.test_run = True

    def set_create_settings( self, arg ):
        self.create_settings = True
        
    def parse_args( self ):
        handlers = {
            '-f' : self.set_filename,
            '-o' : self.set_os,
            '-n' : self.set_norestart,
            '-s' : self.set_test_run,
            '-c' : self.set_create_settings,
        }

        try:
            (optlist, args) = getopt.getopt(sys.argv[1:], 'f:o:nsc')
            for opt in optlist:
                handlers[opt[0]](opt[1])
            return args
        except getopt.GetoptError as exc:
            print(exc)
            print_usage()
            exit(1)

def cleanup(code):
    cleanup_tmpdirs()
    exit(code)

def print_usage():
    sys.stderr.write( """\
%s Usage:
  optional args:
    -f <file>   : settings filename to sync to OS
    -c          : create settings file if non-existant
    -n          : do not run restart commands (just copy files onto filesystem)
    -s          : do not copy or run restart commands (test run)
""" % sys.argv[0] )

def fixup_settings(json):
    """
    Fixes JSON serialization oddities in the JSON object
    """
    if isinstance(json, dict):
        for key in list(json.keys()):
            value = json.get(key)
            if isinstance(value, dict):
                if value.get('list') != None and value.get('javaClass') != None and "List" in value.get('javaClass'):
                    # Java serializes list objects as:
                    # "foo": { "javaClass": "java.util.LinkedList", "list": [] },
                    # This will change it to this for simplicity:
                    # "foo": []
                    new_value = value.get('list')
                    value = new_value
                    json[key] = new_value
            fixup_settings(json.get(key))
    elif isinstance(json, list):
        for i in range(len(json)):
            fixup_settings(json[i])

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
    if len(deleted_files) > 0:
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
    if parser.os == 'debian':
        cmd = "/bin/cp -ar --remove-destination " + tmpdir+"/*" + " /"
    else:
        cmd = "/bin/cp -ar " + tmpdir+"/*" + " /"
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

def cleanup_tmpdirs():
    global tmpdir, tmpdir_delete
    if tmpdir != None:
        shutil.rmtree(tmpdir)
    if tmpdir_delete != None:
        shutil.rmtree(tmpdir_delete)
        
def read_settings():
    """
    Read and parse the settings file
    """
    global settings
    try:
        settings_file = open(parser.filename, 'r')
        settings_data = settings_file.read()
        settings_file.close()
        settings = json.loads(settings_data, object_pairs_hook=collections.OrderedDict)
    except IOError as e:
        print("Unable to read settings file: ",e)
        cleanup(1)

def create_settings_in_tmpdir(tmpdir, tmpdir_delete):
    new_settings = {}
    delete_list=[]

    for manager in sync.registrar.managers:
        try:
            manager.create_settings(new_settings, tmpdir, delete_list, verbosity=2)
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
    
def create_settings():
    """
    Create settings from scratch
    """
    result = call_without_permissions(create_settings_in_tmpdir, tmpdir, tmpdir_delete)
    if result != 0:
        print("\nError during sync process. Abort.")
        cleanup(result)

    deleted_files = calculate_deleted_files(tmpdir_delete)
    if len(deleted_files) > 0:
        delete_files(deleted_files)
    copy_files(tmpdir)

    # Cleanup and make new tmpdirs
    cleanup_tmpdirs()
    make_tmpdirs()
        
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

if parser.os == 'debian':
    from   sync.debian import *
elif parser.os == 'openwrt':
    from   sync.openwrt import *
else:
    print("\nUnknown OS: " + parser.os)
    cleanup(1)

make_tmpdirs()

# Initialize all managers
init_managers()

if parser.create_settings:
    create_settings()

read_settings()

try:
    fixup_settings(settings)
    if sync.registrar.settings_verify_function != None:
        sync.registrar.settings_verify_function(settings)
    if sync.registrar.settings_cleanup_function != None:
        sync.registrar.settings_cleanup_function(settings)
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
if registrar.check_registrar_files(tmpdir) != 0:
    print("File missing in registrar: " + filename)
    cleanup(1)


# Calculate the changed files and the needed operations
changed_files = calculate_changed_files(tmpdir)
deleted_files = calculate_deleted_files(tmpdir_delete)
operations = registrar.calculate_required_operations(changed_files)
operations = registrar.reduce_operations(operations)

# Check that all operations are registered
if registrar.check_registrar_operations(operations) != 0:
    print("Operation missing from registrar: " + op)
    cleanup(1)

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


