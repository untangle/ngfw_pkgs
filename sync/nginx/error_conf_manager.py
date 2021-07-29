"""This class is responsible for writing out the Error handling conf file"""
from sync import registrar, Manager
import os

class ErrorsManager(Manager):
    errors_conf="/etc/modsecurity.d/errors.conf"
    
    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.errors_conf, "restart-nginx", self)

    def create_settings(self, settings_file, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        self.create_error_page_settings(settings_file)

    def sanitize_settings(self, settings_file):
        """sanitizes settings for ip lists"""
        print("%s: Sanitizing settings" % self.__class__.__name__)
        if "errorPages" not in settings_file.settings:
            settings_file = self.create_error_page_settings(settings_file)

    def sync_settings(self, settings_file, prefix, delete_list):
        """sync settings"""
        self.write_errors_to_conf(settings_file, prefix)

    def create_error_page_settings(self, settings_file):
        """create errorPages settings in settings_file. Empty object with custom html paths"""
        """
        This is a placeholder for custom 403 (or other) pages
        errorPages = {
            403: '/custom_403.html'
        }
        """
        error_pages = {}
        settings_file.settings['errorPages'] = error_pages
        return settings_file
    
    def write_errors_to_conf(self, settings_file, prefix):
        """write error handlging to errors.conf"""
        filename = prefix + self.errors_conf
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n\n\n")

        self.write_50xerror_to_conf(settings_file, file)
        self.write_403error_to_conf(settings_file, file)

        file.write("\n\n")
        file.flush()
        file.close()

    def write_403error_to_conf(self, settings_file, conf_file):
        """write 403 error handling"""
        #todo write custom 403 page to /403.html
        conf_file.write("error_page 403 /403.html;\n")
        conf_file.write("location = /403.html {\n")
        conf_file.write("\troot /etc/error-pages;\n")
        conf_file.write("\tsub_filter '{remote_ip}' '$remote_addr';\n")
        conf_file.write("\tsub_filter '{url}' '$scheme://$host$request_uri';\n")
        conf_file.write("\tsub_filter '{timestamp}' '$date_local';\n")
        conf_file.write('\tsub_filter_once on;\n')
        conf_file.write("}\n\n")
    
    def write_50xerror_to_conf(self, settings_file, conf_file):
        """write 50x error handling"""
        conf_file.write("error_page 500 502 503 504  /50x.html;\n")
        conf_file.write("location = /50x.html {\n")
        conf_file.write("\troot /usr/share/nginx/html;\n")
        conf_file.write("}\n\n")
        
        
registrar.register_manager(ErrorsManager())