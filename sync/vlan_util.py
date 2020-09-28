"""vlan utilities"""
# pylint: disable=broad-except
# pylint: disable=bare-except

def write_interface_vlan(intf, vlanBoundName):
    vlan_settings = ""
    vlan_settings += "\n"

    #device block
    vlan_settings += "config device\n"
    vlan_settings += "\toption type '8021q'\n"
    vlan_settings += "\toption ifname '%s'\n" % vlanBoundName
    vlan_settings += "\toption vid '%s'\n" % intf.get('vlanid')
    vlan_settings += "\toption name '%s'\n" % intf.get('name')

    #bound to interface 
    vlan_settings += '\n'
    vlan_settings += "config interface '%s'\n" % intf.get('name')
    vlan_settings += "\toption type 'bridge'\n"
    bridged_interface_str = intf.get('name')
    if intf.get('configType') == 'BRIDGED':
        bridged_interface_str += " %s" % vlanBoundName
    vlan_settings += "\toption ifname '%s'\n" % bridged_interface_str

    return vlan_settings

