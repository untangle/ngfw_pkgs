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

class NasWifiOption(WifiOption):

  COMMAND = 'nas'
  DEFAULT_OPTIONS = "-P /tmp/nas.%(interface)s.pid -H 34954 -i %(interface)s -A -g 3600"

  def __init__(self, name, value, equivalent, converter):
    
    super(NasWifiOption, self).__init__(name, value, equivalent, converter)
    self.command = self.COMMAND
    self.dash = "-"

  def isWl(self):
    return False

class WlWifiOption(WifiOption):

  COMMAND = 'wl'
  DEFAULT_OPTIONS = "-i %(interface)s"

  def __init__(self, name, value, equivalent, converter):
    super(WlWifiOption, self).__init__(name, value, equivalent, converter)
    self.command = self.COMMAND
    self.dash = ""

  def isWl(self):
    return True

class WifiOptionFactory:

  @staticmethod
  def make(name, value):
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
      converter = lambda x: '4' if x >= 3 else 'wep'
    elif name == 'channel':
      if value != '0':
        # 0 means automatic channel, and should not be taken literally
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
      converter = lambda x: 4
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
      sys.exit(2)

    obj = None
    if equivalent:
      if isWl:
        obj = WlWifiOption(name, value, equivalent, converter)
      else:
        obj = NasWifiOption(name, value, equivalent, converter)

    return obj
