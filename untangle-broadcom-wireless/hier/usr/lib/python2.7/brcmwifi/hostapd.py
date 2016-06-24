import StringIO, sys
from ConfigParser import RawConfigParser

from wifioptions import WifiOptionFactory, IfconfigOption

class Hostapd:

  HOSTAPD_DEFAULT_CONF = "/etc/hostapd.conf"
  FAKE_SECTION = "foo" # ConfigParser needs one

  PRE_WL_COMMANDS = [ IfconfigOption("down", None, "down"), # FIXME: nasty,
                      WifiOptionFactory.make("down"),
                      WifiOptionFactory.make("radio", "on"),
                      WifiOptionFactory.make("ap", 1),
                      # WifiOptionFactory.make("vht_features", 3),
                      # WifiOptionFactory.make("vhtmode", 1),
                      WifiOptionFactory.make("roam_delta", 15) ]

  POST_WL_COMMANDS = [ IfconfigOption("up", None, "up"), # FIXME: nasty
                       WifiOptionFactory.make("up") ]

  def __init__(self, filename = HOSTAPD_DEFAULT_CONF):
    self.filename = filename
    self.wlOptions = []
    self.nasOptions = []

    # read hostapd config
    with open(self.filename, 'r') as f:
      s = '[%s]\n%s' % (self.FAKE_SECTION, f.read())
      fd = StringIO.StringIO(s)

    # make a ConfigParser object from it
    self.config = RawConfigParser()
    self.config.readfp(fd)

  def convert(self):
    for key, value in self.config.items(self.FAKE_SECTION):
      option = WifiOptionFactory.make(key, value)
      if option: # push it to the associated command
        if option.COMMAND in ("wl","ifconfig"):
          self.wlOptions.append(option)
        else:
          self.nasOptions.append(option)

  def commands(self, interface):
    return self.wlCommands(interface) + self.nasCommands(interface)

  def wlCommands(self, interface):
    commands = []
    # one by one (yeah...)
    for wlOption in self.PRE_WL_COMMANDS + self.wlOptions + self.POST_WL_COMMANDS:
      commands.append("%s %s %s" % (wlOption.COMMAND,
                                    wlOption.defaultOptions(interface),
                                    str(wlOption)))
    return commands

  def nasCommands(self, interface):
    commands = [ "%s %s %s" % (self.nasOptions[0].COMMAND,
                               self.nasOptions[0].defaultOptions(interface),
                                " ".join(str(o) for o in self.nasOptions)) ]
    return commands
