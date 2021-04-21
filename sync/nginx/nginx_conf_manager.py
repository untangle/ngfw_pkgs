"""This class is responsible for managing the nginx configuration for WAF"""
import os
from sync import registrar, Manager

class NginxConfManager(Manager):
    """NginxConfManager manages the nginx manager settings"""
    nginx_main_conf="/etc/nginx/nginx.conf"
    nginx_default_conf="/etc/nginx/conf.d/default.conf"
    nginx_logging_conf="/etc/nginx/conf.d/logging.conf"
    modsecurity_setup_conf="/etc/modsecurity.d/setup.conf"
    untangle_modsec_rules_conf="/etc/modsecurity.d/untangle-crs-rules.conf"

    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.nginx_main_conf, "restart-nginx", self)
        registrar.register_file(self.nginx_default_conf, "restart-nginx", self)
        registrar.register_file(self.nginx_logging_conf, "restart-nginx", self)
        registrar.register_file(self.modsecurity_setup_conf, "restart-nginx", self)
        registrar.register_file(self.untangle_modsec_rules_conf, "restart-nginx", self)

    def create_settings(self, settings_file, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        server = {}
        #TODO: change how defaults are handled with new slimmed down docker?
        basic_server = {
            'sslPort': '443',
            'port': '80',
            'dnsServer': '127.0.0.11',
            'serverName': 'localhost',
            'paranoia': '1',
            'proxy': '1'
        }
        setupWizard = {
                'completed': False
        }
        upstream_backend = {
            'upstreamServers': [
            ],
            'lbMethod': "round_robin"
        }
        server_ssl = {
            'proxySslCert': '/etc/nginx/certs/server.crt',
            'proxySslCertKey': '/etc/nginx/certs/server.key',
            'proxySslVerify': 'off'
        }
        nginx_locations = {
            'proxyTimeout': '60s',
            'metricsAllowFrom': '127.0.0.0/24',
            'metricsDenyFrom': 'all',
        }
        server['basicServer'] = basic_server
        server['setupWizard'] = setupWizard
        server['upstreamBackend'] = upstream_backend
        server['serverSsl'] = server_ssl
        server['nginxLocations'] = nginx_locations
        settings_file.settings['server'] = server

    def sync_settings(self, settings_file, prefix, delete_list):
        """syncs settings"""
        self.write_nginx_conf(settings_file.settings, prefix)
        self.write_nginx_default_conf(settings_file.settings, prefix)
        self.write_nginx_logging_conf(settings_file.settings, prefix)
        self.write_modsecurity_setup_conf(settings_file.settings, prefix)
        self.write_untangle_modsec_rules(settings_file.settings, prefix)

    def write_nginx_default_conf(self, settings, prefix):
        """write the nginx default.conf file"""
        filename = prefix + self.nginx_default_conf
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.current_file = open(filename, "w+")
        file = self.current_file
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")

        file.write("\n")
        
        # If the upstream servers have not been configured yet, only create the redirect page
        if len(settings['server']['upstreamBackend']['upstreamServers']) is 0:
            self.write_untangle_default_landing(file)
        else:
            self.write_http_connection_upgrade(file, settings)
            self.write_upstream_backend(file, settings)
            self.write_basic_server_conf(file, settings)

        file.flush()
        file.close()

    def write_nginx_conf(self, settings, prefix):
        filename = prefix + self.nginx_main_conf
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.current_file = open(filename, "w+")
        file = self.current_file
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")

        file.write("\n")
        file.write("load_module modules/ngx_http_modsecurity_module.so;\n")
        file.write("load_module modules/ngx_http_sticky_module.so;\n")
        file.write("\n")
        file.write("worker_processes 1;\n")
        file.write("pid /var/run/nginx.pid;\n")
        file.write("events {\n")
        file.write("\tworker_connections 1024;\n")
        file.write("}\n")
        file.write("\n")
        file.write("http {\n")
        file.write("\tinclude /etc/nginx/mime.types;\n")
        file.write("\tdefault_type application/octet-stream;\n")
        file.write("\tkeepalive_timeout 60s;\n")
        file.write("\tsendfile on;\n")
        file.write("\n")
        file.write("\tmodsecurity on;\n")
        file.write("\tmodsecurity_rules_file /etc/modsecurity.d/setup.conf;\n")
        file.write("\tinclude /etc/nginx/conf.d/*.conf;\n")
        file.write("}\n")
        file.flush()
        file.close()

    def write_nginx_logging_conf(self, settings, prefix):
        """write the logging conf file"""
        filename = prefix + self.nginx_logging_conf
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.current_file = open(filename, "w+")
        file = self.current_file
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")

        file.write("\n")
        file.write("log_format json_combined escape=json\n")
        file.write("\t'{'\n")
        file.write("\t\t'\"remote_addr\":\"$remote_addr\",'\n")
        file.write("\t\t'\"time_local\":\"$time_local\",'\n")
        file.write("\t\t'\"request\":\"$request\",'\n")
        file.write("\t\t'\"status\":\"$status\",'\n")
        file.write("\t\t'\"body_bytes_sent\":\"$body_bytes_sent\",'\n")
        file.write("\t\t'\"request_time\":\"$request_time\",'\n")
        file.write("\t\t'\"http_referrer\":\"$http_referrer\",'\n")
        file.write("\t\t'\"http_user_agent\":\"$http_user_agent\",'\n")
        file.write("\t\t'\"remote_user\":\"$remote_user\",'\n")
        file.write("\t\t'\"http_x_forwarded_for\":\"$http_x_forwarded_for\"'\n")
        file.write("\t'}';\n")
        file.write("access_log /var/log/nginx/untangle_access.log json_combined;\n")
        file.write("\n")
        file.flush()
        file.close()

    def write_modsecurity_setup_conf(self, settings, prefix):
        """write_modsecurity_setup_conf writes out the modsecurity setup conf file"""
        filename = prefix + self.modsecurity_setup_conf
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.current_file = open(filename, "w+")
        file = self.current_file
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n")
        file.write("\n")
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
        # crs-setup.conf has the core rule set initialization conf info (also see the activate-rules.sh script)
        file.write("Include /etc/modsecurity.d/owasp-crs/crs-setup.conf\n")
        # This is the location of all the core rule set conf files
        file.write("Include %s\n" % self.untangle_modsec_rules_conf)
        file.write("\n")
        file.write("\n")
        file.flush()
        file.close()

    def write_untangle_modsec_rules(self, settings, prefix):
        """write the untangle modsec rules conf file"""
        filename = prefix + self.untangle_modsec_rules_conf
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.current_file = open(filename, "w+")
        file = self.current_file
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")

        file.write("\n")
        # Initialization is needed always
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-901-INITIALIZATION.conf\n")
        # TODO: Here is where we would add IP Allow/Block list imports, and rule exclusions
        
        
        # TODO: Add settings toggles for these generic application exclusions
        file.write("#Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-903.9001-DRUPAL-EXCLUSION-RULES.conf\n")
        file.write("#Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-903.9002-WORDPRESS-EXCLUSION-RULES.conf\n")
        file.write("#Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-903.9003-NEXTCLOUD-EXCLUSION-RULES.conf\n")
        file.write("#Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-903.9004-DOKUWIKI-EXCLUSION-RULES.conf\n")
        file.write("#Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-903.9005-CPANEL-EXCLUSION-RULES.conf\n")
        file.write("#Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-903.9006-XENFORO-EXCLUSION-RULES.conf\n")
        
        # TODO: Add settings toggles for entire rulesets
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-905-COMMON-EXCEPTIONS.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-910-IP-REPUTATION.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-911-METHOD-ENFORCEMENT.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-912-DOS-PROTECTION.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-913-SCANNER-DETECTION.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-920-PROTOCOL-ENFORCEMENT.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-921-PROTOCOL-ATTACK.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-930-APPLICATION-ATTACK-LFI.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-931-APPLICATION-ATTACK-RFI.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-932-APPLICATION-ATTACK-RCE.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-933-APPLICATION-ATTACK-PHP.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-934-APPLICATION-ATTACK-NODEJS.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-941-APPLICATION-ATTACK-XSS.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-942-APPLICATION-ATTACK-SQLI.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-943-APPLICATION-ATTACK-SESSION-FIXATION.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-944-APPLICATION-ATTACK-JAVA.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-949-BLOCKING-EVALUATION.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/RESPONSE-950-DATA-LEAKAGES.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/RESPONSE-951-DATA-LEAKAGES-SQL.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/RESPONSE-952-DATA-LEAKAGES-JAVA.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/RESPONSE-953-DATA-LEAKAGES-PHP.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/RESPONSE-954-DATA-LEAKAGES-IIS.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/RESPONSE-959-BLOCKING-EVALUATION.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/RESPONSE-980-CORRELATION.conf\n")
        file.write("\n")
        file.write("\n")
        file.flush()
        file.close()

    def write_upstream_backend(self, file, settings):
        """write the upstream backend block for nginx"""
        upstream_backend = settings['server']['upstreamBackend']
        file.write("upstream backend {\n")

        if len(upstream_backend.get('upstreamServers')) > 1 and upstream_backend['lbMethod'] is not None:
            lb = upstream_backend['lbMethod']
            if lb == 'least_connections':
                file.write("    least_conn;\n")
            elif lb == 'random':
                file.write("    random;\n")
            elif lb == 'sticky':
                file.write("    sticky;\n")
            # round robin needs no additional configuration written
            # any unknown lb method would also have nothing written out to the nginx file

        for server in upstream_backend.get('upstreamServers'):
            file.write("    server " + server.get('upstreamServerName') + ";\n")
        file.write("}\n")
        file.write("\n")

    def write_basic_server_conf(self, file, settings):
        """write the initial settings of the server block for nginx"""
        basic_server = settings['server']['basicServer']
        file.write("server {\n")
        file.write("\tlisten " + basic_server['sslPort'] + " ssl;\n")
        file.write("\tlisten " + basic_server['port'] + ";\n")
        file.write("\n")
        file.write("\tresolver " + basic_server['dnsServer'] + " valid=5s;\n")
        file.write("\tserver_name " + basic_server['serverName'] + ";\n")
        file.write("\n")

        server_ssl = settings['server']['serverSsl']
        file.write("\tssl_certificate " + server_ssl['proxySslCert'] + ";\n")
        file.write("\tssl_certificate_key " + server_ssl['proxySslCertKey'] + ";\n")
        file.write("\tssl_ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS;\n")
        file.write("\tssl_prefer_server_ciphers on;\n")
        file.write("\tssl_protocols TLSv1 TLSv1.1 TLSv1.2;\n")
        file.write("\tssl_verify_client " + server_ssl['proxySslVerify'] + ";\n")
        file.write("\n")
        nginx_locations = settings['server']['nginxLocations']
        self.write_root_loc(file, nginx_locations)
        self.write_health_loc(file, nginx_locations)
        self.write_metrics_loc(file, nginx_locations)
        self.write_error_pages(file, nginx_locations)
        file.write("}")

    def write_http_connection_upgrade(self, file, settings):
        """write_http_connection_upgrade creates the http_upgrade logic to upgrade http traffic"""
        file.write("map $http_upgrade $connection_upgrade {\n")
        file.write("\tdefault upgrade;\n")
        file.write("\t\'\' close;\n")
        file.write("\t}\n")

    def write_root_loc(self, file, nginx_loc):
        """write_root_loc writes the root location for the WAF upstream servers"""
        file.write("\tlocation / {\n")
        file.write("\t\tclient_max_body_size 0;\n")
        file.write("\t\tproxy_set_header Host $host;\n")
        file.write("\t\tproxy_set_header Proxy \"\";\n")
        file.write("\t\tproxy_set_header Upgrade $connection_upgrade;\n")
        file.write("\t\tproxy_set_header Connection $connection_upgrade;\n")
        file.write("\t\tproxy_set_header X-Real-IP $remote_addr;\n")
        file.write("\t\tproxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n")
        file.write("\t\tproxy_set_header X-Forwarded-Port $server_port;\n")
        file.write("\t\tproxy_set_header X-Forwarded-Proto $scheme;\n")
        file.write("\t\tproxy_http_version 1.1;\n")
        file.write("\t\tproxy_buffering off;\n")
        file.write("\t\tproxy_connect_timeout " + nginx_loc['proxyTimeout'] + ";\n")
        file.write("\t\tproxy_read_timeout 36000s;\n")
        file.write("\t\tproxy_redirect off;\n")
        file.write("\t\tproxy_pass_header Authorization;\n")
        file.write("\t\tproxy_pass http://backend;\n")
        file.write("\t\tindex index.html index.htm;\n")
        file.write("\t\troot /usr/share/nginx/html;\n")
        file.write("\t}\n")

    def write_health_loc(self, file, nginx_locations):  
        """write_health_loc creates the healthz endpoint for getting nginx health"""
        file.write("\tlocation /healthz {\n")
        file.write("\t\taccess_log off;\n")
        file.write("\t\tadd_header Content-Type text/plain;\n")
        file.write("\t\tclient_max_body_size 0;\n")
        file.write("\t}\n")

    def write_metrics_loc(self, file, nginx_locations):
        """write_metrics_loc creates the metrics location for getting nginx metrics"""
        file.write("\tlocation /metrics/nginx {\n")
        file.write("\t\tallow " + nginx_locations['metricsAllowFrom'] + ";\n")
        file.write("\t\tdeny " + nginx_locations['metricsDenyFrom'] + ";\n")
        file.write("\t\tproxy_store off;\n")
        file.write("\t\tstub_status;\n")
        file.write("\t}\n")

    def write_error_pages(self, file, nginx_locations):
        """write_error_pages creates the http status code response pages"""
        file.write("\terror_page 500 502 503 504  /50x.html;\n")
        file.write("\tlocation = /50x.html {\n")
        file.write("\t\troot /usr/share/nginx/html;\n")
        file.write("\t}\n")

    def write_untangle_default_landing(self, file):
        """write_untangle_default_landing creates a URI rewrite that redirects all requests to /app/setup, and creates a root location that points to the app/index.html"""
        file.write("server {\n")
        file.write("\tlisten 80;\n")
        file.write("\tlocation / {\n")
        file.write("\t\trewrite ^ http://$host/app/setup redirect;\n")
        file.write("\t}\n")
        file.write("\tlocation /app {\n")
        file.write("\t\tproxy_pass http://$host:8585;\n")
        file.write("\t}\n")
        file.write("\tlocation /api {\n")
        file.write("\t\tproxy_pass http://$host:8585;\n")
        file.write("\t}\n")
        file.write("}\n")

registrar.register_manager(NginxConfManager())