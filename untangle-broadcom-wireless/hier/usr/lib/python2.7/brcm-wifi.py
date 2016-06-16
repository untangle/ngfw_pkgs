#! /usr/bin/env python

import StringIO, sys
from ConfigParser import RawConfigParser

## constants
HOSTAPD_CONF = "/etc/hostapd.conf" # file to parse
FAKE_SECTION = "foo" # ConfigParser needs one

class WifiOption(object):
  def __init__(self, name, value, equivalent = None, converter = None, command = None):
    self.name = name
    self.value = value
    self.equivalent = equivalent
    if converter:
      self.converter = converter
    else:
      self.converter = lambda x: x
    self.command = command

  def __str__(self):
    value = self.converter(*(self.value,))
    return "%s%s %s" % (self.dash, self.equivalent, value)

  def defaultOptions(self, interface):
    return self.DEFAULT_OPTIONS % { 'interface' : interface }

  @classmethod
  def make(cls, name, value):
    equivalent = None
    converter = None
    isWl = False

    if name == 'ssid':
      equivalent = 's'
    elif name == 'country_code':
      isWl = True
      equivalent = 'country'
    elif name == 'auth_algs':
      equivalent = 'm'
      converter = lambda x: 4 if x >= 3 else 1
    elif name == 'channel':
      isWl = True
      equivalent = name
    elif name == 'wpa':
      pass # FIXME
    elif name == 'wpa_passphrase':
      equivalent = 'k'
      converter = lambda x: "'%s'" % x # single-quote it
    elif name == 'wpa_key_mgmt':
      # WARNING: nas only supports WPA-PSK
      pass
    elif name == 'wpa_pairwise':
      equivalent = 'w'
      # WARNING: nas only supports TKIP or AES; we choose TKIP
      converter = lambda x: 2
    elif name == 'rsn_pairwise':
      pass # not supported by RSA
    elif name == 'hw_mode':
      # eth1 only has band 'a', and eth2 'b', so we can't really
      # change them. If we could, we'do something like:
      #   isWl = True
      #   equivalent = 'band'
      #   converter = lambda x: 'a' if x == 'g' else x
      pass
    elif name == 'interface':
      pass # handled at command level
    elif name == 'max_num_sta':
      pass # FIXME
    elif name == 'ieee80211n':
      pass # FIXME
    elif name == 'ht_capab':
      pass # FIXME
    elif name == 'wmm_enabled':
      pass # FIXME
    else:
      print "%s option not supported" % name

    obj = None
    if equivalent:
      if isWl:
        obj = WlWifiOption(name, value, equivalent, converter)
      else:
        obj = NasWifiOption(name, value, equivalent, converter)

    return obj

class NasWifiOption(WifiOption):
  COMMAND = 'nas'
  DEFAULT_OPTIONS = "-P /tmp/nas.%(interface)s.pid -H 34954 -i %(interface)s -A -g 3600"

  def __init__(self, name, value, equivalent, converter):
    
    super(NasWifiOption, self).__init__(name, value, equivalent, converter)
    self.command = self.COMMAND
    self.dash = "-"

class WlWifiOption(WifiOption):
  COMMAND = 'wl'
  DEFAULT_OPTIONS = "-i %(interface)s"

  def __init__(self, name, value, equivalent, converter):
    super(WlWifiOption, self).__init__(name, value, equivalent, converter)
    self.command = self.COMMAND
    self.dash = ""


# make RawConfigParser objects behave like regular dictionaries
RawConfigParser.__getitem__ = lambda x, e: x.get(FAKE_SECTION, e)

## main

interface = sys.argv[1]
if len(sys.argv) == 3:
  hostapdConf = sys.argv[2]
else:
  hostapdConf = HOSTAPD_CONF

# read hostapd config
with open(hostapdConf, 'r') as f:
  s = '[%s]\n%s' % (FAKE_SECTION, f.read())
  fd = StringIO.StringIO(s)

# make a ConfigParser object from it
config = RawConfigParser()
config.readfp(fd)

# translate options
commands = { 'wl' : [],
             'nas' : [] }
for key, value in config.items(FAKE_SECTION):
  option = WifiOption.make(key, value)
  if option:
      commands[option.command].append(option)

# print resulting wl commands one by one (yeah...)
for wlOption in commands['wl']:
  print "wl %s %s" % (wlOption.defaultOptions(interface),
                      str(wlOption))

# print nas command
options = commands['nas']
print "nas %s %s" % (options[0].defaultOptions(interface),
                     " ".join(str(o) for o in options))

