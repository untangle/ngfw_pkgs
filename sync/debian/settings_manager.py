import os
import stat
import sys
import subprocess
import datetime
import traceback
import re
from sync.network_util import NetworkUtil
from sync import registrar

# This class just does some initial cleanups of the settings object
# while sync_settings before the other managers get access to the settings object

class SettingsManager:

    def initialize(self):
        pass
    
    def sanitize_settings(self, settings):
        settings['httpPort'] = 81
        pass

    def validate_settings(self, settings):
        fixup_settings(settings)
        cleanup_settings(settings)

    def sync_settings(self, settings, prefix, delete_list):
        pass
    
registrar.register_manager(SettingsManager())

def fixup_settings(json_obj):
    """
    Fixes JSON serialization oddities in the JSON object
    """
    if isinstance(json_obj, dict):
        for key in list(json_obj.keys()):
            value = json_obj.get(key)
            if isinstance(value, dict):
                if value.get('list') != None and value.get('javaClass') != None and "List" in value.get('javaClass'):
                    # Java serializes list objects as:
                    # "foo": { "javaClass": "java.util.LinkedList", "list": [] },
                    # This will change it to this for simplicity:
                    # "foo": []
                    new_value = value.get('list')
                    value = new_value
                    json_obj[key] = new_value
            fixup_settings(json_obj.get(key))
    elif isinstance(json_obj, list):
        for i in range(len(json_obj)):
            fixup_settings(json_obj[i])

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
            
