"""This class is responsible for managing the modsecurity config for WAF"""
import os
from sync import registrar, Manager

class ModsecurityConfManager(Manager):
    untangle_crs_setup_conf = "/etc/modsecurity.d/owasp-crs/untangle-crs-setup.conf"
    modsecurity_setup_conf="/etc/modsecurity.d/setup.conf"
    
    # registered and synced elsewhere
    untangle_modsec_rules_conf="/etc/modsecurity.d/untangle-modsec-rules.conf"
    untangle_modsec_crs_rules_conf="/etc/modsecurity.d/untangle-crs-rules.conf"
    
    def initialize(self):
        """Initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.untangle_crs_setup_conf, "restart-nginx", self)
        registrar.register_file(self.modsecurity_setup_conf, "restart-nginx", self)

    def create_settings(self, settings_file, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)

        settings_file.settings['globalModsec'] = self.default_global_settings()

    def default_global_settings(self):
        """generates the default global settings"""
        global_settings = {
            'enabledExclusions': [],
            'allowedHttpMethods': ['GET', 'HEAD', 'POST', 'OPTIONS', 'PUT', 'PATCH', 'DELETE'],
            'geoIP': {
                'enabled': True,
                'database': '/usr/share/untangle/waf/database/GeoLite2-Country.mmdb'
            },
            'blockCountries': [],
            'dosProtection': {
                'enabled': False,
                'burstTime': 60,
                'counterThreshold': 100,
                'blockTimeout': 600
            }
        }

        return global_settings

    def sanitize_settings(self, settings_file):
        """sanitizes settings for modsecurity conf"""
        print("%s: Sanitizing settings" % self.__class__.__name__)

        if 'globalModsec' not in settings_file.settings:
            settings_file.settings['globalModsec'] = self.default_global_settings()

    def sync_settings(self, settings_file, prefix, delete_list):
        """sync the settings"""
        print("%s: Syncing settings" % self.__class__.__name__)
        self.write_untangle_crs_setup_conf(settings_file.settings, prefix)
        self.write_modsecurity_setup_conf(settings_file.settings, prefix)

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

        self.write_modsecurity_crs_basics(file)
        self.write_modsecurity_crs_anomaly_items(file)
        self.write_modsecurity_crs_exclusions(file, settings)
        self.write_modsecurity_crs_http_policy_settings(file, settings)
        self.write_modsecurity_crs_http_limits(file)
        self.write_modsecurity_crs_advanced_options(file, settings)
        self.write_modsecurity_crs_end_options(file)

        file.flush()
        file.close()

    def write_modsecurity_crs_basics(self, file):
        """Write out the mode of operation and paranoia level"""
        # mode of operation
        file.write("\n\n")
        file.write("# [[ Mode of Operation ]] \n")
        file.write("# Mode that the CRS will run in. At least one mode must be selected. \n")
        file.write("# Default is anomaly scoring mode logging to modsecurity audit and error logs\n")
        file.write("SecDefaultAction \"phase:1,log,auditlog,pass\"\n")
        file.write("SecDefaultAction \"phase:2,log,auditlog,pass\"\n")

        # paranoia level initialization
        file.write("\n\n")
        file.write("# [[ Paranoia Level Initialization ]] \n")
        file.write("# Allows you to choose the desired level of rule checks that will add to your security scores\n")
        file.write("# Using defaults of 1, so rule is commented\n") # comment could change if we uncomment rule
        file.write("SecAction \\\n")
        file.write(" \"id:900000, \\\n")
        file.write("  phase:1, \\\n")
        file.write("  nolog, \\\n")
        file.write("  pass, \\\n")
        file.write("  t:none, \\\n")
        file.write("  setvar:tx.paranoia_level=1\"\n")
        file.write("\n")
        file.write("# Executing paranoia level - add rules from higher paranoia levels\n")
        file.write("# Default is 1\n") # comment could change if we uncomment rule
        file.write("#SecAction \\\n")
        file.write("# \"id:900001, \\\n")
        file.write("#  phase:1, \\\n")
        file.write("#  nolog, \\\n")
        file.write("#  pass, \\\n")
        file.write("#  t:none, \\\n")
        file.write("#  setvar:tx.executing_paranoia_level=1\"\n")

        # enforce body processor encoded
        file.write("\n\n")
        file.write("# [[ Enforce Body Processor URLENCODED ]] \n")
        file.write("# When on, forces the URLENCODED body processor when modsecurity can't determine body processor \n")
        file.write("# from Content-Type request header of client. \n")
        file.write("# Default is off, so rule is commented as the uncommented rule would turn it on. \n") # comment could change if we uncomment rule
        file.write("#SecAction \\\n")
        file.write("# \"id:900010, \\\n")
        file.write("#  phase:1, \\\n")
        file.write("#  nolog, \\\n")
        file.write("#  pass, \\\n")
        file.write("#  t:none, \\\n")
        file.write("#  setvar:tx.enforce_bodyproc_urlencoded=1\"\n")

    def write_modsecurity_crs_anomaly_items(self, file):
        """Write out anomaly items in the crs conf file"""
        # anomaly scoring mode severity levels
        file.write("\n\n")
        file.write("# [[ Anomaly Scoring Mode Severity Levels ]] \n")
        file.write("# Default scoring points for each severity level. \n")
        file.write("# These settings will be used to increment the anomaly score if a rule matches. \n")
        file.write("# Adjustment usually not needed\n")
        file.write("# Using default values, so rule is commented. \n") # comment could change if we uncomment rule
        file.write("#SecAction \\\n")
        file.write("# \"id:900100, \\\n")
        file.write("#  phase:1, \\\n")
        file.write("#  nolog, \\\n")
        file.write("#  pass, \\\n")
        file.write("#  t:none, \\\n")
        file.write("#  setvar:tx.critical_anomaly_score=5, \\\n")
        file.write("#  setvar:tx.error_anomaly_score=4, \\\n")
        file.write("#  setvar:tx.warning_anomaly_score=3, \\\n")
        file.write("#  setvar:tx.notice_anomaly_score=2\"\n")

        # anomaly scoring mode blocking threshold levels
        file.write("\n\n")
        file.write("# [[ Anomaly Scoring Mode Blocking Threshold Levels ]] \n")
        file.write("# Here, you can specify at which cumulative anomaly score an inbound request,\n")
        file.write("# or outbound response, gets blocked.\n")
        file.write("# At default value, a single critical rule match will cause the request to be blocked.\n")
        file.write("# Using default values. \n") # comment could change if we uncomment rule
        file.write("SecAction \\\n")
        file.write(" \"id:900110, \\\n")
        file.write("  phase:1, \\\n")
        file.write("  nolog, \\\n")
        file.write("  pass, \\\n")
        file.write("  t:none, \\\n")
        file.write("  setvar:tx.inbound_anomaly_score_threshold=5, \\\n")
        file.write("  setvar:tx.outbound_anomaly_score_threshold=4\"\n")

        # early anomaly scoring mode blocking
        file.write("\n\n")
        file.write("# [[ Early Anomaly Scoring Mode Blocking ]] \n")
        file.write("# Enable early evaluation of anomaly scores at end of phase:1 and phase:3. \n")
        file.write("# Evaluation usually occurs at the end of phase:2 and phase:4. \n")
        file.write("# Default is off, so rule is commented. \n") # comment could change if we uncomment rule
        file.write("#SecAction \\\n")
        file.write("# \"id:900120, \\\n")
        file.write("#  phase:1, \\\n")
        file.write("#  nolog, \\\n")
        file.write("#  pass, \\\n")
        file.write("#  t:none, \\\n")
        file.write("#  setvar:tx.blocking_early=1\"\n")

    def write_modsecurity_crs_exclusions(self, file, settings):
        """Write exclusions items out to crs setup"""
        # app specific rule exclusions 
        file.write("\n\n")
        file.write("# [[ Application Specific Rule Exclusions ]] \n")
        file.write("# Some well-known applications may undertake actions that appear to be malicious. \n")
        file.write("# In such cases the CRS aims to prevent false positives by allowing prebuilt, application \n")
        file.write("# specific exclusions on an application by application basis. \n")

        comment = "By default, no exclusions apply, so rule is commented."
        prepend = "#"
        enabledExclusionsList = settings['globalModsec']['enabledExclusions']
        lastItem = "\"\n"
        between = ", \\\n"
        exclusions = []
        if len(enabledExclusionsList) != 0:
            comment = "Enabled exclusions are: " + ",".join(enabledExclusionsList)
            prepend = ""
            if 'Drupal' in enabledExclusionsList:
                exclusions.append("  setvar:tx.crs_exclusions_drupal=1")
            if 'Wordpress' in enabledExclusionsList:
                exclusions.append("  setvar:tx.crs_exclusions_wordpress=1") 
            if 'Nextcloud' in enabledExclusionsList:
                exclusions.append("  setvar:tx.crs_exclusions_nextcloud=1")
            if 'Dokuwiki' in enabledExclusionsList:
                exclusions.append("  setvar:tx.crs_exclusions_dokuwiki=1")
            if 'Cpanel' in enabledExclusionsList:
                exclusions.append("  setvar:tx.crs_exclusions_cpanel=1")
            if 'Xenforo' in enabledExclusionsList:
                exclusions.append("  setvar:tx.crs_exclusions_xenforo=1")
            if 'Phpbb' in enabledExclusionsList:
                exclusions.append("  setvar:tx.crs_exclusions_phpbb=1")
            if 'Phpmyadmin' in enabledExclusionsList:
                exclusions.append("  setvar:tx.crs_exclusions_phpmyadmin=1")
        file.write("# " + comment+  "\n") 
        file.write(prepend + "SecAction \\\n")
        file.write(prepend + " \"id:900130, \\\n")
        file.write(prepend + "  phase:1, \\\n")
        file.write(prepend + "  nolog, \\\n")
        file.write(prepend + "  pass, \\\n")
        file.write(prepend + "  t:none, \\\n")
        file.write(between.join(exclusions))
        file.write(prepend + lastItem)

    def write_modsecurity_crs_http_policy_settings(self, file, settings):
        """Write modsecurity crs configuration items for HTTP policy settings"""
        # HTTP policy settings - methods
        # UNTANGLE CHANGED NORMAL DEFAULTS
        file.write("\n\n")
        file.write("# [[ HTTP Policy Settings - HTTP Methods ]] \n")
        file.write("# HTTP methods that a client is allowed to use \n")
        comment = "# Using defaults, so rule is uncommented.\n"
        default = "GET HEAD POST OPTIONS"
        prepend = "#"
        methods = " ".join(settings['globalModsec']['allowedHttpMethods'])
        if methods != default:
            comment = "# Allowed HTTP methods: " + methods + ".\n"
            prepend = ""
        file.write(comment)
        file.write(prepend + "SecAction \\\n")
        file.write(prepend + " \"id:900200, \\\n")
        file.write(prepend + "  phase:1, \\\n")
        file.write(prepend + "  nolog, \\\n")
        file.write(prepend + "  pass, \\\n")
        file.write(prepend + "  t:none, \\\n")
        file.write(prepend + "  setvar:'tx.allowed_methods=" + methods + "'\"\n")

        # HTTP Policy Settings - Content-Types
        file.write("\n\n")
        file.write("# [[ HTTP Policy Settings - Content-Types ]] \n")
        file.write("# Allowed Content-Types header from clients \n")
        file.write("# Using defaults, so rule is commented. \n") # comment could change if rule changes
        file.write("#SecAction \\\n")
        file.write("# \"id:900220, \\\n")
        file.write("#  phase:1, \\\n")
        file.write("#  nolog, \\\n")
        file.write("#  pass, \\\n")
        file.write("#  t:none, \\\n")
        file.write("#  setvar:'tx.allowed_request_content_type=|application/x-www-form-urlencoded| |multipart/form-data| ")
        file.write("|multipart/related| |text/xml| |application/xml| |application/soap+xml| |application/x-amf| |application/json| ")
        file.write("|application/cloudevents+json| |application/cloudevents-batch+json| |application/octet-stream| |application/csp-report| ")
        file.write("|application/xss-auditor-report| |text/plain|'\"\n")

        # HTTP POlicy settings - HTTP versions
        file.write("\n\n")
        file.write("# [[ HTTP Policy Settings - Allowed HTTP Versions ]] \n")
        file.write("# Using defaults, so rule is commented.\n") # comment could change if rule changes
        file.write("#SecAction \\\n")
        file.write("# \"id:900230, \\\n")
        file.write("#  phase:1, \\\n")
        file.write("#  nolog, \\\n")
        file.write("#  pass, \\\n")
        file.write("#  t:none, \\\n")
        file.write("#  setvar:'tx.allowed_http_versions=HTTP/1.0 HTTP/1.1 HTTP/2 HTTP/2.0'\"\n")

        #HTTP Policy settings - forbidden file extensions
        file.write("\n\n")
        file.write("# [[ HTTP Policy Settings - Forbidden File Extensions ]] \n")
        file.write("# Guards against unintended exposure of development/configuration files.\n")
        file.write("# Using defaults, so rule is commented. \n") # comment could change if rule changes
        file.write("#SecAction \\\n")
        file.write("# \"id:900240, \\\n")
        file.write("#  phase:1, \\\n")
        file.write("#  nolog, \\\n")
        file.write("#  pass, \\\n")
        file.write("#  t:none, \\\n")
        file.write("#  setvar:'tx.restricted_extensions=.asa/ .asax/ .ascx/ .axd/ .backup/ .bak/ .bat/ .cdx/ .cer/ .cfg/ ")
        file.write(".cmd/ .com/ .config/ .conf/ .cs/ .csproj/ .csr/ .dat/ .db/ .dbf/ .dll/ .dos/ .htr/ .htw/ .ida/ .idc/ ")
        file.write(".idq/ .inc/ .ini/ .key/ .licx/ .lnk/ .log/ .mdb/ .old/ .pass/ .pdb/ .pol/ .printer/ .pwd/ .rdb/ .resources/ ")
        file.write(".resx/ .sql/ .swp/ .sys/ .vb/ .vbs/ .vbproj/ .vsdisco/ .webinfo/ .xsd/ .xsx/'\"\n")

        #HTTP Policy Settings - file extensions 
        file.write("\n\n")
        file.write("# [[ HTTP Policy Settings - File Extensions ]] \n")
        file.write("# These are file extensions considered static files for DoS protection\n")
        file.write("# Using defaults, so rule is commented. \n") # comment could change if rule changes
        file.write("#SecAction \\\n")
        file.write("# \"id:900260, \\\n")
        file.write("#  phase:1, \\\n")
        file.write("#  nolog, \\\n")
        file.write("#  pass, \\\n")
        file.write("#  t:none, \\\n")
        file.write("#  setvar:'tx.static_extensions=/.jpg/ /.jpeg/ /.png/ /.gif/ /.js/ /.css/ /.ico/ /.svg/ /.webp/'\"\n")

        # HTTP Policy Settings - Content-Types charsets 
        file.write("\n\n")
        file.write("# [[ HTTP Policy Settings - Content-Types charsets ]] \n")
        file.write("# Content-Types charsets that a client is allowed to send in a request.\n")
        file.write("# Using defaults, so rule is commented. \n") # comment could change if rule changes
        file.write("#SecAction \\\n")
        file.write("# \"id:900280, \\\n")
        file.write("#  phase:1, \\\n")
        file.write("#  nolog, \\\n")
        file.write("#  pass, \\\n")
        file.write("#  t:none, \\\n")
        file.write("#  setvar:'tx.allowed_request_content_type_charset=|utf-8| |iso-8859-1| |iso-8859-15| |windows-1252|'\"\n")

    def write_modsecurity_crs_http_limits(self, file):
        """Write modsecurity crs http policy argument/upload limits items"""
        #HTTP Policy Argument/Upload Limits - Block request if number of args is too high
        file.write("\n\n")
        file.write("# [[ HTTP Policy Argument/Upload Limits - Block request if number of args is too high ]] \n")
        file.write("# Using default of unlimited, so rule is commented. \n") # comment could change if rule changes
        file.write("#SecAction \\\n")
        file.write("# \"id:900300, \\\n")
        file.write("#  phase:1, \\\n")
        file.write("#  nolog, \\\n")
        file.write("#  pass, \\\n")
        file.write("#  t:none, \\\n")
        file.write("#  setvar:tx.max_num_args=255\"\n")

        #HTTP Policy Argument/Upload Limits - block request if the length of any argument name is too high
        file.write("\n\n")
        file.write("# [[ HTTP Policy Argument/Upload Limits - block request if the length of any argument name is too high ]] \n")
        file.write("# Using default of unlimited, so rule is commented. \n") # comment could change if rule changes
        file.write("#SecAction \\\n")
        file.write("# \"id:900310, \\\n")
        file.write("#  phase:1, \\\n")
        file.write("#  nolog, \\\n")
        file.write("#  pass, \\\n")
        file.write("#  t:none, \\\n")
        file.write("#  setvar:tx.arg_name_length=255\"\n")

        #HTTP Policy Argument/Upload Limits - block request if length of any argument length is too high
        file.write("\n\n")
        file.write("# [[ HTTP Policy Argument/Upload Limits - block request if length of any argument length is too high ]] \n")
        file.write("# Using default of unlimited, so rule is commented. \n") # comment could change if rule changes
        file.write("#SecAction \\\n")
        file.write("# \"id:900320, \\\n")
        file.write("#  phase:1, \\\n")
        file.write("#  nolog, \\\n")
        file.write("#  pass, \\\n")
        file.write("#  t:none, \\\n")
        file.write("#  setvar:tx.arg_length=255\"\n")

        #HTTP Policy Argument/Upload Limits - block request if total length of all combined arguments is too high
        file.write("\n\n")
        file.write("# [[ HTTP Policy Argument/Upload Limits - block request if total length of all combined arguments is too high ]] \n")
        file.write("# Using default of unlimited, so rule is commented. \n") # comment could change if rule changes
        file.write("#SecAction \\\n")
        file.write("# \"id:900330, \\\n")
        file.write("#  phase:1, \\\n")
        file.write("#  nolog, \\\n")
        file.write("#  pass, \\\n")
        file.write("#  t:none, \\\n")
        file.write("#  setvar:tx.total_arg_length=255\"\n")

        #HTTP Policy Argument/Upload Limits - Block request if file size of any individual uploaded file is too high
        file.write("\n\n")
        file.write("# [[ HTTP Policy Argument/Upload Limits - Block request if file size of any individual uploaded file is too high ]] \n")
        file.write("# Using default of unlimited, so rule is commented. \n") # comment could change if rule changes
        file.write("#SecAction \\\n")
        file.write("# \"id:900340, \\\n")
        file.write("#  phase:1, \\\n")
        file.write("#  nolog, \\\n")
        file.write("#  pass, \\\n")
        file.write("#  t:none, \\\n")
        file.write("#  setvar:tx.max_file_size=255\"\n")

        #HTTP Policy Argument/Upload Limits - Block request if the total size of all combined uploaded files is too high
        file.write("\n\n")
        file.write("# [[ HTTP Policy Argument/Upload Limits - Block request if the total size of all combined uploaded files is too high ]] \n")
        file.write("# Using default of unlimited, so rule is commented. \n") # comment could change if rule changes
        file.write("#SecAction \\\n")
        file.write("# \"id:900350, \\\n")
        file.write("#  phase:1, \\\n")
        file.write("#  nolog, \\\n")
        file.write("#  pass, \\\n")
        file.write("#  t:none, \\\n")
        file.write("#  setvar:tx.combined_file_sizes=255\"\n")

    def write_modsecurity_crs_advanced_options(self, file, settings):
        """Write out modsecurity crs advanced options"""
        #Easing in/sampling percentage
        file.write("\n\n")
        file.write("# [[ Easing In / Sampling Percentage ]] \n")
        file.write("# Enable CRS for a lmited number of requests. Shown as a percentage of requests\n")
        file.write("# Default is all requests are processed.\n")
        file.write("# Using default of no restriction, so rule is commented. \n") # comment could change if rule changes)
        file.write("#SecAction \\\n") 
        file.write("# \"id:900400, \\\n")
        file.write("#  phase:1, \\\n")
        file.write("#  pass, \\\n")
        file.write("#  nolog, \\\n")
        file.write("#  setvar:tx.sampling_percentage=100\"\n")

        # Project honey port 
        file.write("\n\n")
        file.write("# [[ Project Honey Pot ]] \n")
        file.write("# Optionally, you can check the client IP address against the Project Honey Pot HTTPBL (dnsbl.httpbl.org).\n")
        file.write("# Using default of disabled, so rule and API key is commented \n") # comment could change if rule changes
        file.write("#SecHttpBlKey XXXXXXXXXXXXXXXXX\n")
        file.write("#SecAction \\\n")
        file.write("# \"id:900500, \\\n")
        file.write("#  phase:1, \\\n")
        file.write("#  nolog, \\\n")
        file.write("#  pass, \\\n")
        file.write("#  t:none, \\\n")
        file.write("#  setvar:tx.block_search_ip=1, \\\n")
        file.write("#  setvar:tx.block_suspicious_ip=1, \\\n")
        file.write("#  setvar:tx.block_harvester_ip=1, \\\n")
        file.write("#  setvar:tx.block_spammer_ip=1\"\n")

        #geoip
        file.write("\n\n")
        file.write("# [[ GeoIP Database ]] \n")
        file.write("# There are some rulesets that inspect geolocation data of the client IP address (geoLookup). The CRS uses geoLookup to implement optional country blocking. \n")
        file.write("# Make sure you download the database!\n")
        comment = "# Using default of disabled, so rule is commented.\n"
        prepend = "#"
        if settings['globalModsec']['geoIP']['enabled']:
            comment = "# GeoIP Database enabled.\n"
            prepend = ""
        file.write(comment)
        file.write(prepend + "SecGeoLookupDB " + settings['globalModsec']['geoIP']['database'] + "\n")

        #block countries
        file.write("\n\n")
        file.write("# [[ Block Countries ]] \n")
        file.write("# Rules in the IP Reputation file can check the client against a list of high risk country codes. \n")
        file.write("# This rule requires SecGeoLookupDB to be enabled and the GeoIP database to be downloaded. \n")
        comment = "# Using default of disabled, so rule is commented.\n"
        prepend = "#"
        countries = settings['globalModsec']['blockCountries']
        countries_str = ""
        if len(countries) > 0:
            countries_str = " ".join(countries)
            comment = "# Blocking country codes: " + countries_str + "\n"
            prepend = ""
        file.write(comment)
        file.write(prepend + "SecAction \\\n")
        file.write(prepend + " \"id:900600, \\\n")
        file.write(prepend + "  phase:1, \\\n")
        file.write(prepend + "  nolog, \\\n")
        file.write(prepend + "  pass, \\\n")
        file.write(prepend + "  t:none, \\\n")
        file.write(prepend + "  setvar:'tx.high_risk_country_codes=" + countries_str + "'\"\n")

        # Anti Automation / DoS Protection
        file.write("\n\n")
        file.write("# [[ Anti Automation / DoS Protection ]] \n")
        file.write("# Optional DoS protection against clients making requests too quickly. \n")
        file.write("# When a client is making more than " + str(settings['globalModsec']['dosProtection']['counterThreshold']) + " requests (excluding static files) ") 
        file.write("within " + str(settings['globalModsec']['dosProtection']['burstTime']) + " seconds, this is considered a 'burst'.\n")
        file.write("# After two bursts, the client is blocked for " + str(settings['globalModsec']['dosProtection']['blockTimeout']) + " seconds.\n")
        comment = "# Using default of disabled, so rule is commented. \n"
        prepend = "#"
        if settings['globalModsec']['dosProtection']['enabled']:
            prepend = ""
            comment = "# DOS Protection enabled with values described above. \n"
        file.write(comment) 
        file.write(prepend + "SecAction \\\n")
        file.write(prepend + " \"id:900700, \\\n")
        file.write(prepend + "  phase:1, \\\n")
        file.write(prepend + "  nolog, \\\n")
        file.write(prepend + "  pass, \\\n")
        file.write(prepend + "  t:none, \\\n")
        file.write(prepend + "  setvar:'tx.dos_burst_time_slice=" + str(settings['globalModsec']['dosProtection']['burstTime']) + "', \\\n")
        file.write(prepend + "  setvar:'tx.dos_counter_threshold=" + str(settings['globalModsec']['dosProtection']['counterThreshold']) + "', \\\n")
        file.write(prepend + "  setvar:'tx.dos_block_timeout=" + str(settings['globalModsec']['dosProtection']['blockTimeout']) + "'\"\n")

        # Check UTF-8 Encoding
        file.write("\n\n")
        file.write("# [[ Check UTF-8 Encoding ]] \n")
        file.write("# The CRS can optionally check request contents for invalid UTF-8 encoding. \n")
        file.write("# Using default of disabled, so rule is commented. \n") # comment could change if rule changes
        file.write("#SecAction \\\n")
        file.write("# \"id:900950, \\\n")
        file.write("#  phase:1, \\\n")
        file.write("#  nolog, \\\n")
        file.write("#  pass, \\\n")
        file.write("#  t:none, \\\n")
        file.write("#  setvar:tx.crs_validate_utf8_encoding=1\"\n")

        # Blocking based on IP reputation
        file.write("\n\n")
        file.write("# [[ Blocking based on IP reputation ]] \n")
        file.write("# Using default of disabled and blocking time at 5 minutes, so rules are commented. \n") # comment could change if rule changes
        file.write("#SecAction \\\n")
        file.write("# \"id:900960, \\\n")
        file.write("#  phase:1, \\\n")
        file.write("#  nolog, \\\n")
        file.write("#  pass, \\\n")
        file.write("#  t:none, \\\n")
        file.write("#  setvar:tx.do_reput_block=1\"\n")
        file.write("## Uncomment this rule to change the blocking time:\n")
        file.write("#SecAction \\\n")
        file.write("# \"id:900970, \\\n")
        file.write("#  phase:1, \\\n")
        file.write("#  nolog, \\\n")
        file.write("#  pass, \\\n")
        file.write("#  t:none, \\\n")
        file.write("#  setvar:tx.reput_block_duration=300\"\n")

    def write_modsecurity_crs_end_options(self, file):
        """Write out end of modsecurity crs setup file"""
        # Collection timeout
        file.write("\n\n")
        file.write("# [[ Collection timeout ]] \n")
        file.write("# Set the SecCollectionTimeout directive from the ModSecurity default (1 hour) to a lower setting.\n") # comment could change if rule changes
        file.write("# Using non-default of 10 minutes, so rule is uncommented.\n") 
        file.write("SecCollectionTimeout 600")

        # End of setup
        file.write("\n\n")
        file.write("# [[ End of Setup ]] \n")
        file.write("# Do not change below\n")
        file.write("SecAction \\\n")
        file.write(" \"id:900990, \\\n")
        file.write("  phase:1, \\\n")
        file.write("  nolog, \\\n")
        file.write("  pass, \\\n")
        file.write("  t:none, \\\n")
        file.write("  setvar:tx.crs_setup_version=330\"\n")

    def write_modsecurity_setup_conf(self, settings, prefix):
        """write_modsecurity_setup_conf writes out the modsecurity setup conf file"""
        filename = prefix + self.modsecurity_setup_conf
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.current_file = open(filename, "w+")
        file = self.current_file
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n\n\n")
        # Load the modsecurity.conf default file
        file.write("Include /etc/modsecurity.d/modsecurity.conf\n")
        # Override the modsecurity.conf properties
        file.write("SecRuleEngine on\n")
        file.write("SecRequestBodyAccess on\n")
        file.write("\n")
        file.write("SecRequestBodyLimit 13107200\n")
        file.write("SecRequestBodyNoFilesLimit 131072\n")
        file.write("SecRequestBodyLimitAction Reject\n")
        file.write("\n")
        file.write("SecPcreMatchLimit 100000\n")
        file.write("SecPcreMatchLimitRecursion 100000\n")
        file.write("\n")
        file.write("SecResponseBodyAccess on\n")
        file.write("SecResponseBodyMimeType text/plain text/html text/xml\n")
        file.write("SecResponseBodyLimit 1048576\n")
        file.write("SecResponseBodyLimitAction ProcessPartial\n")
        file.write("SecTmpDir /tmp/\n")
        file.write("SecDataDir /tmp/\n")
        file.write("\n")
        file.write("SecAuditEngine RelevantOnly\n")
        file.write("SecAuditLog /var/log/untangle_modsec_audit.log\n")
        file.write("SecAuditLogFormat json\n")
        file.write("SecAuditLogParts ABIJDEFHKZ\n")
        file.write("SecAuditLogRelevantStatus \"^(?:5|4(?!04))\"\n")
        file.write("SecAuditLogType Serial\n")
        file.write("SecAuditLogStorageDir /var/log/modsecurity/audit\n")
        file.write("\n")
        file.write("SecArgumentSeparator &\n")
        file.write("SecCookieFormat 0\n")
        file.write("SecUnicodeMapFile unicode.mapping 20127\n")
        file.write("SecStatusEngine On\n")
        file.write("\n")
        # untangle-crs-setup.conf has the core rule set initialization conf info (also see the activate-rules.sh script)
        file.write("Include %s\n" % self.untangle_crs_setup_conf)
        # This is the location of all the core rule set conf files
        file.write("Include %s\n" % self.untangle_modsec_crs_rules_conf)
        # This is the location of custom untangle rules
        file.write("Include %s\n" % self.untangle_modsec_rules_conf)
        file.write("\n")
        file.write("\n")
        file.flush()
        file.close()

registrar.register_manager(ModsecurityConfManager())