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

# managers store a list of all the "manager" modules
# managers are responsible for serializing the settings to disk
managers = []

# A list of settings_files and the managers that want to operate on them.
settings_files = []

def register_manager( manager ):
    global managers
    managers.append(manager)

def register_operation( name, pre_commands, post_commands, priority, parent=None ):
    """
    Register available operations that can be associated with processing files.
    """
    global operations
    # print("Registering operation: " + name.ljust(20) + " parent: " + str(parent))
    operations[name] = { "name": name, "pre_commands": pre_commands, "post_commands": post_commands, "priority": priority, "parent": parent }

def register_file( filepath, operation, owner ):
    """
    Register a file (full path) with an operation to act upon.
    """
    global files, operations
    # print("Registering file: " + filepath.ljust(70) + " op: " + str(operation).ljust(20) + " owner: " + str(type(owner).__name__))
    if operation != None:
        op = operations[operation]
        if op == None:
            raise ValueError("Unknown operation: " + operation)
        
    files[filepath] = { "filepath": filepath, "operation": operation, "owner": owner}

def register_settings_file(id, manager):
    """
    Register a manager with a settings file identifer.
    If id=*, manager will see all settings files.
    """
    settings_files.append({ "id": id, "manager" : manager})

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

def check_registrar_files(tmpdir):
    """
    This checks that all files written in tmpdir are properly registered
    in the registrar. Returns 1 if error, 0 otherwise
    """
    for root, dirs, files in os.walk(tmpdir):
        for filename in files:
            rootpath = os.path.join(root,filename).replace(tmpdir,"")
            result = registrar_check_file(rootpath)
            if not result:
                print("Unregistered file: %s" % rootpath)
                return 1
    return 0

def check_registrar_operations(ops):
    """
    Check that all operations in the ops list is in the registrar
    Returns 1 if an operation is missing in the registrar 
    0 otherwise
    """
    if ops == None:
        return 0
    if len(ops) > 0:
        print("Required operations: ")
    for op in ops:
        print(op)
        o = operations.get(op)
        if o == None:
            return 1
    return 0

def check_registrar_settings_file(id, manager):
    """
    Determine if the specified manager is interested in this settings file identifier.
    """
    for settings_file in settings_files:
        if settings_file['manager'] == manager:
            if settings_file['id'] == id or settings_file['id'] == '*':
                return True

    return False