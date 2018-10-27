import sync.registrar

sync.registrar.register_operation("restart-networking", [""], ["/etc/init.d/network reload"], 10, None)
sync.registrar.register_operation("restart-nftables-rules", [""], ["/etc/init.d/nftables-rules restart"], 9, None)
sync.registrar.register_operation("restart-wireless", [""], ["/sbin/wifi"], 10, None)
sync.registrar.register_operation("restart-dhcp", [""], ["/etc/init.d/dnsmasq restart"], 10, None)
sync.registrar.register_operation("restart-qos", [""], ["/etc/config/nftables-rules.d/300-qos-rules-sys"], 10, "restart-nftables-rules")
sync.registrar.register_operation("restart-default-route", [""], ["/etc/config/ifdown.d/10-default-route"], 10, "restart-networking")
sync.registrar.register_operation("restart-wan-balancer", [""], ["/etc/config/ifup.d/20-wan-balancer"], 10, "restart-networking")


