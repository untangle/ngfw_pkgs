"""vlan utilities"""
# pylint: disable=broad-except
# pylint: disable=bare-except

#class VlanUtil:
#    """
#    This class is a utility class with utility functions providing
#    useful tools for dealing with vlans 
#    """

def write_interface_vlan(intf):
    vlan_settings = ""
    vlan_settings += "\n"

    #device block
    vlan_settings += "config device\n"
    vlan_settings += "\toption type '8021q'\n"
    vlan_settings += "\toption ifname '%s'\n" % intf['boundInterfaceId']
    vlan_settings += "\toption vid '%s'\n" % intf['vlanId']
    vlan_settings += "\toption name '%s'\n" % intf['vlan_name']

    #interface block
    vlan_settings += "\n"
    vlan_settings += "config interface '%s'\n" % intf['logical_name']
    vlan_settings += "\toption type 'bridge'\n"
    vlan_settings += "\toption ifname '%s'\n" % intf['vlan_name']

    return vlan_settings

