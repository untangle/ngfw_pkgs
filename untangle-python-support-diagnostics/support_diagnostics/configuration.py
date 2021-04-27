import getopt
import json
import os
import pwd
import sys

class Configuration():
    """
    Discover/set application configuration

    Since modules like import_module need to access information here statically,
    this is just used as a static object.
    """
    user_path = None 
    file_path = ".support_diagnostics.json"
    platform = None

    default_settings = {
        "output": "report",
        "categories": ["all"],
        "updates": {
            "last_check_time": 0,
            "last_content_length": 0            
        }
    }
    settings = None

    @classmethod
    def static_init(cls):
        if os.path.isfile('/etc/debian_version'):
            Configuration.platform = 'debian'
        elif os.path.isfile('/etc/openwrt_version'):
            Configuration.platform = 'openwrt'

        Configuration.user_path = pwd.getpwuid(os.getuid())[5]
        Configuration.file_path = "{home_path}/{file_name}".format(home_path=Configuration.user_path, file_name=Configuration.file_path)
        Configuration.read()

        """
        Process options
        """
        handlers = {
            '--categories': Configuration.set_categories,
            '--output': Configuration.set_output,
            '--help': Configuration.usage
        }
        try:
            options, args = getopt.getopt(sys.argv[1:], 'h', ['categories=','output=','help'])
            for option,argument in options:
                # print(option)
                # print(argument)
                handlers[option](argument)

            # return args
        except getopt.GetoptError as exc:
            print(exc)
            self.usage(None)
            exit(1)

        Configuration.write()

    @classmethod
    def get_settings(cls):
        return Configuration.settings

    @classmethod
    def set_categories(cls,argument):
        """
        Set category list
        """
        Configuration.settings['categories'] = argument.lower().split(',')

    @classmethod
    def set_output(cls,argument):
        """
        Set output type
        """
        Configuration.settings['output'] = argument.lower()

    @classmethod
    def read(cls):
        Configuration.settings = Configuration.default_settings
        if os.path.isfile(Configuration.file_path):
            with open(Configuration.file_path, "r") as file:
                Configuration.settings = json.load(file)

    @classmethod
    def write(cls):
        with open(Configuration.file_path, "w") as file:
            json.dump(Configuration.settings, file, indent=4)

    @classmethod
    def usage(cls):
        """Print usage"""
        sys.stderr.write("""\
{command} usage:
optional arguments:
    --categories=cat1,cat2[...]  :   Categories to analyze.  Default='all'

""".format(command=sys.argv[0]))

if Configuration.platform is None:
    Configuration.static_init()