import sync.registrar

sync.registrar.register_operation("restart-nftables-rules", [""], ["/etc/init.d/nftables-rules restart ; /etc/init.d/wan-manager restart"], 9, None)

sync.registrar.register_operation("restart-networking", [""], ["/etc/init.d/network reload"], 10, None)
sync.registrar.register_operation("restart-qos", [""], ["/etc/init.d/qos restart"], 11, None)
sync.registrar.register_operation("restart-wan-routing", [""], ["/etc/config/nftables-rules.d/102-wan-routing ; /etc/init.d/wan-manager restart"], 12, "restart-nftables-rules")
sync.registrar.register_operation("restart-default-route", [""], ["/etc/config/ifdown.d/10-default-route"], 14, "restart-networking")
sync.registrar.register_operation("restart-pyconnector", [""], ["/etc/init.d/pyconnector restart"], 15, None)

sync.registrar.register_operation("restart-wireless", [""], ["/sbin/wifi"], 20, None)

sync.registrar.register_operation("restart-dhcp", [""], ["/etc/init.d/dnsmasq restart ; /etc/init.d/odhcpd restart"], 30, None)

sync.registrar.register_operation("restart-cron", [""], ["/etc/init.d/cron stop ; /etc/init.d/cron enable ; /etc/init.d/cron start "], 35, None)

sync.registrar.register_operation("startup-scripts", [""], ["/etc/init.d/startup boot"], 40, None)

sync.registrar.register_operation("restart-nic-setting", [""], ["/etc/config/startup.d/060-nic-settings"], 30, 'startup-scripts')
