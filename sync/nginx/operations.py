import sync.registrar

sync.registrar.register_operation("restart-nginx", None, ["nginx -s reload"], 1, None)