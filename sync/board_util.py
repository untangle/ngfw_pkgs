import os
import sys
import subprocess
import string

def get_board_name():
    try:
        return subprocess.check_output("cat /tmp/sysinfo/board_name", shell=True, stderr=subprocess.DEVNULL).decode('ascii').rstrip()
    except:
        return "unknown"

def get_hidden_interfaces():
    board_name = get_board_name()
    return {
            "armada-385-linksys-shelby": ["eth0", "eth1"],
            "armada-385-linksys-rango": ["eth0", "eth1"],
            "armada-385-turris-omnia": ["eth0", "eth1"],
    }.get(board_name, [])

def get_external_device_name():
    board_name = get_board_name()
    return {
            "armada-385-linksys-shelby": "wan",
            "armada-385-linksys-rango": "wan",
            "armada-385-turris-omnia": "eth2",
    }.get(board_name, "eth1")

def get_internal_device_name():
    board_name = get_board_name()
    return {
            "armada-385-linksys-shelby": "lan1",
            "armada-385-linksys-rango": "lan1",
            "armada-385-turris-omnia": "lan0",
    }.get(board_name, "eth0")

def get_country_code():
    board_name = get_board_name()
    if board_name == "armada-385-linksys-shelby":
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

def get_eth0_mac_addr():
    try:
        return subprocess.check_output("cat /sys/class/net/eth0/address", shell=True, stderr=subprocess.DEVNULL).decode('ascii').rstrip()
    except:
        return None

def increment_mac(mac, idx):
    eth_mac = mac.split(':')
    nic = int("".join([eth_mac[3], eth_mac[4], eth_mac[5]]), 16)
    nic += idx
    new_nic = "%6x" % nic
    return ":".join([eth_mac[0], eth_mac[1], eth_mac[2], new_nic[0:2], new_nic[2:4], new_nic[4:6]]) 

def get_wireless_macaddr(idx):
    board_name = get_board_name()
    if board_name == "armada-385-linksys-shelby":
        return increment_mac(get_eth0_mac_addr(), idx + 1)
    return ""

def get_switch_settings():
    board_name = get_board_name()
    return {
    }.get(board_name, [])
    return ""
