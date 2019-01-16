import sync.registrar

sync.registrar.register_operation("restart-nftables-rules", [""], ["/etc/init.d/nftables-rules restart"], 9, None)

sync.registrar.register_operation("restart-networking", [""], ["/etc/init.d/network reload"], 10, None)
sync.registrar.register_operation("restart-qos", [""], ["/etc/config/nftables-rules.d/300-qos-rules-sys"], 11, "restart-nftables-rules")
sync.registrar.register_operation("restart-default-route", [""], ["/etc/config/ifdown.d/10-default-route"], 12, "restart-networking")
sync.registrar.register_operation("restart-wan-balancer", [""], ["/etc/config/ifup.d/20-wan-balancer"], 13, "restart-networking")
sync.registrar.register_operation("restart-openvpn", ["/etc/config/ifdown.d/30-openvpn loopback"], ["/etc/config/ifup.d/30-openvpn loopback"], 14, "restart-networking")

sync.registrar.register_operation("restart-wireless", [""], ["/sbin/wifi"], 20, None)

sync.registrar.register_operation("restart-dhcp", [""], ["/etc/init.d/dnsmasq restart"], 30, None)

sync.registrar.register_operation("startup-scripts", [""], ["/etc/init.d/startup boot"], 40, None)


