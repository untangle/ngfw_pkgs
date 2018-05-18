from sync.registrar import register_operation

register_operation( "restart-networking", ["/bin/true"], ["/bin/true"], 10, None )
