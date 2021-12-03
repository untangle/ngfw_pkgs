from untangle_button_led_monitor import Leds, Logger, Settings

class NuvotonLeds(Leds):
    """
    Manage nuvoton super IO leds for w4/w8 series.
    """
    gpio_select_path="/sys/class/misc/gpio-nuvoton/select"
    gpio_direction_path="/sys/class/misc/gpio-nuvoton/direction"
    gpio_output_path="/sys/class/misc/gpio-nuvoton/output"
    gpio_output_content_format = "{id} {value}"

    led_actions = {
        "wifi": {
            "off":  [{ 'id': 74, 'value': 1 }],
            "on":   [{ 'id': 74, 'value': 0 }],
        },
    }

    status = {
        "wifi": {
            "action": "off"
        }
    }

    def open_gpio(self):
        """
        Initialize gpio for use
        """
        for gpio_id in self.get_gpio_ids():
            try:
                with open(self.gpio_select_path, "w") as gpio_export_file:
                    gpio_export_file.write("{gpio_id} 1\n".format(gpio_id=gpio_id))
                with open(self.gpio_direction_path.format(gpio_id=gpio_id), "w") as gpio_direction_file:
                    gpio_direction_file.write("{gpio_id} 0\n".format(gpio_id=gpio_id))
            except:
                Logger.message("Cannot write", sys.exc_info(), target="log")
                continue
        self.leds = True

    def close_gpio(self):
        """
        No real way to close gpio for these leds.
        """
        return

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
            Logger.message("no led")
            raise ValueError("Unknown led={led}".format(led=led))
        if not action in self.led_actions[led]:
            Logger.message("no action")
            raise ValueError("Unknown type={action}".format(action=action))

        status = self.status[led]
        if status["action"] == action:
            if blink is True:
                action = "off"
            else:
                return

        for id_value in self.led_actions[led][action]:
            try:
                with open(self.gpio_output_path, "w") as gpio_output_file:
                    gpio_output_file.write(self.gpio_output_content_format.format(id=id_value["id"], value=id_value["value"]))
            except:
                continue

        status["action"] = action
