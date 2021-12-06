import os
import pyinotify

from untangle_button_led_monitor import Logger, Settings

class FileWatcherEventProcessor(pyinotify.ProcessEvent):
    _methods = [
        'IN_ACCESS',
        'IN_MODIFY',
        'IN_ATTRIB',
        'IN_CLOSE_WRITE',
        'IN_CLOSE_NOWRITE',
        'IN_OPEN',
        'IN_MOVED_FROM',
        'IN_MOVED_TO',
        'IN_CREATE',
        'IN_DELETE',
        'IN_DELETE_SELF',
        'IN_MOVE_SELF',
        'IN_UNMOUNT',
        'IN_Q_OVERFLOW',
        'IN_IGNORED',
        'IN_ONLYDIR',
        'IN_DONT_FOLLOW',
        'IN_EXCL_UNLINK',
        'IN_MASK_ADD',
        'IN_ISDIR',
        'IN_ONESHOT',
        "default"
    ]

class FileWatcher:
    """
    Singleton class to monitor filesystem changes using pyinotify
    """
    ready = None
    watch_manager = None
    event_notifier = None

    path_exist_dir = {}
    path_method = {}
    path_mask = {}

    @classmethod
    def static_init(cls):
        for method in FileWatcherEventProcessor._methods:
            FileWatcher.process_generator(FileWatcherEventProcessor, method)

        FileWatcher.watch_manager = pyinotify.WatchManager()
        FileWatcher.event_notifier = pyinotify.Notifier(FileWatcher.watch_manager, FileWatcherEventProcessor())

        FileWatcher.ready = True

    @classmethod
    def get_mask(cls, mask_name):
        mask = 0
        found = False
        mask_name = mask_name.upper()
        for flags in pyinotify.EventsCodes.FLAG_COLLECTIONS:
            if mask_name == "ALL":
                found = True
                for flag_mask_name in pyinotify.EventsCodes.FLAG_COLLECTIONS[flags]:
                    mask |= pyinotify.EventsCodes.FLAG_COLLECTIONS[flags][flag_mask_name]
            elif mask_name in pyinotify.EventsCodes.FLAG_COLLECTIONS[flags]:
                return pyinotify.EventsCodes.FLAG_COLLECTIONS[flags][mask_name]
        if found is False:
            raise ValueError(f'Unknown mask_name={mask_name}')
        return mask

    @classmethod
    def register(cls, path, method=None, mask=[pyinotify.ALL_EVENTS], exist_check=True):
        absolute_path = os.path.abspath(path)
        FileWatcher.path_method[absolute_path] = method
        FileWatcher.watch_manager.add_watch(absolute_path, mask)
        if exist_check is True:
            # File may not exist so watch parent path directory instead.
            dir_paths = os.path.dirname(absolute_path).split('/')
            dir_path = '/'.join(dir_paths)

            # Keep walking up parents looking for existing directory.
            # If we reach end, then don't bother; we're not going
            # to listen for everything under /
            while os.path.exists(dir_path) is False:
                dir_paths.pop()
                if len(dir_paths) == 0:
                    dir_path = None
                    break
                dir_path = '/'.join(dir_paths)

            if dir_path is None:
                Logger.message(f'Cannot add listener for {absolute_path} (cannot find existing parent directory)')
            else:
                FileWatcher.path_exist_dir[dir_path] = dir_path
                # Check for close file and create (symlink)
                FileWatcher.watch_manager.add_watch(dir_path, FileWatcher.get_mask('IN_CLOSE_WRITE') | FileWatcher.get_mask('IN_CREATE'), rec=True, auto_add=True)

        if Settings.Debug:
            Logger.message(f'path={absolute_path}, method={method}, mask={mask}')

    @classmethod
    def unregister(cls, path=None):
        absolute_path = os.path.abspath(path)
        if absolute_path.endswith('*'):
            absolute_path = absolute_path[:-1]
            for path in FileWatcher.path_method:
                if path.startswith(absolute_path):
                    if absolute_path in FileWatcher.path_method:
                        del FileWatcher.path_method[absolute_path]
                    wd = FileWatcher.watch_manager.get_wd(absolute_path)
                    if wd is not None:
                        FileWatcher.watch_manager.del_watch(wd)
        else:
            if absolute_path in FileWatcher.path_method:
                del FileWatcher.path_method[absolute_path]
                wd = FileWatcher.watch_manager.get_wd(absolute_path)
                if wd is not None:
                    FileWatcher.watch_manager.del_watch(wd)
        return

    @classmethod
    def check(cls):
        if Settings.Debug:
            Logger.message()

        if FileWatcher.event_notifier.check_events(timeout=100):
            FileWatcher.event_notifier.read_events()
            FileWatcher.event_notifier.coalesce_events()
            FileWatcher.event_notifier.process_events()

    @classmethod
    def process_generator(cls2, cls, method):
        def _method_name(self, event):
            if Settings.Debug:
                Logger.message( "Method name: process_{}()\n"
                   "Path name: {}\n"
                "Event Name: {}\n".format(method, event.pathname, event.maskname))

            if event.pathname in FileWatcher.path_method:
                FileWatcher.path_method[event.pathname](event.pathname, event.maskname)
            else:
                # See if file was created in directory.
                for path in FileWatcher.path_exist_dir:
                    if event.pathname == path \
                       and event.pathname in FileWatcher.path_method:
                        FileWatcher.path_method[event.pathname](event.pathname, event.maskname)

        _method_name.__name__ = "process_{}".format(method)
        setattr(cls, _method_name.__name__, _method_name)

if FileWatcher.ready is None:
    FileWatcher.static_init()
