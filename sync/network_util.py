"""network utilities"""
# pylint: disable=broad-except
# pylint: disable=bare-except
import subprocess

class NetworkUtil:
    """
    This class is a utility class with utility functions providing
    useful tools for dealing with iptables rules
    """
    settings = {}

    @staticmethod
    def interface_list():
        """
        returns a list of the interfaceId's extracted from the settings
        """
        settings = NetworkUtil.settings
        ret = []

        if settings is None or 'interfaces' not in settings:
            return ret

        for intf in settings['interfaces']:
            if 'interfaceId' not in intf:
                continue
            ret.append(int(intf['interfaceId']))
        return ret

    @staticmethod
    def wan_list():
        """
        returns a list of the interfaceId's for WANS extracted from the settings
        """
        settings = NetworkUtil.settings
        ret = []

        if settings is None or settings.get('interfaces') is None:
            return ret

        for intf in settings['interfaces']:
            if intf.get('interfaceId') is None:
                continue
            if intf.get('configType') == 'ADDRESSED' and intf.get('isWan'):
                ret.append(int(intf['interfaceId']))

        for intf in settings['virtualInterfaces']:
            if intf.get('interfaceId') is None:
                continue
            if intf.get('isWan'):
                ret.append(int(intf['interfaceId']))
        return ret

    @staticmethod
    def non_wan_list():
        """
        returns a list of the interfaceId's for non-WANS extracted from the settings
        """
        settings = NetworkUtil.settings
        ret = []

        if settings is None or settings.get('interfaces') is None:
            return ret

        for intf in settings['interfaces']:
            if intf.get('interfaceId') is None:
                continue
            if intf.get('configType') == 'ADDRESSED' and intf.get('isWan'):
                continue
            else:
                ret.append(int(intf['interfaceId']))
        for intf in settings['virtualInterfaces']:
            if intf.get('interfaceId') is None:
                continue
            if intf.get('isWan'):
                continue
            else:
                ret.append(int(intf['interfaceId']))
        return ret


CIDR_MAP = {
    1:	"128.0.0.0",
    2:	"192.0.0.0",
    3:	"224.0.0.0",
    4:	"240.0.0.0",
    5:	"248.0.0.0",
    6:	"252.0.0.0",
    7:	"254.0.0.0",
    8:	"255.0.0.0",
    9:	"255.128.0.0",
    10:	"255.192.0.0",
    11:	"255.224.0.0",
    12:	"255.240.0.0",
    13:	"255.248.0.0",
    14:	"255.252.0.0",
    15:	"255.254.0.0",
    16:	"255.255.0.0",
    17:	"255.255.128.0",
    18:	"255.255.192.0",
    19:	"255.255.224.0",
    20:	"255.255.240.0",
    21:	"255.255.248.0",
    22:	"255.255.252.0",
    23:	"255.255.254.0",
    24:	"255.255.255.0",
    25:	"255.255.255.128",
    26:	"255.255.255.192",
    27:	"255.255.255.224",
    28:	"255.255.255.240",
    29:	"255.255.255.248",
    30:	"255.255.255.252",
    31:	"255.255.255.254",
    32:	"255.255.255.255"
}
    
def ipv4_prefix_to_netmask(prefix):
    """prefix to netmask string"""
    if prefix < 0 or prefix > 32:
        return None
    return CIDR_MAP.get(prefix)

def is_bridge_interface(settings, interface):
    """
    returns true if interface has any other interfaces bridged to it
    If it does this interface is definitionally a "bridge group"
    """
    interfaces = settings.get('network').get('interfaces')
    for intf in interfaces:
        if intf.get('configType') == "BRIDGED" and \
           intf.get('bridgedTo') == interface.get('interfaceId'):
            return True
    return False

def get_interface_by_id(settings, interfaceId):
    """ returns interface with the given interfaceId """
    interfaces = settings.get('network').get('interfaces')
    for intf in interfaces:
        if intf.get('interfaceId') == interfaceId:
            return intf
    return None

def get_policy_by_id(settings, policyId):
    """ 
    @param settings - The Settings json
    @param policyId - The policy ID to load the full policy JSON for
    returns interface with the given policyId 
    """
    policies = settings['wan'].get('policies')
    for pol in policies:
        if pol.get('policyId') == policyId:
            return pol
    return None

def get_policy_description(settings, policyId):
    """
    @param settings - The settings json
    @param policyId - the policy ID
    returns the policy description, or just the policy ID if not found
    """
    load_pol = get_policy_by_id(settings, policyId)
    if load_pol is None:
        return policyId
    return load_pol.get('description')

def get_interface_name_confirm(settings, interfaceId):
    """
    @param settings - the settings json
    @param interfaceId - the interface ID
    returns the interface name, or just the interface ID if not found
    """
    load_intf = get_interface_by_id(settings, interfaceId)
    if load_intf is None:
        return interfaceId
    return load_intf.get('name')

def get_interface_name(settings, intf, family):
    """
    @param settings - the Settings json
    @param intf - the interface we wish to retrieve the name from
    @param family - the ip family we are checking against (ipv4 or ipv6)
    returns the interface name as it would appear in /etc/config/network
    """
    interface_name = ""
    if is_bridge_interface(settings, intf):
        interface_name = "b_"

    interface_name = interface_name + intf.get('name')

    if intf.get('type') == 'OPENVPN' or intf.get('type') == 'WIREGUARD' or intf.get('type') == 'WWAN':
        return interface_name
    # Does it make sense to check the "ConfigType" if we have to specify family in the util call anyway?
    if family == 'ipv4' and intf.get('v4ConfigType') != 'DISABLED':
        interface_name = interface_name + "4"
    if family == 'ipv6' and intf.get('v6ConfigType') != 'DISABLED':
        interface_name = interface_name + "6"

    return interface_name

def get_bridge_name(settings, interface):
    """
    returns the name of the bridge that this interface is a part of
    as it would appear in /etc/config/network
    """
    interfaces = settings['network']['interfaces']
    for intf in interfaces:
        if intf.get('interfaceId') == interface.get('bridgedTo'):
            return "b_" + intf.get('name')
    return ""

def get_interface_ip4addr(ifname):
    """Get the IPv4 address of the specified interface"""
    try:
        cmd = r"ip addr show %s | sed -rne '/inet/s:\s+inet\s+([0-9.]+).*:\1:gp'"%ifname
        return subprocess.check_output(cmd, shell=True, stderr=subprocess.DEVNULL).decode('ascii').rstrip()
    except:
        return None

def get_interface_ip4prefix(ifname):
    """Get the IPv4 prefix of the specified interface"""
    try:
        cmd = r"ip addr show %s | sed -rne '/inet/s:\s+inet\s+[0-9.]+/([0-9]+).*:\1:gp'"%ifname
        output = subprocess.check_output(cmd, shell=True, stderr=subprocess.DEVNULL).decode('ascii').rstrip()
        return int(output)
    except:
        return None
