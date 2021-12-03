import os
import sys

from untangle_button_led_monitor import Logger, Settings

class Leds:
    """
    Manage leds through gpio.
    Extensions extend/override.
    """
    leds = None

    gpio_export_path = "/sys/class/gpio/export"
    gpio_unexport_path = "/sys/class/gpio/unexport"
    gpio_path = "/sys/class/gpio/gpio{gpio_id}"
    gpio_direction_path = "/sys/class/gpio/gpio{gpio_id}/direction"
    gpio_value_path = "/sys/class/gpio/gpio{gpio_id}/value"
    gpio_value_content = "{value}\n"

    led_actions = {}

    status = {}

    def get_gpio_ids(self):
        ids = []
        for led in self.led_actions:
            for action in self.led_actions[led]:
                for id_value in self.led_actions[led][action]:
                    if id_value["id"] not in ids:
                        ids.append(id_value["id"])
        return ids

    def init(self):
        """
        Prepare gpio for use
        """
        self.close_gpio()
        self.open_gpio()

    def close(self):
        """
        Shutdown gpio
        """
        self.close_gpio()

    def open_gpio(self):
        """
        Initialize gpio for use
        """
        for gpio_id in self.get_gpio_ids():
            gpio_path = self.gpio_path.format(gpio_id=gpio_id)
            if os.path.isdir(gpio_path):
                continue
            try:
                with open(self.gpio_export_path, "w") as gpio_export_file:
                    gpio_export_file.write("{gpio_id}\n".format(gpio_id=gpio_id))
                with open(self.gpio_direction_path.format(gpio_id=gpio_id), "w") as gpio_direction_file:
                    gpio_direction_file.write(self.gpio_value_content.format(value="out"))
            except:
                Logger.message("Cannot write", sys.exc_info(), target="log")
                continue
        self.leds = True

    def close_gpio(self):
        """
        Turn off all gpios
        """
        for gpio_id in self.get_gpio_ids():
            gpio_path = self.gpio_path.format(gpio_id=gpio_id)
            if os.path.isdir(gpio_path) == False:
                continue
            try:
                with open(self.gpio_direction_path.format(gpio_id=gpio_id), "w") as gpio_direction_file:
                    gpio_direction_file.write(self.gpio_value_content.format(value="in"))
                with open(self.gpio_unexport_path, "w") as gpio_export_file:
                    gpio_export_file.write("{gpio_id}\n".format(gpio_id=gpio_id))
            except:
                Logger.message("Cannot write", sys.exc_info(), target="log")
                continue
        self.leds = False

    def set_led(self, led, action, blink=False):
        """
        Prepare gpio for use
        """
        if Settings.Debug:
            if blink:
                blink_solid = "blink"
            else:
                blink_solid = "solid"
            Logger.message(f'{led} {action} {blink_solid}')

        if not led in self.led_actions:
            raise ValueError("Unknown led={led}".format(led=led))
        if not action in self.led_actions[led]:
            raise ValueError("Unknown type={action}".format(action=action))

        status = self.status[led]
        if status["action"] == action:
            if blink is True:
                action = "off"
            else:
                return

        for id_value in self.led_actions[led][action]:
            try:
                with open(self.gpio_value_path.format(gpio_id=id_value["id"]), "w") as gpio_value_file:
                    gpio_value_file.write(self.gpio_value_content.format(value=id_value["value"]))
            except:
                continue

        status["action"] = action
