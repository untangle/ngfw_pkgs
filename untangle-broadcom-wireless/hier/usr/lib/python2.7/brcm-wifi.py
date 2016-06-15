#! /usr/bin/env python

import StringIO
from ConfigParser import RawConfigParser

## constants
HOSTAPD_CONF = "/etc/hostapd.conf"
FAKE_SECTION = "foo"

# make RawConfigParser objects behave like regular dictionaries
RawConfigParser.__getitem__ = lambda x, e: x.get(FAKE_SECTION, e)

## main

# read hostapd config
with open(HOSTAPD_CONF, 'r') as f:
  s = '[%s]\n%s' % (FAKE_SECTION, f.read())
  fd = StringIO.StringIO(s)

config = RawConfigParser()
config.readfp(fd)

# format options for nas(1)
print "-s %(ssid)s -m %(wpa)s -k %(wpa_passphrase)s" % config
