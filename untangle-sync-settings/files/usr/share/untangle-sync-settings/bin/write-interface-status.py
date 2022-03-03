#!/usr/bin/env python3

# This script reads the current interface's configuration/status and writes it to the specified file.
# This is usually called when an IP or configuration changes like when saving new settings or
# when a different DHCP address is given.
# The Untangle-vm will read the status file

import sys
import getopt
import signal
import os
import traceback
import re
import subprocess

try: import simplejson as json
except ImportError: import json

fileName = None
dev = None
interfaceId = None
verbosity = 0
ipRegex = r"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"

class ArgumentParser(object):
    def __init__(self):
        pass

    def set_file( self, arg ):
        global fileName
        fileName = arg

    def set_dev( self, arg ):
        global dev
        dev = arg

    def set_interfaceId( self, arg ):
        global interfaceId
        interfaceId = int( arg )

    def increase_verbosity( self, arg ):
        global verbosity
        verbosity += 1

    def parse_args( self ):
        handlers = {
            '-w' : self.set_file,
            '-I' : self.set_dev,
            '-i' : self.set_interfaceId,
            '-v' : self.increase_verbosity
        }

        try:
            (optlist, args) = getopt.getopt(sys.argv[1:], 'w:i:I:v')
            for opt in optlist:
                handlers[opt[0]](opt[1])
            return args
        except getopt.GetoptError as exc:
            print(exc)
            printUsage()
            exit(1)

def printUsage():
    sys.stderr.write( """\
%s Usage:
  required args:
    -w <file>   : settings file to sync to OS
    -I <dev>         : ethernet device of the interface in question
    -i <interfaceId> : ID of the interface
  optional args:
    -v          : verbose (can be specified more than one time)
""" % sys.argv[0] )

def ipv4_cidr_to_netmask(bits):
    """ Convert CIDR bits to netmask """
    netmask = ''
    for i in range(4):
        if i:
            netmask += '.'
        if bits >= 8:
            netmask += '%d' % (2**8-1)
            bits -= 8
        else:
            netmask += '%d' % (256-2**(8-bits))
            bits = 0
    return netmask



parser = ArgumentParser()
parser.parse_args()

if fileName == None or dev == None or interfaceId == None:
    printUsage()
    sys.exit(1)

if verbosity > 0: print("Writing %s status to %s." % (dev, fileName))

obj = {"javaClass":"com.untangle.uvm.network.InterfaceStatus", "interfaceId":interfaceId}


# Parse IPv4 Address, Netmask, Prefix Length
for line in subprocess.Popen(("ip addr show %s scope global" % dev).split(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT).communicate()[0].decode("ascii").split('\n'):
    if re.search(r'\sinet\s.*', line):

        segments = line.split()
        if len( segments ) < 2:
            print("ERROR: invalid ip addr show output: \"%s\"" % line)
            continue

        addrStr = segments[1].split("/")
        if len( addrStr ) == 1:
            addrStr.append( "32" )
        if len( addrStr ) != 2:
            print("ERROR: invalid ip addr show address format: \"%s\"" % addrStr)
            continue

        try:
            if ( re.match( ipRegex, addrStr[0] ) ):
                obj['v4Address'] = addrStr[0]
            obj['v4PrefixLength'] = int( addrStr[1] )
            obj['v4Netmask'] = ipv4_cidr_to_netmask( obj['v4PrefixLength'] )
        except Exception as e:
            print("ERROR: invalid ip addr show address format: \"%s\"" % addrStr)
            traceback.print_exc(e)
            continue

# Parse IPv6 Address, Prefix Length
for line in subprocess.Popen(("ip addr show %s scope global" % dev).split(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT).communicate()[0].decode("ascii").split('\n'):
    if re.search(r'\sinet6\s.*', line):

        segments = line.split()
        if len( segments ) < 2:
            print("ERROR: invalid ip addr show output: \"%s\"" % line)
            continue

        addrStr = segments[1].split("/")
        if len( addrStr ) != 2:
            print("ERROR: invalid ip addr show address format: \"%s\"" % addrStr)
            continue

        try:
            obj['v6Address'] = addrStr[0]
            obj['v6PrefixLength'] = int( addrStr[1] )
        except Exception as e:
            print("ERROR: invalid ip addr show address format: \"%s\"" % addrStr)
            traceback.print_exc(e)
            continue

# Parse IPv4 Gateway
for line in subprocess.Popen(("ip route show table uplink.%i" % interfaceId).split(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT).communicate()[0].decode("ascii").split('\n'):
    if re.search(r'default via.*', line):

        segments = line.split()
        if len( segments ) < 3:
            print("ERROR: invalid ip route show output: \"%s\"" % line)
            continue

        if ( re.match( ipRegex, segments[2] ) ):
            obj['v4Gateway'] = segments[2]

# Parse IPv6 Gateway
# XXX table main? table uplink.X?
for line in subprocess.Popen(("ip -6 route show table main").split(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT).communicate()[0].decode("ascii").split('\n'):
    if re.search(r'default via.*', line):

        segments = line.split()
        if len( segments ) < 3:
            print("ERROR: invalid ip route show output: \"%s\"" % line)
            continue

        obj['v6Gateway'] = segments[2]


# Parse DNS (read from dnsmasq.conf)
count=1
for line in subprocess.Popen(["/bin/sh","-c","cat /etc/dnsmasq.conf /etc/dnsmasq.d/*"], stdout=subprocess.PIPE).communicate()[0].decode("ascii").split('\n'):
    if re.search(r'server=.*\suplink.%i\s*$' % interfaceId, line):

        if count > 2:
            print("ERROR: too many DNS entries for uplink.%i: %s " % (interfaceId, line))
            continue

        segments = re.split(r'[\s=]',line)
        if len( segments ) < 2:
            print("ERROR: invalid dnsmasq.conf output: \"%s\"" % line)
            continue

        if ( re.match( ipRegex, segments[1] ) ):
            obj['v4Dns%i' % count] = segments[1]
            count = count +1


try:
    if not os.path.exists(os.path.dirname(fileName)):
        os.makedirs(os.path.dirname(fileName))
    file = open(fileName, 'w')
    json.dump(obj, file)
    file.write("\n")
    if verbosity > 0: print("Wrote: %s" % str(obj))
except Exception as e:
    print("ERROR: writing file: \"%s\"" % fileName)
    traceback.print_exc(e)
finally:
    file.flush()
    file.close()
