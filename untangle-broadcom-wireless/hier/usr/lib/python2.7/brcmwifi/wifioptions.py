import sys

class WifiOption(object):

  def __init__(self, name, value = None, equivalent = None, converter = None, command = None):
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
    ret = "%s%s" % (self.dash, self.equivalent)
    if value:
      ret += " %s" % value
    return ret

  def defaultOptions(self, interface):
    return self.DEFAULT_OPTIONS % { 'interface' : interface }

class NasWifiOption(WifiOption):

  COMMAND = 'nas'
  # FIXME: probably unsafe to hardcode the bridge name like that
  DEFAULT_OPTIONS = "-P /tmp/nas.%(interface)s.pid -l br.eth0-2 -i %(interface)s -A -g 3600"

  def __init__(self, name, value = None, equivalent = None, converter = None):
    
    super(NasWifiOption, self).__init__(name, value, equivalent, converter)
    self.command = self.COMMAND
    self.dash = "-"

class WlWifiOption(WifiOption):

  COMMAND = 'wl'
  DEFAULT_OPTIONS = "-i %(interface)s"

  def __init__(self, name, value = None, equivalent = None, converter = None):
    super(WlWifiOption, self).__init__(name, value, equivalent, converter)
    self.command = self.COMMAND
    self.dash = ""

class IfconfigOption(WifiOption):

  COMMAND = 'ifconfig'
  DEFAULT_OPTIONS = "%(interface)s"

  def __init__(self, name, value = None, equivalent = None, converter = None):
    super(IfconfigOption, self).__init__(name, value, equivalent, converter)
    self.command = self.COMMAND
    self.dash = ""

class WifiOptionFactory:

  @staticmethod
  def make(name, value = None):
    equivalent = None
    converter = None
    isWl = False
    isIfconfig = False

    if name == 'ssid':
      equivalent = 's'
    elif name == 'country_code':
      isWl = True
      equivalent = 'country'
    elif name == 'channel':
      if value != '0':
        # 0 means automatic channel, and should not be taken literally
        isWl = True
        equivalent = name
    elif name == 'wpa':
      equivalent = 'm'
      def converter(x):
        if x == '1': # WPA
          return 4
        elif x == '2': # WPA2
          return 128
        elif x == '3': # WPA/WPA2
          return 132
      pass # FIXME
    elif name == 'wpa_passphrase':
      equivalent = 'k'
    elif name == 'wpa_key_mgmt':
      # WARNING: nas only supports WPA-PSK
      pass
    elif name == 'wpa_pairwise':
      equivalent = 'w'
      def converter(x):
        if x == 'CCMP':
          return 4
        elif x == 'TKIP':
          return 2
        else: # TKIP+AES
          return 6
    elif name == 'rsn_pairwise':
      pass # not supported by RSA
    elif name == 'hw_mode':
      # eth1 only has band 'a', and eth2 'b', so we can't really
      # change them. If we could, we'do something like:
      #   isWl = True
      #   equivalent = 'band'
      #   converter = lambda x: 'a' if x == 'g' else x
      pass
    elif name in ("down","radio","ap","roam_delta","up","vht_features","vhtmode"):
      isWl = True
      equivalent = name
    elif name == 'interface':
      pass # handled at command level
    elif name == 'auth_algs':
      pass # not supported
    elif name == 'max_num_sta':
      pass # FIXME ?
    elif name == 'ieee80211n':
      pass # FIXME ?
    elif name == 'ht_capab':
      pass # FIXME ?
    elif name == 'wmm_enabled':
      pass # FIXME ?
    else:
      print "%s option not supported" % name
      sys.exit(2)

    obj = None
    if equivalent:
      if isWl:
        obj = WlWifiOption(name, value, equivalent, converter)
      elif isIfconfig:
        obj = IfconfigOption(name, value, equivalent, converter)
      else:
        obj = NasWifiOption(name, value, equivalent, converter)

    return obj
