#!/usr/bin/env python

import sys
sys.path.insert(0, sys.path[0] + "/" + "../" + "../" + "../" + "lib/" + "python2.7/")

import getopt
import signal
import os

# python2.7 includes json, python2.5 uses simplejson
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
print "Done."
