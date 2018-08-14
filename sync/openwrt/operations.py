import sync.registrar

sync.registrar.register_operation( "restart-networking", [""], ["/etc/init.d/network reload"], 10, None )
sync.registrar.register_operation( "restart-wireless", [""], ["/sbin/wifi"], 10, None )
sync.registrar.register_operation( "restart-dhcp", [""], ["/etc/init.d/dnsmasq restart"], 10, None )

def verify_settings(settings):
    """
    Sanity check the settings
    """
    if settings is None:
        raise Exception("Invalid Settings: null")

def cleanup_settings( settings ):
    """
    This removes/disable hidden fields in the interface settings so we are certain they don't apply
    We do these operations here because we don't want to actually modify the settings
    For example, lets say you have DHCP enabled, but then you choose to bridge that interface to another instead.
    The settings will reflect that dhcp is still enabled, but to the user those fields are hidden.
    It is convenient to keep it enabled in the settings so when the user switches back to their previous settings
    everything is still the same. However, we need to make sure that we don't actually enable DHCP on that interface.

    This function runs through the settings and removes/disables settings that are hidden/disabled in the current configuration.
    """
    return
    
sync.registrar.settings_verify_function = verify_settings
sync.registrar.settings_cleanup_function = cleanup_settings
