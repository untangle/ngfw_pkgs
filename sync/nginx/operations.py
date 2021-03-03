import sync.registrar

sync.registrar.register_operation("restart-nginx", None, ["nginx -s"], 1, None)