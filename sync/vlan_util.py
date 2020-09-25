"""vlan utilities"""
# pylint: disable=broad-except
# pylint: disable=bare-except

from sync import network_util

def write_interface_vlan(intf, vlanBoundName):
    vlan_settings = ""
    vlan_settings += "\n"

    #device block
    vlan_settings += "config device\n"
    vlan_settings += "\toption type '8021q'\n"
    vlan_settings += "\toption ifname '%s'\n" % vlanBoundName
    vlan_settings += "\toption vid '%s'\n" % intf.get('vlanid')
    vlan_settings += "\toption name '%s'\n" % intf.get('name')

    return vlan_settings

def write_vlan_bound_to_interface(intf, vlanBoundInterface):
    bound_to_interface = ''
    bound_to_interface += '\n'

    #bound to interface 
    bound_to_interface += "config interface '%s'\n" % intf.get('name')
    bound_to_interface += "\toption type 'bridge'\n"
    bound_to_interface += "\toption ifname '%s'\n" % " ".join(intf.get('bridged_interfaces_str'))

    return bound_to_interface

