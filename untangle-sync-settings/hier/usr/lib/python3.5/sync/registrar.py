import os
import sys
import subprocess
import datetime
import traceback
import string
import re

# Operation defines operations to runs before and after syncing settings
# Each operation has these properties
# name - the primary key - must be unique
# pre_command - the command to run before sync (may be None)
# post_command - the command to run after sync (may be None)
# priority - an integer, lowest operations run first, defines the order to avoid any inconsistency
# parent - the name of the parent (if any) that is in INCLUSIVE of this operation. If the parent is required then this operation can be skipped
operations = {}

# files stores a mapping of all files to be changed
# Each file has the follow properties
# filepath - the file
# operation - the name of the operation that must be before/after changing this file
# owner - the manager responsible for writing this file
files = {}

def register_operation( name, pre_command, post_command, priority, parent=None ):
    global operations
    print("Registering operation: " + name.ljust(20) + " parent: " + str(parent))
    operations[name] = { "name": name, "pre_command": pre_command, "post_command": post_command, "priority": priority, "parent": parent }

def register_file( filepath, operation, owner ):
    global files, operations
    print("Registering file: " + filepath.ljust(70) + " op: " + str(operation).ljust(20) + " owner: " + str(type(owner).__name__))
    if operation != None:
        op = operations[operation]
        if op == None:
            raise ValueError("Unknown operation: " + operation)
        
    files[filepath] = { "filepath": filepath, "operation": operation, "owner": owner}

register_operation( "restart-networking", "ifdown -a -v --exclude=lo", "ifup -a -v --exclude=lo",          10, None )
register_operation( "restart-dnsmasq",    None, "/etc/untangle/post-network-hook.d/990-restart-dnsmasq",   20, "restart-networking" )
register_operation( "restart-miniupnpd",  None, "/etc/untangle/post-network-hook.d/990-restart-upnp",      21, "restart-networking" )
register_operation( "restart-radvd",      None, "/etc/untangle/post-network-hook.d/990-restart-radvd",     22, "restart-networking" )
register_operation( "restart-ddclient",   None, "/etc/untangle/post-network-hook.d/990-restart-ddclient",  23, "restart-networking" )
register_operation( "restart-hostapd",    None, "/etc/untangle/post-network-hook.d/990-restart-hostapd",   24, "restart-networking" )
register_operation( "restart-softflowd",  None, "/etc/untangle/post-network-hook.d/990-restart-softflowd", 25, "restart-networking" )
register_operation( "restart-keepalived", None, "/etc/untangle/post-network-hook.d/200-vrrp",              30, "restart-networking" )
register_operation( "restart-iptables",   None, "/etc/untangle/post-network-hook.d/960-iptables",          50, "restart-networking" )



