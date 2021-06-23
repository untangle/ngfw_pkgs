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
        file.write("# Default is off, so rule is commented as the uncommented rule would turn it on. \n") # comment could change if we uncomment rule
        file.write("#SecAction \ \n")
        file.write('#  "id:900010,\ \n')
        file.write("#   phase:1,\ \n")
        file.write("#   nolog,\ \n")
        file.write("#   pass,\ \n")
        file.write("#   t:none,\ \n")
        file.write('#   setvar:tx.enforce_bodyproc_urlencoded=1"\n')

        # anomaly scoring mode severity levels
        file.write("\n\n")
        file.write(" [[ Anomaly Scoring Mode Severity Levels ]] \n")
        file.write("# Default scoring points for each severity level. \n")
        file.write("# These settings will be used to increment the anomaly score if a rule matches. \n")
        file.write("# Adjustment usually not needed\n")
        file.write("# Using default, so rule is commented.\n") # comment could change if we uncomment rule
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
        file.write("\n\n")
        file.write(" [[ Anomaly Scoring Mode Blocking Threshold Levels ]] \n")
        file.write("# Here, you can specify at which cumulative anomaly score an inbound request,\n")
        file.write("# or outbound response, gets blocked.\n")
        file.write("# At default value, a single critical rule match will cause the request to be blocked.\n")
        file.write("# Using default value, so rule is commented.\n") # comment could change if we uncomment rule
        file.write("#SecAction \ \n")
        file.write('# "id:900110,\ \n')
        file.write("#  phase:1,\ \n")
        file.write("#  nolog,\ \n")
        file.write("#  pass,\ \n")
        file.write("#  t:none,\ \n")
        file.write("#  setvar:tx.inbound_anomaly_score_threshold=5,\ \n")
        file.write('#  setvar:tx.outbound_anomaly_score_threshold=4" \n')

        # early anomaly scoring mode blocking
        file.write("\n\n")
        file.write(" [[ Early Anomaly Scoring Mode Blocking ]] \n")
        file.write("# Enable early evaluation of anomaly scores at end of phase:1 and phase:3. \n")
        file.write("# Evaluation usually occurs at the end of phase:2 and phase:4. \n")
        file.write("# Default is off, so rule is commented \n") # comment could change if we uncomment rule
        file.write("#SecAction \ \n")
        file.write('#  "id:900120,\ \n')
        file.write("#  phase:1,\ \n")
        file.write("#  nolog,\ \n")
        file.write("#  pass,\ \n")
        file.write("#  t:none,\ \n")
        file.write('#  setvar:tx.blocking_early=1"\n')

        # app specific rule exclusions 
        file.write("\n\n")
        file.write(" [[ Application Specific Rule Exclusions ]] \n")
        file.write("# Some well-known applications may undertake actions that appear to be malicious. \n")
        file.write("# In such cases the CRS aims to prevent false positives by allowing prebuilt, application \n")
        file.write("# specific exclusions on an application by application basis. \n")
        file.write("By default, no exclusions apply, so rule is commented, \n") # comment could change if we uncomment rule
        file.write("#SecAction \ \n")
        file.write('# "id:900130,\ \n')
        file.write("#  phase:1,\ \n")
        file.write("#  nolog,\ \n")
        file.write("#  pass,\ \n")
        file.write("#  t:none,\ \n")
        # TODO: adjust exclusions below. 1 is enable exclusions, 0 is not enabled
        file.write("#  setvar:tx.crs_exclusions_cpanel=1,\ \n")
        file.write("#  setvar:tx.crs_exclusions_dokuwiki=1,\ \n")
        file.write("#  setvar:tx.crs_exclusions_drupal=1,\ \n")
        file.write("#  setvar:tx.crs_exclusions_nextcloud=1,\ \n")
        file.write("#  setvar:tx.crs_exclusions_phpbb=1,\ \n")
        file.write("#  setvar:tx.crs_exclusions_phpmyadmin=1,\ \n")
        file.write("#  setvar:tx.crs_exclusions_wordpress=1,\ \n")
        file.write('#  setvar:tx.crs_exclusions_xenforo=1"\n')

        # HTTP policy settings - methods
        # UNTANGLE CHANGED NORMAL DEFAULTS
        file.write("\n\n")
        file.write("# [[ HTTP Policy Settings - HTTP Methods ]] \n")
        file.write("# HTTP methods that a client is allowed to use \n")
        file.write("# Allowing methods for normal websites and RESTful APIs \n") # comment could change if rule changes
        file.write("SecAction \ \n")
        file.write(' "id:900200,\ \n')
        file.write("  phase:1,\     \n")
        file.write("  nolog,\ \n")
        file.write("  pass,\ \n")
        file.write("  t:none,\ \n")
        file.write("  setvar:'tx.allowed_methods=GET HEAD POST OPTIONS PUT PATCH DELETE'\" \n")

        # HTTP Policy Settings - Content-Types
        file.write("\n\n")
        file.write("# [[ HTTP Policy Settings - Content-Types ]] \n")
        file.write("# Allowed Content-Types header from clients \n")
        file.write("# Using defaults, so rule is commented. \n") # comment could change if rule changes
        file.write("#SecAction \ \n")
        file.write('# "id:900220,\ \n')
        file.write("#  phase:1,\ \n")
        file.write("#  nolog,\ \n")
        file.write("#  pass,\ \n")
        file.write("#  t:none,\ \n")
        file.write("#  setvar:'tx.allowed_request_content_type=|application/x-www-form-urlencoded| |multipart/form-data| ")
        file.write("|multipart/related| |text/xml| |application/xml| |application/soap+xml| |application/x-amf| |application/json| ")
        file.write("|application/cloudevents+json| |application/cloudevents-batch+json| |application/octet-stream| |application/csp-report| ")
        file.write("|application/xss-auditor-report| |text/plain|'\"\n")

        





registrar.register_manager(ModsecurityConfManager())