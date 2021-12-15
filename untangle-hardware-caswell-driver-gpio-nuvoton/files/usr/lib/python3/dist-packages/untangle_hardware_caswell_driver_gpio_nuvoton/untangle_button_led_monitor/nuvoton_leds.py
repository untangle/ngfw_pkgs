import sys

from untangle_button_led_monitor import Leds, Logger, Settings

class NuvotonLeds(Leds):
    """
    Manage nuvoton super IO leds for w4/w8 series.
    """
    gpio_select_path="/sys/class/misc/gpio-nuvoton/select"
    gpio_direction_path="/sys/class/misc/gpio-nuvoton/direction"
    gpio_output_path="/sys/class/misc/gpio-nuvoton/output"
    gpio_output_content_format = "{id} {value}"

    # File to read to get system model.
    model_path = "/usr/share/untangle/conf/appliance-model"
    # led_actions to write to  are based on model type
    model_led_actions = {
        "w4":  {
            "wifi": {
                "off":  [{ 'id': 74, 'value': 1 }],
                "on":   [{ 'id': 74, 'value': 0 }],
            },
        },
        "w8": {
            "wifi": {
                "off":  [{ 'id': 64, 'value': 1 }],
                "on":   [{ 'id': 64, 'value': 0 }],
            },
        }
    }

    status = {
        "wifi": {
            "action": "off"
        }
    }

    def __init__(self):
        """
        Initialize object
        """
        # Determine model and led action set to use.
        self.model = None
        try:
            with open(NuvotonLeds.model_path, "r") as model_file:
                self.model = model_file.read().rstrip()
        except:
            Logger.message("Cannot read", sys.exc_info(), target="log")

        if self.model in NuvotonLeds.model_led_actions:
            self.led_actions = NuvotonLeds.model_led_actions[self.model]

        if self.model == None:
            Logger.message("Unable to find model")
        elif not self.model in NuvotonLeds.model_led_actions:
            Logger.message("Unable to find model led actions for model " + self.model)

        self.ready = True
        if Settings.Debug:
            Logger.message("model = " + self.model)
            Logger.message(self.led_actions)

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
