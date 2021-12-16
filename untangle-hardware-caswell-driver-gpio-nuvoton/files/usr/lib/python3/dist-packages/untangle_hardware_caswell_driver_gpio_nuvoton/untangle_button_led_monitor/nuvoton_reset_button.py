import os
import subprocess
import sys
import time

from untangle_button_led_monitor import Button, Logger, InputWatcher, Settings
import untangle_hardware_caswell_driver_gpio_nuvoton.untangle_button_led_monitor

class NuvotonResetButton(Button):
    """
    Reset button handler.

    Watch for button press and release.
    If the interval is less than 6 seconds, reboot the system.
    If the interval 6 seconds or greater, perform factory reset and reboot the system.
    """
    # Under this interval, reboot.
    # Over this interval, perform factory reset then reboot.
    reboot_interval_seconds = 6

    # Base gpio path for nuvoton driver
    sys_path="/sys/class/misc/gpio-nuvoton/"

    # Driver files to manipulate
    sys_filenames = [
        "select",
        "direction",
        "output",
        "input"
    ]

    # File to read to get system model.
    model_path = "/usr/share/untangle/conf/appliance-model"
    # Pins to watch are based on model type
    model_pins = {
        "w4":  {
            "status": 31, 
            "clear": 32
        },
        "w8": {
            "status": 62,
            "clear": 63
        }
    }

    # Flag is True if we are able to determine system model and pins.
    # Otherwise, False to not attempt processing.
    ready = False

    # Template of line to watch for in input result
    status_gpio_port_prefix_template = "GPIO Port{status_group}:"

    status_button = None
    status_button_time = None

    action = None

    def __init__(self):
        """
        Initialize object
        """
        #
        # Initialize paths for each file
        #
        self.paths = {}
        for filename in NuvotonResetButton.sys_filenames:
            self.paths[filename] = NuvotonResetButton.sys_path + filename

        # Determine model and pins to use.
        self.model = None
        self.pins = None
        try:
            with open(NuvotonResetButton.model_path, "r") as model_file:
                self.model = model_file.read().rstrip()
        except:
            Logger.message("Cannot read", sys.exc_info(), target="log")

        if self.model in NuvotonResetButton.model_pins:
            self.pins = NuvotonResetButton.model_pins[self.model]

        if self.model == None:
            Logger.message("Unable to find model")
        elif not self.model in NuvotonResetButton.model_pins:
            Logger.message("Unable to find model pins for model " + self.model)

        self.ready = True
        if Settings.Debug:
            Logger.message("model = " + self.model)
            Logger.message(self.pins)

        if self.pins is not None:
            # Set the full line to look for in input
            self.status_gpio_port_prefix = NuvotonResetButton.status_gpio_port_prefix_template.format(status_group=int(self.pins["status"] / 10)) 
            # Specific bit to watch change
            self.status_bit = int(self.pins["status"] % 10) 

    def start(self):
        """
        Start pgio for button capture
        """
        if self.ready is False:
            return

        # Initialize nuvoton gpio for button processing
        try:
            with open(self.paths["select"], "w") as gpio_export_file:
                gpio_export_file.write("{status} 1\n".format(**self.pins))
            with open(self.paths["select"], "w") as gpio_export_file:
                gpio_export_file.write("{clear} 1\n".format(**self.pins))
            with open(self.paths["direction"], "w") as gpio_export_file:
                gpio_export_file.write("{status} 1\n".format(**self.pins))
            with open(self.paths["direction"], "w") as gpio_export_file:
                gpio_export_file.write("{clear} 0\n".format(**self.pins))

            with open(self.paths["output"], "w") as gpio_export_file:
                gpio_export_file.write("{clear} 0\n".format(**self.pins))
        except:
            Logger.message("Cannot write", sys.exc_info(), target="log")

        InputWatcher.register(self.paths["input"], self.check_input)
        return

    def check_input(self, path, file):
        """
        Monitor activity of reset button value.
        """
        if self.ready is False:
            return

        current_status_button = None
        try:
            inputs = file.readlines()
            for input in inputs:
                input = input.decode('ascii').rstrip()
                if input.startswith(self.status_gpio_port_prefix):
                    # After decoding to ASCII, line comes out like:
                    # GPIO Port3:#0110x74
                    # The #0110 is some kind of whitespace; button value is in the hex number
                    status_input = input.split("x")
                    # Get the button status based on the status bit set or not.
                    current_status_button = (int(status_input[1],16) >> self.status_bit) & 1
                    Logger.message("current status_button = " + str(current_status_button))
                    if current_status_button == 1:
                        # Button pressed.  It will stay in this state forever,
                        # but we want to measure how long its being pressed.
                        # So clear it and if it hasn't been released, the next check
                        # check we'll see it in the same state.
                        # Then we can act upon length of button press.
                        with open(self.paths["output"], "w") as gpio_export_file:
                            gpio_export_file.write("{clear} 0\n".format(**self.pins))
                    break;
        except:
            Logger.message("Cannot read", sys.exc_info(), target="log")

        current_seconds = time.time()
        time_diff_seconds = 0
        if current_status_button == 1:
            # Button is in pressed state
            self.status_button = current_status_button
            if self.status_button_time is None:
                # First we've seen the press, note the start time.
                self.status_button_time = int(current_seconds)
            else:
                # Next time, in, determine how long state was held
                time_diff_seconds = int(current_seconds) - self.status_button_time

            # Set action to perform based on lenth of press
            if time_diff_seconds < NuvotonResetButton.reboot_interval_seconds:
                ## Reboot
                self.action = "reboot"
            else:
                ## Factory
                self.action = "factory"

        if current_status_button == 0 and self.action is not None:
            # Only act upon action after button release.
            if self.action == "reboot":
                self.reboot()
            elif self.action == "factory":
                self.factory_reset()

        # Nuvoton driver isn't smart enough to let us just keep
        # reading the open file over and over.
        file.close()

    def stop(self):
        if self.ready is False:
            return

        InputWatcher.unregister(self.paths["input"])
        return

    def reboot(self):
        """
        Call system reboot
        """
        if Settings.Debug:
            Logger.message("reboot")
        os.system("/bin/sync")
        # Fork off reboot.
        subprocess.Popen("/sbin/reboot", start_new_session=True)

    def factory_reset(self):
        """
        Perform factory reset
        """
        if Settings.Debug:
            Logger.message("factory reset")
        # Untangle factory reset followed by reboot - forked
        subprocess.Popen(["sh", "-c", '/usr/share/untangle/bin/ut-factory-defaults; /bin/sync; /sbin/reboot'], start_new_session=True)

    def get_status(self):
        return self.status
