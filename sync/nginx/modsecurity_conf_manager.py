"""This class is responsible for managing the modsecurity config for WAF"""
import os
from sync import registrar, Manager

class ModsecurityConfManager(Manager):
    untangle_crs_setup_conf = "/etc/modsecurity.d/owasp-crs/untangle-crs-setup.conf"

    def initialize(self):
        """Initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.untangle_crs_setup_conf, "restart-nginx", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        """sync the settings"""
        self.write_untangle_crs_setup_conf(settings_file.settings, prefix)

    def write_untangle_crs_setup_conf(self, settings, prefix):
        """write the untangle crs setup file"""
        filename = prefix + self.untangle_crs_setup_conf
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)
        
        self.current_file = open(filename, "w+")
        file = self.current_file
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")

        #license 
        file.write("# ------------------------------------------------------------------------\n")
        file.write("# OWASP ModSecurity Core Rule Set ver.3.4.0-dev\n")
        file.write("# Copyright (c) 2006-2020 Trustwave and contributors. All rights reserved.\n")
        file.write("# Copyright (c) 2021 Core Rule Set project. All rights reserved.\n")
        file.write("#\n")
        file.write("# The OWASP ModSecurity Core Rule Set is distributed under\n")
        file.write("# Apache Software License (ASL) version 2\n")
        file.write("# Please see the enclosed LICENSE file for full details.\n")
        file.write("# ------------------------------------------------------------------------\n")

        # mode of operation
        file.write("\n\n")
        file.write("# [[ Mode of Operation ]] \n")
        file.write("# Mode that the CRS will run in. At least one mode must be selected. \n")
        file.write("# Default is anomaly scoring mode logging to modsecurity audit and error logs\n")
        file.write('SecDefaultAction "phase:1,log,auditlog,pass"\n')
        file.write('SecDefaultAction "phase:2,log,auditlog,pass"\n')

        # paranoia level initialization
        file.write("\n\n")
        file.write("# [[ Paranoia Level Initialization ]] \n")
        file.write("# Allows you to choose the desired level of rule checks that will add to your security scores\n")
        file.write("Using defaults of 1, so rule is commented\n") # comment could change if we uncomment rule
        file.write("#SecAction \ \n")
        file.write('#  "id:900000,\ \n')
        file.write('#   phase:1,\ \n')
        file.write("#   nolog,\ \n")
        file.write("#   pass,\ \n")
        file.write("#   t:none,\ \n")
        file.write('#   setvar:tx.paranoia_level=1"\n')
        file.write("\n")
        file.write("# Executing paranoia level - add rules from higher paranoia levels\n")
        file.write("# Default is disabled, so rule is commented") # comment could change if we uncomment rule
        file.write("#SecAction \ \n")
        file.write('#  "id:900001,\ \n')
        file.write("#   phase:1,\ \n")
        file.write("#   nolog,\ \n")
        file.write("#   pass,\ \n")
        file.write("#   t:none,\ \n")
        file.write('#   setvar:tx.executing_paranoia_level=1"\n')

        # enforce body processor encoded
        file.write("\n\n")
        file.write(" [[ Enforce Body Processor URLENCODED ]] \n")
        file.write("# When on, forces the URLENCODED body processor when modsecurity can't determine body processor \n")
        file.write("# from Content-Type request header of client.")
        file.write("# Default is off, so rule is uncommented as rule would turn it on. \n") # comment could change if we uncomment rule
        file.write("#SecAction \ \n")
        file.write('#  "id:900010,\ \n')
        file.write("#   phase:1,\ \n")
        file.write("#   nolog,\ \n")
        file.write("#   pass,\ \n")
        file.write("#   t:none,\ \n")
        file.write('#   setvar:tx.enforce_bodyproc_urlencoded=1"\n')

        # anomaly scoring mode severity levels
        file.write("\n\n")
        file.write(" [[ Anomaly Scoring Mode SeverityLevels ]] \n")
        file.write("# Default scoring points for each severity level. \n")
        file.write("# These settings will be used to increment the anomaly score if a rule matches. \n")
        file.write("# Adjustment usually not needed \n")
        file.write("#SecAction \ \n")
        file.write('# "id:900100,\ \n')
        file.write("#  phase:1,\ \n")
        file.write("#  nolog,\ \n")
        file.write("#  pass,\ \n")
        file.write("#  t:none,\ \n")
        file.write("#  setvar:tx.critical_anomaly_score=5,\ \n")
        file.write("#  setvar:tx.error_anomaly_score=4,\ \n")
        file.write("#  setvar:tx.warning_anomaly_score=3,\ \n")
        file.write('#  setvar:tx.notice_anomaly_score=2"\n')

        # anomaly scoring mode blocking threshold levels
        





registrar.register_manager(ModsecurityConfManager())