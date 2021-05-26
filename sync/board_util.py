"""board/system utilities"""
# pylint: disable=broad-except
# pylint: disable=bare-except
import subprocess

def get_board_name():
    """get the board name"""
    try:
        return subprocess.check_output("cat /tmp/sysinfo/board_name", shell=True, stderr=subprocess.DEVNULL).decode('ascii').rstrip()
    except:
        return "unknown"

def get_hidden_interfaces():
    """returns a list of interfaces that should be hidden from the user"""
    board_name = get_board_name()
    return {
        "armada-385-linksys-shelby": ["eth0", "eth1"],
        "linksys,shelby": ["eth0", "eth1"],
        "armada-385-linksys-rango": ["eth0", "eth1", "wlan2"],
        "linksys,rango": ["eth0", "eth1", "wlan2"],
        "armada-385-linksys-venom": ["eth0", "eth1", "wlan2"],
        "linksys,venom": ["eth0", "eth1", "wlan2"],
        "armada-385-turris-omnia": ["eth0", "eth1"],
        "cznic,turris-omnia": ["eth0", "eth1"],
        "globalscale,espressobin": ["eth0"],
        "globalscale,espressobin-v7-emmc": ["eth0"],
        "caswell-caf-0262": ["wwan1", "wwan2"],
        "untangle-inc-default-string": ["wwan1", "wwan2"],
    }.get(board_name, [])

def get_wan_interfaces():
    """get the list of the wan devices"""
    board_name = get_board_name()
    return {
        "armada-385-linksys-shelby": ["wan"],
        "linksys,shelby": ["wan"],
        "armada-385-linksys-rango": ["wan"],
        "linksys,rango": ["wan"],
        "armada-385-linksys-venom": ["wan"],
        "linksys,venom": ["wan"],
        "armada-385-turris-omnia": ["eth2"],
        "cznic,turris-omnia": ["eth2"],
        "globalscale,espressobin": ["wan", "lan0"],
        "globalscale,espressobin-v7-emmc": ["eth1", "eth2"],
        "caswell-caf-0262": ["eth4", "eth5"],
        "untangle-inc-default-string": ["eth4", "eth5"],
        "raspberrypi,3-model-b-plus": ["eth0"],
        "raspberrypi,3-model-b": ["eth0"],
    }.get(board_name, ["eth1"])

def get_internal_interfaces():
    """get the list of the internal devices"""
    board_name = get_board_name()
    return {
        "armada-385-linksys-shelby": ["lan1", "lan2", "lan3", "lan4"],
        "linksys,shelby": ["lan1", "lan2", "lan3", "lan4"],
        "armada-385-linksys-rango": ["lan1", "lan2", "lan3", "lan4"],
        "linksys,rango": ["lan1", "lan2", "lan3", "lan4"],
        "armada-385-linksys-venom": ["lan1", "lan2", "lan3", "lan4"],
        "linksys,venom": ["lan1", "lan2", "lan3", "lan4"],
        "armada-385-turris-omnia": ["lan0", "lan1", "lan2", "lan3", "lan4"],
        "cznic,turris-omnia": ["lan0", "lan1", "lan2", "lan3", "lan4"],
        "globalscale,espressobin": ["lan1"],
        "globalscale,espressobin-v7-emmc": ["eth3"],
        "caswell-caf-0262": ["eth0", "eth1", "eth2", "eth3"],
        "untangle-inc-default-string": ["eth0", "eth1", "eth2", "eth3"],
        "raspberrypi,3-model-b-plus": ["wlan0"],
        "raspberrypi,3-model-b": ["wlan0"],
    }.get(board_name, ["eth0"])

interface_name_maps = {
    "globalscale,espressobin-v7-emmc": { "eth1": "WAN0", "eth2": "WAN1", "eth3": "LAN", "wlan0": "WiFi"},
    "caswell-caf-0262": { "eth0": "LAN1", "eth1": "LAN2", "eth2": "LAN3", "eth3": "LAN4", "eth4": "WAN0", "eth5": "WAN1", "wlan0": "WiFi", "wwan0": "LTE"},
    "untangle-inc-default-string": { "eth0": "LAN1", "eth1": "LAN2", "eth2": "LAN3", "eth3": "LAN4", "eth4": "WAN0", "eth5": "WAN1", "wlan0": "WiFi", "wwan0": "LTE"},
    "linksys,shelby": { "lan1": "LAN1", "lan2": "LAN2", "lan3": "LAN3", "lan4": "LAN4", "wan": "WAN", "wlan0": "WiFiOne", "wlan1": "WiFiTwo"},
    "linksys,rango": { "lan1": "LAN1", "lan2": "LAN2", "lan3": "LAN3", "lan4": "LAN4", "wan": "WAN", "wlan0": "WiFiOne", "wlan1": "WiFiTwo"},
    "linksys,venom": { "lan1": "LAN1", "lan2": "LAN2", "lan3": "LAN3", "lan4": "LAN4", "wan": "WAN", "wlan0": "WiFiOne", "wlan1": "WiFiTwo"}
}

def get_interface_name(device):
    """get the device specific interface name"""
    board_name = get_board_name()
    interface_name = interface_name_maps.get(board_name, {}).get(device, "")

    return interface_name


def get_country_code():
    """get the country code"""
    board_name = get_board_name()
    if board_name in ["armada-385-linksys-shelby", "linksys,shelby"]:
        sku = None
        try:
            sku = subprocess.check_output("cat /tmp/syscfg/syscfg/syscfg.dat | sed -ne 's/^device::cert_region=//p'", shell=True, stderr=subprocess.DEVNULL).decode('ascii').rstrip()
        except:
            pass
        return {
            "AP": "CN",
            "AU": "AU",
            "EU": "DE",
            "US": "US",
        }.get(sku, "")

    return ""

def get_device_macaddr(ifname):
    """get the device mac address for the given ifname"""
    try:
        return subprocess.check_output("cat /sys/class/net/%s/address" % ifname, shell=True, stderr=subprocess.DEVNULL).decode('ascii').rstrip()
    except:
        return None

def increment_mac(mac, inc):
    """increment the specified MAC address"""
    eth_mac = mac.split(':')
    nic = int("".join([eth_mac[3], eth_mac[4], eth_mac[5]]), 16)
    nic += inc
    new_nic = "%06x" % nic
    return ":".join([eth_mac[0], eth_mac[1], eth_mac[2], new_nic[0:2], new_nic[2:4], new_nic[4:6]])

def get_interface_macaddr(ifname):
    """get the interface's mac address"""
    board_name = get_board_name()
    if board_name in ["armada-385-linksys-shelby", "linksys,shelby"]:
        return {
            "wlan0": increment_mac(get_device_macaddr("eth0"), 1),
            "wlan1": increment_mac(get_device_macaddr("eth0"), 2),
            "lan1": get_device_macaddr("eth1"),
            "lan2": get_device_macaddr("eth1"),
            "lan3": get_device_macaddr("eth1"),
            "lan4": get_device_macaddr("eth1"),
            "wan": get_device_macaddr("eth1"),
        }.get(ifname, "")
    if board_name in ["armada-385-linksys-rango", "armada-385-linksys-venom", "linksys,rango", "linksys,venom"]:
        return {
            "lan1": get_device_macaddr("eth1"),
            "lan2": get_device_macaddr("eth1"),
            "lan3": get_device_macaddr("eth1"),
            "lan4": get_device_macaddr("eth1"),
            "wan": get_device_macaddr("eth1"),
        }.get(ifname, "")
    return ""

def get_switch_settings():
    """get the switch settings"""
    # currently unused as we moved switch config to kernel
    board_name = get_board_name()
    return {
    }.get(board_name, [])

def is_docker():
    """returns true if the system is a docker container"""
    try:
        grep_output = subprocess.check_output(["/bin/grep", "docker", "/proc/1/cgroup"])
        if "docker" in grep_output.decode():
            return True
    except subprocess.CalledProcessError:
        pass
    return False
