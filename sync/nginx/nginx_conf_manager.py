"""This class is responsible for managing the nginx configuration for WAF"""
import os
import uuid
from sync import registrar, Manager

class NginxConfManager(Manager):
    """NginxConfManager manages the nginx manager settings"""
    nginx_main_conf="/etc/nginx/nginx.conf"
    nginx_default_conf="/etc/nginx/conf.d/default.conf"
    nginx_logging_conf="/etc/nginx/conf.d/logging.conf"

    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.nginx_main_conf, "restart-nginx", self)
        registrar.register_file(self.nginx_default_conf, "restart-nginx", self)
        registrar.register_file(self.nginx_logging_conf, "restart-nginx", self)

    def create_settings(self, settings_file, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        settings_file.settings['server'] = self.default_server_settings(settings_file.settings['server'] if 'server' in settings_file.settings else None)

    def default_server_settings(self, server_settings):
        """generates the default server settings"""

        if server_settings == None:
            server_settings = {}

        if 'basicServer' not in server_settings:
            basic_server = {
                'sslPort': '443',
                'port': '80',
                'dnsServer': '127.0.0.11',
                'serverName': 'localhost',
                'paranoia': '1',
                'proxy': '1'
            }
            server_settings['basicServer'] = basic_server

        if 'setupWizard' not in server_settings:
            setupWizard = {
                    'completed': False
            }
            server_settings['setupWizard'] = setupWizard

        if 'upstreamBackend' not in server_settings:
            upstream_backend = {
                'upstreamServers': [],
                'lbMethod': "sticky",
                'listenerPorts': [
                    {
                        'listenerID': str(uuid.uuid4()),
                        'listenerPort': '80',
                        'upstreamPort': '80',
                        'listenerProtocol': 'http',
                        'upstreamProtocol': 'http'
                    },
                    {
                        'listenerID': str(uuid.uuid4()),
                        'listenerPort': '443',
                        'upstreamPort': '443',
                        'listenerProtocol': 'https',
                        'upstreamProtocol': 'https'
                    }
                ]
            }
            server_settings['upstreamBackend'] = upstream_backend

        if 'serverSsl' not in server_settings:
            server_ssl = {
                'proxySslCert': '/etc/nginx/certs/server.crt',
                'proxySslCertKey': '/etc/nginx/certs/server.key',
                'proxySslVerify': 'off',
                'enabled': False,
            }
            server_settings['serverSsl'] = server_ssl

        if 'nginxLocations' not in server_settings:
            nginx_locations = {
                'metricsAllowFrom': '127.0.0.0/24',
                'metricsDenyFrom': 'all',
            }
            server_settings['nginxLocations'] = nginx_locations

        if 'advancedOptions' not in server_settings:
            advancedOptions = {
                'clientMaxBodySize': {'name': 'client_max_body_size', 'value': '10', 'units': 'MB' }, #used in modsecurity also
                'clientTimeout': {'name': 'client_timeout', 'value': '60', 'units': 'seconds' }
            }
            server_settings['advancedOptions'] = advancedOptions
        
        return server_settings

    def sanitize_settings(self, settings_file):
        """sanitizes settings for nginx conf"""
        print("%s: Sanitizing settings" % self.__class__.__name__)
        settings_file.settings['server'] = self.default_server_settings(settings_file.settings['server'] if 'server' in settings_file.settings else None)

    def sync_settings(self, settings_file, prefix, delete_list):
        """syncs settings"""
        self.write_nginx_conf(settings_file.settings, prefix)
        self.write_nginx_default_conf(settings_file.settings, prefix)
        self.write_nginx_logging_conf(settings_file.settings, prefix)

    def write_nginx_default_conf(self, settings, prefix):
        """write the nginx default.conf file"""
        filename = prefix + self.nginx_default_conf
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.current_file = open(filename, "w+")
        file = self.current_file
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n\n\n")
        
        # If the upstream servers have not been configured yet, only create the redirect page
        if len(settings['server']['upstreamBackend']['upstreamServers']) is 0:
            self.write_untangle_default_landing(file)
        else:
            self.write_http_connection_upgrade(file, settings)
            # for each listener, write out upstream and backend
            for listener in settings['server']['upstreamBackend']['listenerPorts']:
                self.write_upstream_backend(file, settings, listener)
                self.write_basic_server_conf(file, settings, listener)

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
        file.write("## DO NOT EDIT. Changes will be overwritten.\n\n\n")

        file.write("load_module modules/ngx_http_modsecurity_module.so;\n")
        file.write("load_module modules/ngx_http_sticky_module.so;\n")
        file.write("load_module modules/ngx_http_geoip2_module.so;\n")
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
        file.write("\tclient_max_body_size %sM;\n" % settings['server']['advancedOptions']['clientMaxBodySize']['value'])
        file.write("\n")
        file.write("\tmodsecurity on;\n")
        file.write("\tmodsecurity_rules_file /etc/modsecurity.d/setup.conf;\n")
        file.write("\tinclude /etc/nginx/conf.d/*.conf;\n")
        file.write("\tgeoip2 /usr/share/untangle/waf/database/GeoLite2-Country.mmdb {\n")
        file.write("\t\t$geoip2_data_country_code default=XU country iso_code;\n")
        file.write("\t}\n")
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
        file.write("## DO NOT EDIT. Changes will be overwritten.\n\n\n")

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
        file.write("\t\t'\"geoip2_data_country_code\":\"$geoip2_data_country_code\",'\n")
        file.write("\t\t'\"http_x_forwarded_for\":\"$http_x_forwarded_for\",'\n")
        file.write("\t\t'\"proxy_port\":\"$proxy_port\"'\n")
        file.write("\t'}';\n")
        file.write("access_log /var/log/nginx/untangle_access.log json_combined;\n")
        file.write("\n")
        file.flush()
        file.close()

    def write_upstream_backend(self, file, settings, listener):
        """write the upstream backend block for nginx"""
        upstream_backend = settings['server']['upstreamBackend']
        file.write("\nupstream backend_"  + listener['listenerID'] + " {\n")

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

        for server in upstream_backend['upstreamServers']:
            file.write(f"\tserver {server['upstreamServerName']}:{listener['upstreamPort']};\n")

        file.write("}\n")
        file.write("\n")

    def write_basic_server_conf(self, file, settings, listener):
        """write the settings of the server block for a listener"""
        
        # open server block
        file.write("\nserver {\n")

        # if https, write out ssl port listeners and ssl settings
        if listener['listenerProtocol'] == 'https':
            file.write(f"\tlisten [::]:{listener['listenerPort']} ssl;\n") 
            file.write(f"\tlisten {listener['listenerPort']} ssl;\n") 
            self.write_ssl_settings(file, settings, listener)

        # if http, write out http port listeners
        elif listener['listenerProtocol'] == 'http':
            file.write(f"\tlisten [::]:{listener['listenerPort']};\n") 
            file.write(f"\tlisten {listener['listenerPort']};\n")

        file.write("\n")

        # write out generic server info
        basic_server = settings['server']['basicServer']
        file.write("\tresolver " + basic_server['dnsServer'] + " valid=5s;\n")
        file.write("\tserver_name " + basic_server['serverName'] + ";\n\n")

        # write root, health, metrics and error locations
        nginx_locations = settings['server']['nginxLocations']
        self.write_root_loc(file, nginx_locations, settings, listener)
        self.write_health_loc(file, nginx_locations)
        self.write_metrics_loc(file, nginx_locations)
        self.write_error_pages(file, nginx_locations)

        # close server block
        file.write("}")
        

    def write_http_connection_upgrade(self, file, settings):
        """write_http_connection_upgrade creates the http_upgrade logic to upgrade http traffic"""
        file.write("map $http_upgrade $connection_upgrade {\n")
        file.write("\tdefault upgrade;\n")
        file.write("\t\'\' close;\n")
        file.write("\t}\n")

    def write_root_loc(self, file, nginx_loc, settings, listener):
        """write_root_loc writes the root location for the WAF upstream servers"""
        file.write("\tlocation / {\n")
        file.write("\t\tclient_max_body_size 0;\n")
        # write proxy headers
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

        timeout = settings['server']['advanced_options']['clientTimeout']['value'] + 's'
        file.write("\t\tproxy_read_timeout %s;\n" % timeout)
        file.write("\t\tproxy_connect_timeout %s;\n" % timeout)
        file.write("\t\tproxy_send_timeout %s;\n" % timeout)
        file.write("\t\tsend_timeout %s;\n" % timeout)
        file.write("\t\tproxy_redirect off;\n")
        file.write("\t\tproxy_pass_header Authorization;\n")
        
        # write proxy_pass to upstream server
        file.write(f"\t\tproxy_pass {listener['upstreamProtocol']}://backend_{listener['listenerID']};\n")

        # write root location
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
        file.write('\tinclude /etc/modsecurity.d/errors.conf;\n')

    def write_untangle_default_landing(self, file):
        """write_untangle_default_landing creates a URI rewrite that redirects all requests to /app/setup, and creates a root location that points to the app/index.html"""
        file.write("server {\n")
        file.write("\tlisten 80;\n")
        file.write("\tlocation / {\n")
        file.write("\t\trewrite ^ http://$host/app/setup redirect;\n")
        file.write("\t}\n")
        file.write("\tlocation /app {\n")
        file.write("\t\tproxy_pass http://localhost:8585;\n")
        file.write("\t}\n")
        file.write("\tlocation /api {\n")
        file.write("\t\tproxy_pass http://localhost:8585;\n")
        file.write("\t}\n")
        self.write_error_pages(file, [])
        file.write("}\n")

    def write_ssl_settings(self, file, settings, listener):
        """writes the ssl information for a server listener"""
        server_ssl = settings['server']['serverSsl']
        file.write("\tssl_certificate " + server_ssl['proxySslCert'] + ";\n")
        file.write("\tssl_certificate_key " + server_ssl['proxySslCertKey'] + ";\n")
        file.write("\tssl_ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS;\n")
        file.write("\tssl_prefer_server_ciphers on;\n")
        file.write("\tssl_protocols TLSv1 TLSv1.1 TLSv1.2;\n")
        file.write("\tssl_verify_client " + server_ssl['proxySslVerify'] + ";\n")

registrar.register_manager(NginxConfManager())