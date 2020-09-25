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

    #vlan interface block
    vlan_settings += "\n"
    vlan_settings += "config interface '%s'\n" % intf.get('name')
    vlan_settings += "\toption proto static\n"
    vlan_settings += "\toption ifname '%s'\n" % intf.get('name')
    vlan_settings += "\toption ipaddr '%s'\n" % intf.get('v4StaticAddress')
    vlan_settings += "\toption netmask '%s'\n" % network_util.ipv4_prefix_to_netmask(intf.get('v4StaticPrefix'))

    return vlan_settings

