import sync.registrar

sync.registrar.register_operation("update-hostname",    None, ["hostname -F /etc/hostname"],          1, "restart-networking")
sync.registrar.register_operation("restart-networking", ["ifdown -a -v --exclude=lo"], ["ifup -a -v --exclude=lo", "/usr/bin/systemctl-wait"], 10, None)
sync.registrar.register_operation("restart-dnsmasq",    None, ["/etc/untangle/post-network-hook.d/990-restart-dnsmasq", "/usr/bin/systemctl-wait"],   20, "restart-networking")
sync.registrar.register_operation("restart-miniupnpd",  None, ["/etc/untangle/post-network-hook.d/990-restart-upnp", "/usr/bin/systemctl-wait"],      21, "restart-networking")
sync.registrar.register_operation("restart-radvd",      None, ["/etc/untangle/post-network-hook.d/990-restart-radvd", "/usr/bin/systemctl-wait"],     22, "restart-networking")
sync.registrar.register_operation("restart-ddclient",   None, ["/etc/untangle/post-network-hook.d/990-restart-ddclient", "/usr/bin/systemctl-wait"],  23, "restart-networking")
sync.registrar.register_operation("restart-softflowd",  None, ["/etc/untangle/post-network-hook.d/990-restart-softflowd", "/usr/bin/systemctl-wait"], 25, "restart-networking")
sync.registrar.register_operation("restart-quagga",     None, ["/etc/untangle/post-network-hook.d/990-restart-quagga", "/usr/bin/systemctl-wait"],    26, "restart-networking")
sync.registrar.register_operation("restart-keepalived", None, ["/etc/untangle/post-network-hook.d/200-vrrp", "/usr/bin/systemctl-wait"],              30, "restart-networking")
sync.registrar.register_operation("restart-iptables",   None, ["/etc/untangle/post-network-hook.d/960-iptables", "/usr/bin/systemctl-wait"],          50, "restart-networking")


def verify_settings(settings):
    """
    Sanity check the settings
    """
    if settings is None:
        raise Exception("Invalid Settings: null")

    if 'interfaces' not in settings:
        raise Exception("Invalid Settings: missing interfaces")
    interfaces = settings['interfaces']
    for intf in interfaces:
        for key in ['interfaceId', 'name', 'systemDev', 'symbolicDev', 'physicalDev', 'configType']:
            if key not in intf:
                raise Exception("Invalid Interface Settings: missing key %s" % key)

    if 'virtualInterfaces' not in settings:
        raise Exception("Invalid Settings: missing virtualInterfaces")
    virtualInterfaces = settings['virtualInterfaces']
    for intf in virtualInterfaces:
        for key in ['interfaceId', 'name']:
            if key not in intf:
                raise Exception("Invalid Virtual Interface Settings: missing key %s" % key)


def cleanup_settings(settings):
    """
    This removes/disable hidden fields in the interface settings so we are certain they don't apply
    We do these operations here because we don't want to actually modify the settings
    For example, lets say you have DHCP enabled, but then you choose to bridge that interface to another instead.
    The settings will reflect that dhcp is still enabled, but to the user those fields are hidden.
    It is convenient to keep it enabled in the settings so when the user switches back to their previous settings
    everything is still the same. However, we need to make sure that we don't actually enable DHCP on that interface.

    This function runs through the settings and removes/disables settings that are hidden/disabled in the current configuration.
    """
    interfaces = settings['interfaces']
    virtualInterfaces = settings['virtualInterfaces']

    # Remove disabled interfaces from regular interfaces list
    # Save them in another field in case anyone needs them
    disabled_interfaces = [intf for intf in interfaces if intf.get('configType') == 'DISABLED']
    new_interfaces = [intf for intf in interfaces if intf.get('configType') != 'DISABLED']
    new_interfaces = sorted(new_interfaces, key=lambda x: x.get('interfaceId'))
    settings['interfaces'] = new_interfaces
    settings['disabledInterfaces'] = disabled_interfaces

    disabled_virtual_interfaces = []
    new_virtual_interfaces = [intf for intf in virtualInterfaces]
    new_virtual_interfaces = sorted(new_virtual_interfaces, key=lambda x: x.get('interfaceId'))
    settings['virtualInterfaces'] = new_virtual_interfaces
    settings['disabledVirtualInterfaces'] = disabled_virtual_interfaces

    # Disable DHCP if if its a WAN or bridged to another interface
    for intf in interfaces:
        if intf['isWan'] or intf['configType'] == 'BRIDGED':
            for key in list(intf.keys()):
                if key.startswith('dhcp'):
                    del intf[key]

    # Disable NAT options on bridged interfaces
    for intf in interfaces:
        if intf['configType'] == 'BRIDGED':
            if 'v4NatEgressTraffic' in intf:
                del intf['v4NatEgressTraffic']
            if 'v4NatIngressTraffic' in intf:
                del intf['v4NatIngressTraffic']

    # Disable Gateway for non-WANs
    for intf in interfaces:
        if intf.get('isWan') != True:
            if 'v4StaticGateway' in intf:
                del intf['v4StaticGateway']
            if 'v6StaticGateway' in intf:
                del intf['v6StaticGateway']

    # Disable egress NAT on non-WANs
    # Disable ingress NAT on WANs
    for intf in interfaces:
        if intf['isWan']:
            if 'v4NatIngressTraffic' in intf:
                del intf['v4NatIngressTraffic']
        if not intf['isWan']:
            if 'v4NatEgressTraffic' in intf:
                del intf['v4NatEgressTraffic']

    # Remove PPPoE settings if not PPPoE intf
    for intf in interfaces:
        if intf['v4ConfigType'] != 'PPPOE':
            for key in list(intf.keys()):
                if key.startswith('v4PPPoE'):
                    del intf[key]

    # Remove static settings if not static intf
    for intf in interfaces:
        if intf['v4ConfigType'] != 'STATIC':
            for key in list(intf.keys()):
                if key.startswith('v4Static'):
                    del intf[key]

    # Remove auto settings if not auto intf
    for intf in interfaces:
        if intf['v4ConfigType'] != 'AUTO':
            for key in list(intf.keys()):
                if key.startswith('v4Auto'):
                    del intf[key]

    # Remove bridgedTo settings if not bridged
    for intf in interfaces:
        if intf['configType'] != 'BRIDGED':
            if 'bridgedTo' in intf:
                del intf['bridgedTo']

    # In 13.1 we renamed inputFilterRules to accessRules
    # Check for safety NGFW-10791
    # This can be removed after 13.1
    if settings.get('inputFilterRules') != None and settings.get('accessRules') == None:
        print("WARNING: accessRules missing - using inputFilterRules")
        settings['accessRules'] = settings.get('inputFilterRules')

    # In 13.1 we renamed forwardFilterRules to filterRules
    # Check for safety NGFW-10791
    # This can be removed after 13.1
    if settings.get('forwardFilterRules') != None and settings.get('filterRules') == None:
        print("WARNING: filterRules missing - using forwardFilterRules")
        settings['filterRules'] = settings.get('forwardFilterRules')

    return


sync.registrar.settings_verify_function = verify_settings
sync.registrar.settings_cleanup_function = cleanup_settings
