import logging
import logging.handlers
import os
from pathlib import Path
from types import TracebackType
import traceback
import inspect

class Logger:
    """
    Manage log messages to stdout and/or logging.
    """
    logger = None
    handler = None
    target = None

    @classmethod
    def static_init(cls):
        """
        Initialze logger using our script name.
        """
        stack = inspect.stack()
        Logger.logger = logging.getLogger(Path(os.path.basename(stack[len(stack)-1].filename)).stem)
        Logger.logger.setLevel(logging.INFO)

        Logger.handler = logging.handlers.SysLogHandler(address = '/dev/log')
        Logger.handler.setFormatter(
            logging.Formatter("%(name)s %(message)s")
        )
        Logger.logger.addHandler(Logger.handler)

    def message(*args, **kwargs):
        """
        Output messages.
        *args contains message to display.  
                This can also contain sys.exc_info() for an exception stack trace, like:
                Logger.message("Cannot do someting", sys.exc_info(), target="log")
        *kwargs can contain:
            target          'log' or nothing to only do stdout
            message_joiner  string to use to join messages.
            stdout          If True (default) always output message to stdout.  If  False, don't output
            capture_path    If True (default) attempt to detect and prefix calling class and function.
        """
        messages = list(args)

        capture_path = True
        if "capture_path" in kwargs:
            capture_path = kwargs["capture_path"]

        if capture_path:
            # Get the caller method and class name.
            messages.insert(0,inspect.stack()[1].function)

            # Determine class name.
            class_name = None
            if inspect.stack()[1][0]:
                if "self" in inspect.stack()[1][0].f_locals and  \
                    inspect.stack()[1][0].f_locals["self"].__class__:
                    # Determine class from object.
                    if type(inspect.stack()[1][0].f_locals["self"]) is type:
                        class_name = inspect.stack()[1][0].f_locals["self"].__name__
                    else:
                        class_name = inspect.stack()[1][0].f_locals["self"].__class__.__name__
                if 'cls' in inspect.stack()[1][0].f_locals:
                    # Static call
                    class_name = inspect.stack()[1][0].f_locals['cls'].__name__
            if class_name is not None:
                messages.insert(0, class_name)

        message_joiner = ": "
        if "message_joiner" in kwargs:
            message_joiner = kwargs["message_joiner"]

        ## Look for and process "sub messages" like exceptions.
        sub_messages = None
        remove_message_indexes = []
        for index, message in enumerate(messages):
            is_exception = False

            if type(message) is tuple:
                for item in message:
                    if isinstance(item,TracebackType):
                        is_exception = True

            if is_exception:
                ## Found an exception to process.
                remove_message_indexes.append(index)
                is_exception = False
                sub_messages = []
                new_sub_message = []
                for line in traceback.format_exception(message[0],message[1],message[2]):
                    for msg in line.split("\n"):
                        new_sub_message = []
                        if capture_path:
                            new_sub_message.append(messages[0])
                            new_sub_message.append(messages[1])
                        new_sub_message.append(msg)
                        sub_messages.append(new_sub_message)
        if len(remove_message_indexes):
            # Remove messages we processed as sub messages
            for index in reversed(remove_message_indexes):
                del messages[index]
            
        full_message = message_joiner.join(str(message) for message in messages)

        target=Logger.target
        if "target" in kwargs:
            target=kwargs["target"]

        if target == "log":
            Logger.logger.info(full_message)

        stdout = True
        if "stdout" in kwargs:
            stdout=kwargs["stdout"]
        if stdout:
            print(full_message)

        if sub_messages:
            # Output sub messages
            sub_kwargs = kwargs
            sub_kwargs["capture_path"] = False
            for sub_message in sub_messages:
                Logger.message(*sub_message, **sub_kwargs)

if Logger.logger is None:
    Logger.static_init()
    Logger.target = "log"
