"""This class is responsible for managing the nginx configuration for WAF"""
import os
from sync import registrar, Manager

class NginxConfManager(Manager):
    """NginxConfManager manages the nginx manager settings"""
    nginx_filename="/etc/nginx/conf.d/default.conf"
    nginx_file = None

    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.nginx_filename, "restart-nginx", self)

    def create_settings(self, settings_file, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        server = {}
        #TODO: change how defaults are handled with new slimmed down docker?
        basic_server = {
            'ssl_port': '443',
            'port': '80',
            'dns_server': '127.0.0.11',
            'server_name': 'localhost',
            'paranoia': '1',
            'proxy': '1'
        }
        upstream_backend = {
            'upstream_servers': [
                {
                    'upstream_server_name': 'localhost',
                    'upstream_server_uid': '-1',
                },
            ],
            'lb_method': None
        }
        server_ssl = {
            'proxy_ssl_cert': '/etc/nginx/conf/server.crt',
            'proxy_ssl_cert_key': '/etc/nginx/conf/server.key',
            'proxy_ssl_verify': 'off'
        }
        nginx_locations = {
            'proxy_timeout': '60s',
            'metrics_allow_from': '127.0.0.0/24',
            'metrics_deny_from': 'all',
        }
        server['basic_server'] = basic_server
        server['upstream_backend'] = upstream_backend
        server['server_ssl'] = server_ssl
        server['nginx_locations'] = nginx_locations
        settings_file.settings['server'] = server

    def sync_settings(self, settings_file, prefix, delete_list):
        """syncs settings"""
        self.write_nginx_file(settings_file.settings, prefix)

    def write_nginx_file(self, settings, prefix):
        """write the nginx default.conf file"""
        filename = prefix + self.nginx_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.nginx_file = open(filename, "w+")
        file = self.nginx_file
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")

        file.write("\n")
        file.write(r"""
# Nginx configuration for both HTTP and SSL
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}
""")
        self.write_upstream_backend(settings)
        self.write_basic_server_conf(settings)
        self.write_nginx_main_locations(settings)

        file.flush()
        file.close()

    def write_upstream_backend(self, settings):
        """write the upstream backend block for nginx"""
        upstream_backend = settings['server']['upstream_backend']
        file = self.nginx_file
        file.write("upstream backend {\n")

        if len(upstream_backend.get('upstream_servers')) > 1 and upstream_backend['lb_method'] is not None:
            lb = upstream_backend['lb_method']
            if lb == 'least_connections':
                file.write("    least_conn;\n")
            elif lb == 'random':
                file.write("    random;\n")
            elif lb == 'sticky':
                file.write("    sticky;\n")
            # round robin needs no additional configuration written
            # any unknown lb method would also have nothing written out to the nginx file

        for server in upstream_backend.get('upstream_servers'):
            file.write("    server " + server.get('upstream_server_name') + ";\n")
        file.write("}\n")
        file.write("\n")

    def write_basic_server_conf(self, settings):
        """write the initial settings of the server block for nginx"""
        basic_server = settings['server']['basic_server']
        file = self.nginx_file
        file.write("server {\n")
        file.write("    listen " + basic_server['ssl_port'] + " ssl;\n")
        file.write("    listen " + basic_server['port'] + ";\n")
        file.write("\n")
        file.write("    resolver " + basic_server['dns_server'] + " valid=5s;\n")
        file.write("    server_name " + basic_server['server_name'] + ";\n")
        file.write("\n")

        server_ssl = settings['server']['server_ssl']
        file = self.nginx_file
        file.write("    ssl_certificate " + server_ssl['proxy_ssl_cert'] + ";\n")
        file.write("    ssl_certificate_key " + server_ssl['proxy_ssl_cert_key'] + ";\n")
        file.write(
r"""    ssl_ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS;
    ssl_prefer_server_ciphers on;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
""")
        file.write("    ssl_verify_client " + server_ssl['proxy_ssl_verify'] + ";\n")
        file.write("\n")

    def write_nginx_main_locations(self, settings):
        """write the main location, healthz, and metrics nginx endpoints"""
        nginx_locations = settings['server']['nginx_locations']
        file = self.nginx_file
        file.write(
r"""    location / {
        client_max_body_size 0;
        proxy_set_header Host $host;
        proxy_set_header Proxy "";
        proxy_set_header Upgrade $connection_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Port $server_port;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_buffering off;
""")
        file.write("        proxy_connect_timeout " + nginx_locations['proxy_timeout'] + ";\n")
        file.write(
r"""        proxy_read_timeout 36000s;
        proxy_redirect off;
        proxy_pass_header Authorization;
        proxy_pass http://backend;
        index index.html index.htm;
        root /usr/share/nginx/html;
    }
    location /healthz {
        access_log off;
        add_header Content-Type text/plain;
        return 200 "OK";
    }
    location /metrics/nginx {
        access_log off;
""")
        file.write("        allow " + nginx_locations['metrics_allow_from'] + ";\n")
        file.write("        deny " + nginx_locations['metrics_deny_from'] + ";\n")
        file.write(
r"""        proxy_store off;
        stub_status;
    }
    error_page 500 502 503 504  /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
""")

registrar.register_manager(NginxConfManager())