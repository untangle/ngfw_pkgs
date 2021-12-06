import json
import os
import re
import sys
import time

from uvm import Uvm

from untangle_button_led_monitor import Monitor, Logger, FileWatcher, NetlinkWatcher
import untangle_hardware_caswell_driver_gpio_nuvoton.untangle_button_led_monitor

Debug = False

class NuvotonMonitor(Monitor):
    """
    Monitor wifi carrier status.
    Turn on Caswell LED if any wireless interfaces are enabled and link detected.
    Turn off Caswell LED if all wireless interfaces are disabled or link not detected. 
    """
    network_settings_file_name = '/usr/share/untangle/settings/untangle-vm/network.js'

    wireless_devices = []

    link_status = {}

    def network_settings_load(self, path=None, maskname=None):
        """
        Load network settings to determine active WAN devices
        """
        if os.path.exists(self.network_settings_file_name) is False:
            return

        with open(self.network_settings_file_name, "r") as network_settings_file:
            network_settings = json.load(network_settings_file)

        self.link_status = {}

        # Get wireless devices to monitor
        wireless_devices = []    
        for interface in network_settings.get('interfaces').get('list'):
            if interface.get('isWirelessInterface') == False:
                continue
            device = interface.get('systemDev')
            wireless_devices.append(device)

        self.wireless_devices = wireless_devices
        # Clear and re-register known devices
        NetlinkWatcher.clear_registers()
        # Remove all other status file watchers.
        for device in self.wireless_devices:
            # Watch for link status change.
            NetlinkWatcher.register(device, self.check_device_link_status)
            self.check_device_link_status(device)

    def check_device_link_status(self, device):
        """
        Determine device's link status
        """
        carrier = 0
        try:
            with open(f'/sys/class/net/{device}/carrier', "r") as status_file:
                carrier = int(status_file.read().strip())
        except:
            carrier = 0

        self.link_status[device] = carrier == 1

    def get_status(self):
        if len(self.link_status) == 0 or not True in self.link_status.values():
            # Either no wireless interfaces or all have no link.
            return "nolink"

    def start(self):
        """
        Initialize listener by loading settings
        """
        self.leds = untangle_hardware_caswell_driver_gpio_nuvoton.untangle_button_led_monitor.NuvotonLeds()
        self.leds.init()

        # Interested when network settings change
        FileWatcher.register(self.network_settings_file_name, self.network_settings_load, FileWatcher.get_mask('IN_CLOSE_WRITE'))
        self.network_settings_load()

        ## !!! debug
        self.leds.set_led("wifi", "on", False)
        return

    def check(self):
        if self.get_status() == "nolink":
            self.leds.set_led("wifi", "off", False)
        else:
            self.leds.set_led("wifi", "on", False)

    def stop(self):
        FileWatcher.unregister(self.network_settings_file_name)
        self.leds.set_led("wifi", "off", False)
        self.leds.close()
