import os
import struct
import sys

from untangle_button_led_monitor import Logger, Settings

class InputWatcher:
    """
    Singleton class to monitor input devices
    """
    path_file = {}
    path_method = {}

    ready = None

    @classmethod
    def static_init(cls):
        """
        Initalize singleton
        """
        InputWatcher.ready = True

    @classmethod
    def register(cls, path, method):
        InputWatcher.path_file[path] = None
        InputWatcher.path_method[path] = method

    @classmethod
    def unregister(cls, path):
        if path in InputWatcher.path_file:
            try:
                if InputWatcher.path_file[path] is not None and not InputWatcher.path_file[path].closed: 
                    InputWatcher.path_file[path].close()
            except:
                Logger.message(f'Cannot close file for {path}', sys.exc_info(), target="log")
            del InputWatcher.path_file[path]
        if path in InputWatcher.path_method:
            del InputWatcher.path_method[path]

    @classmethod
    def check(cls):
        if Settings.Debug:
            Logger.message()

        for path in InputWatcher.path_file:
            if InputWatcher.path_file[path] is None or InputWatcher.path_file[path].closed:
                if os.path.exists(path) == False:
                    continue
                try:
                    InputWatcher.path_file[path] = open(path, "rb")
                    os.set_blocking(InputWatcher.path_file[path].fileno(), False)
                except:
                    Logger.message(f'Cannot open file for {path}', sys.exc_info(), target="log")
                    continue

            # Call subscriber check method.
            InputWatcher.path_method[path](path, InputWatcher.path_file[path])

if InputWatcher.ready is None:
    InputWatcher.static_init()
