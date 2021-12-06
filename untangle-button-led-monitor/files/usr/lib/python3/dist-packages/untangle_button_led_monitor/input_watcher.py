import struct

from untangle_button_led_monitor import Logger, Settings

class InputWatcher:
    """
    Singleton class to monitor input devices
    """
    # Binary format for input events:
    # time_seconds
    # time_microseconds
    # input type
    # input code
    # input value
    event_format = 'llHHI'

    path_file = {}
    path_method = {}

    ready = None
    @classmethod
    def static_init(cls):
        """
        Initalize singleton
        """
        InputWatcher.event_size = struct.calcsize(InputWatcher.event_format)
        InputWatcher.ready = True

    @classmethod
    def register(cls, path, method):
        InputWatcher.path_file[path] = None
        InputWatcher.path_method[path] = method

    @classmethod
    def unregister(cls, path):
        if path in InputWatcher.path_file:
            try:
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
            if InputWatcher.path_file[path] is None:
                if os.path.exists(path) == False:
                    continue
                try:
                    InputWatcher.path_file[path] = open(path, "rb")
                    os.set_blocking(InputWatcher.path_file[path].fileno(), False)
                except:
                    Logger.message(f'Cannot open file for {path}', sys.exc_info(), target="log")
                    continue

            file = InputWatcher.path_file[path]

            while True:
                try:
                    event = file.read(InputWatcher.event_size)
                except:
                    Logger.message(f'Cannot read from file for {path}', sys.exc_info(), target="log")
                    InputWatcher.path_file[path] = None
                    event = None

                if event is None:
                    break

                (tv_sec, tv_usec, type, code, value) = struct.unpack(InputWatcher.event_format, event)

                if type != 0 or code != 0 or value != 0:
                    if Settings.Debug:
                        Logger.message(f'Event type {type}, code {code}, value{value} at {tv_sec}.{tv_usec}')
                    InputWatcher.path_method[path](path, tv_sec, tv_usec, type, code, value)
                else:
                    if Settings.Debug:
                        # Events with code, type and value == 0 are "separator" events
                        Logger.message("===========================================")

if InputWatcher.ready is None:
    InputWatcher.static_init()
