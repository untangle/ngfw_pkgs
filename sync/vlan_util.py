"""vlan utilities"""
# pylint: disable=broad-except
# pylint: disable=bare-except

from sync import network_util

def write_interface_vlan(intf, settings):
    """Create device and interface block for VLANs to be written to /etc/config/network"""
    vlan_settings = ""
    vlan_settings += "\n"

    #Get device name of VLAN's bound (parent) interface
    vlanBoundInterface = network_util.get_interface_by_id(settings, intf.get('boundInterfaceId'))
    vlanBoundName = vlanBoundInterface.get('device')

    #device block
    vlan_settings += "config device\n"
    vlan_settings += "\toption type '8021q'\n"
    vlan_settings += "\toption ifname '%s'\n" % vlanBoundName
    vlan_settings += "\toption vid '%s'\n" % intf.get('vlanid')
    vlan_settings += "\toption name '%s'\n" % intf.get('name')

    return vlan_settings

