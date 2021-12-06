import os
import sys

from untangle_button_led_monitor import Logger, FileWatcher, Settings

from pathlib import Path

class Defaults:
    """
    Load defaults for dynamic configuration changes to settings, such as debug flag.
    """
    file_name = None
    last_mtime = None

    def __init__(self, name):
        """
        Register defaults with file watcher.
        """
        name = Path(name).stem
        if self.file_name is None:
            self.file_name = f'/etc/default/{name}'

        if os.path.exists(self.file_name) == True:
            FileWatcher.register(self.file_name, self.load, FileWatcher.get_mask('IN_CLOSE_WRITE'))
            self.load()

    def load(self, path=None, maskname=None):
        """
        Read and process defaults file.
        """
        if os.path.exists(self.file_name) == False:
            return
        mtime = os.stat(self.file_name).st_mtime

        if self.last_mtime is None or self.last_mtime != mtime:
            self.last_mtime = mtime
            with open(self.file_name, "r") as defaults_file:
                for line in defaults_file.readlines():
                    line = line.strip()
                    if line == "":
                        continue
                    if line.startswith("#"):
                        continue
                    if "=" in line:
                        (key,value) = line.split("=")
                        key = key.strip()
                        value = value.strip()
                        try:
                            if value == 'False' or value == 'True' or '[' in value or '{' in value:
                                value = eval(value)
                            Settings.set(key.strip(), value)
                        except:
                            Logger.message(f'Unable to set {key}={value}', sys.exc_info())
                            continue

                        if Settings.Debug == True:
                            Logger.message(f'set {key}={value}')

