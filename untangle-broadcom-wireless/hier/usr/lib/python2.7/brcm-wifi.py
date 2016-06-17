#! /usr/bin/env python

import sys
from brcmwifi import Hostapd

## functions
def usage():
  print "Usage: %s interface [/path/to/hostapd.conf]" % sys.argv[0]

## main

# cl-args
if len(sys.argv) not in (2,3):
  usage()
  sys.exit(1)

interface = sys.argv[1]
if len(sys.argv) == 3:
  hostapdConf = sys.argv[2]
else:
  hostapdConf = None

# hostapd conf object
hostapd = Hostapd(hostapdConf)

# translate hostapd options
hostapd.convert()

# print resulting commands
for command in hostapd.commands(interface):
  print command
