#!/usr/bin/python3
"""
System monitor to manage LEDs
"""
import atexit
import glob
import getopt
import importlib
import os
import signal
import sys
import time
import traceback

from pathlib import Path

from builtins import classmethod
from uvm import Uvm
from untangle_button_led_monitor import *

#
# Load extensions
#
Monitors = []
for path in glob.glob("/usr/lib/python3/*/*/untangle_button_led_monitor"):
    path_parts = path.split("/")
    imported_module = importlib.import_module(".".join(path_parts[-2:]))
    for name in [x for x in imported_module.__dict__ if not x.startswith("_")]:
        globals().update({name: getattr(imported_module, name)})
        if 'Monitor' in name:
            Monitors.append(globals()[name]())

class ExitHooks(object):
    """
    Monitor reason for exit
    """
    def __init__(self):
        self.exit_code = None
        self.exception = None

    def hook(self):
        self._orig_exit = sys.exit
        sys.exit = self.exit
        sys.excepthook = self.exc_handler

    def exit(self, code=0):
        self.exit_code = code
        self._orig_exit(code)

    def exc_handler(self, exc_type, exc, *args):
        self.exception_type = exc_type
        self.exception = exc
        trace_messages = []
        for line in traceback.format_exception(exc_type, exc, args[0]):
            for msg in line.split("\n"):
                trace_messages.append(msg)
        self.trace_messages = trace_messages

ExitHook = ExitHooks()
ExitHook.hook()

class GracefulKiller:
    """
    Watch for signals to kill and handle shutdown in a nice manner,
    such as shutting down monitors.
    """
    def __init__(self):
        """
        Register signals to watch for shutdown
        """
        signal.signal(signal.SIGINT, self.exit_gracefully)
        signal.signal(signal.SIGTERM, self.exit_gracefully)

    def exit_gracefully(self, *args):
        """
        Shut down monitors
        """
        for monitor in Monitors:
            monitor.stop()

        sys.exit(None)

class Daemon:
    """
    Daemon class
    """
    def __init__(self, name):
        """
        Specify pid filename - neccesary or can we figure out?
        """
        self.name = name
        self.pid_file_name = f'/tmp/{name}.pid'
	
    def daemonize(self):
        """
        Deamonize object
        """
        try: 
            pid = os.fork() 
            if pid > 0:
                sys.exit(0)
        except OSError as err: 
            Logger.message(f'fork #1 failed: {err}')
            sys.exit(1)
	
        # Decouple from parent environment
        os.chdir('/') 
        os.setsid() 
        os.umask(0) 
	
        # Do second fork
        try: 
            pid = os.fork() 
            if pid > 0:
                # exit from second parent
                sys.exit(0) 
        except OSError as err: 
            Logger.message(f'fork #2 failed: {err}')
            sys.exit(1) 
	
        # Redirect standard file descriptors
        sys.stdout.flush()
        sys.stderr.flush()
        std_in = open(os.devnull, 'r')
        std_out = open(os.devnull, 'a+')
        std_err = open(os.devnull, 'a+')

        os.dup2(std_in.fileno(), sys.stdin.fileno())
        os.dup2(std_out.fileno(), sys.stdout.fileno())
        os.dup2(std_err.fileno(), sys.stderr.fileno())
	
        # Write pid_file_name
        atexit.register(self.exit)

        pid = str(os.getpid())
        with open(self.pid_file_name,'w+') as f:
            f.write(pid + '\n')
	
    def exit(self):
        os.remove(self.pid_file_name)
        if ExitHook.exit_code is not None:
            Logger.message(f"sys.exit: {ExitHook.exit_code}")
        elif ExitHook.exception is not None:
            Logger.message(f"Exception type: {ExitHook.exception_type}")
            Logger.message(f"Exception: {ExitHook.exception}")
            Logger.message("Exception trace:")
            for message in ExitHook.trace_messages:
                Logger.message(message)

    def start(self):
        """
        Start the daemon.
        """
        # Check for a pid_file_name to see if the daemon already runs
        try:
            with open(self.pid_file_name,'r') as pf:
                pid = int(pf.read().strip())
        except IOError:
            pid = None
	
        if pid:
            Logger.message(f'pid_file_name {self.pid_file_name} already exist. " + "Daemon already running?')
            sys.exit(1)
		
        # Start the daemon
        parent_pid = os.getpid()
        self.daemonize()

        self.run()

    def stop(self):
        """
        Stop the daemon.
        """
        try:
            with open(self.pid_file_name,'r') as pf:
                pid = int(pf.read().strip())
        except IOError:
            pid = None
	
        if not pid:
            return

        # Try killing the daemon process	
        try:
            while 1:
                os.kill(pid, signal.SIGTERM)
                time.sleep(0.1)
        except OSError as err:
            e = str(err.args)
            if e.find("No such process") > 0:
                if os.path.exists(self.pid_file_name):
                    os.remove(self.pid_file_name)
                else:
                    sys.exit(1)

    def run(self):
        """
        Damon run method.
        """
        killer = GracefulKiller()
        defaults = Defaults(self.name)

        # Start monitors
        for monitor in Monitors:
            monitor.start()

        loop_interval = 1
        while True:
            if Settings.Debug is True:
                Logger.message(f'----------[top of loop - {loop_interval}s]')
            FileWatcher.check()
            NetlinkWatcher.check()
            InputWatcher.check()

            for monitor in Monitors:
                monitor.check()

            time.sleep(loop_interval)

def usage():
    """
    Show usage
    """
    print("usage")
    print("--start\tStart monitor")
    print("--stop\tStop monitor")

def main(argv):
    """
    Main loop
    """
    daemon = Daemon(Path(__file__).stem)
    try:
        opts, args = getopt.getopt(argv, "h", ["help", "start", "stop"])
    except getopt.GetoptError as error:
        print(error)
        usage()
        sys.exit(2)
    for opt, arg in opts:
        if opt in ("-h", "--help"):
            usage()
            sys.exit()
        elif opt == "--start":
            daemon.start()
        elif opt == "--stop":
            daemon.stop()
        else:
            usage()
            sys.exit(2)

    sys.exit(0)

if __name__ == "__main__":
    main(sys.argv[1:])
