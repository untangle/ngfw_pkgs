import sync.registrar

sync.registrar.register_operation("restart-nftables-rules", [""], ["/etc/init.d/nftables-rules restart"], 9, None)

sync.registrar.register_operation("restart-networking", [""], ["/etc/init.d/network reload"], 10, None)
sync.registrar.register_operation("restart-qos", [""], ["/etc/init.d/qos restart"], 11, None)
sync.registrar.register_operation("restart-wan-routing", [""], ["/etc/config/nftables-rules.d/102-wan-routing"], 12, "restart-nftables-rules")
sync.registrar.register_operation("restart-wan-manager", [""], ["rm -f /tmp/wan_manager.nft ; /etc/init.d/wan-manager reload"], 13, None)
sync.registrar.register_operation("restart-default-route", [""], ["/etc/config/ifdown.d/10-default-route"], 14, "restart-networking")

sync.registrar.register_operation("restart-wireless", [""], ["/sbin/wifi"], 20, None)

sync.registrar.register_operation("restart-dhcp", [""], ["/etc/init.d/dnsmasq restart"], 30, None)

sync.registrar.register_operation("startup-scripts", [""], ["/etc/init.d/startup boot ; /etc/init.d/system restart"], 40, None)


