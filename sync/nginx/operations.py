import sync.registrar

sync.registrar.register_operation("restart-nginx", None, ["/etc/init.d/nginx reload"], 1, None)