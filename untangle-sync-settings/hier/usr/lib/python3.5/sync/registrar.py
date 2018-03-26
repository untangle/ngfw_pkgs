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
    # print("Registering operation: " + name.ljust(20) + " parent: " + str(parent))
    operations[name] = { "name": name, "pre_command": pre_command, "post_command": post_command, "priority": priority, "parent": parent }

def register_file( filepath, operation, owner ):
    global files, operations
    # print("Registering file: " + filepath.ljust(70) + " op: " + str(operation).ljust(20) + " owner: " + str(type(owner).__name__))
    if operation != None:
        op = operations[operation]
        if op == None:
            raise ValueError("Unknown operation: " + operation)
        
    files[filepath] = { "filepath": filepath, "operation": operation, "owner": owner}


def operation_subset_of( parent, child ):
    """
    Returns true if the child operation is a child or x-grandchild of parent
    In other words, the child operation is a subset of the parent operation
    Otherwise returns False
    """
    if child == parent:
        return False
    child_op = operations.get(child)
    parent_op = operations.get(parent)
    if child_op == None or parent_op == None:
        return False
    if child_op.get('parent') == parent:
        return True
    if child_op.get('parent') != None:
        return operation_subset_of(parent, child_op.get('parent'))
    return False

def calculate_required_operations( changed_files ):
    """
    Calculates the required operations that need to be completed 
    if the specified files have changed
    """
    global files
    operations = []
    for filename in changed_files:
        f = find_file_registration(filename)
        if f == None:
            raise ValueError("Missing file from registrar: " + filename)
        op = f.get('operation')
        if op != None and op not in operations:
            operations.append(op)
    return operations

def find_file_registration( filename ):
    """
    Find the file registration object for the given filename
    """
    global files
    f = files.get(filename)
    if f != None:
        return f
    for regex in files.keys():
        if re.compile(regex).match(filename):
            return files.get(regex)
    return None

def registrar_check_file(filename):
    """
    Checks that the specified filename is present in the registrar
    Exits with exit code 1 if filename is not found
    """
    global files
    for regex in files.keys():
        if filename == regex:
            return True
    for regex in files.keys():
        if re.compile(regex).match(filename):
            return True
    return False

def reduce_operations( ops ):
    """
    This attempts to reduce the number of required operations is some semi-intelligent fashion
    """
    global operations
    if ops == None:
        return None
    if len(ops) == 0:
        return ops
    # Check operations
    for op1 in ops:
        o = operations.get(op1)
        if o == None:
            raise ValueError("Missing op for registrar: " + op1)
    # First remove any operations that are already included
    orig_ops = list(ops)
    for op1 in orig_ops:
        for op2 in orig_ops:
           if operation_subset_of(op1, op2):
               ops.remove(op2)

    # See if including any of the immediate parents of the operations reduces the length
    # If so, its probably worth it to do include the parent
    orig_ops = list(ops)
    for op1 in orig_ops:
        o1 = operations.get(op1)
        if o1.get('parent') != None:
            new_ops = ops + [o1.get('parent')]
            new_ops = reduce_operations( new_ops )
            if len(new_ops) < len(orig_ops):
                return reduce_operations( new_ops )

    return(ops)





register_operation( "restart-networking", "ifdown -a -v --exclude=lo", "ifup -a -v --exclude=lo",          10, None )
register_operation( "restart-dnsmasq",    None, "/etc/untangle/post-network-hook.d/990-restart-dnsmasq",   20, "restart-networking" )
register_operation( "restart-miniupnpd",  None, "/etc/untangle/post-network-hook.d/990-restart-upnp",      21, "restart-networking" )
register_operation( "restart-radvd",      None, "/etc/untangle/post-network-hook.d/990-restart-radvd",     22, "restart-networking" )
register_operation( "restart-ddclient",   None, "/etc/untangle/post-network-hook.d/990-restart-ddclient",  23, "restart-networking" )
register_operation( "restart-softflowd",  None, "/etc/untangle/post-network-hook.d/990-restart-softflowd", 25, "restart-networking" )
register_operation( "restart-quagga",     None, "/etc/untangle/post-network-hook.d/990-restart-quagga",    26, "restart-networking" )
register_operation( "restart-keepalived", None, "/etc/untangle/post-network-hook.d/200-vrrp",              30, "restart-networking" )
register_operation( "restart-iptables",   None, "/etc/untangle/post-network-hook.d/960-iptables",          50, "restart-networking" )



