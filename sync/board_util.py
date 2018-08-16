import os
import sys
import subprocess
import string

def get_board_name():
        return subprocess.check_output("cat /tmp/sysinfo/board_name", shell=True).decode('ascii').rstrip()

def get_external_device_name():
    board_name = get_board_name()
    return {
            "armada-385-linksys-shelby": "eth1.2",
            "armada-385-linksys-rango": "eth1.2",
            "armada-385-turris-omnia": "eth2",
    }.get(board_name, "eth1")

def get_internal_device_name():
    board_name = get_board_name()
    return {
            "armada-385-linksys-shelby": "eth0.1",
            "armada-385-linksys-rango": "eth0.1",
            "armada-385-turris-omnia": "lan0",
    }.get(board_name, "eth0")

def get_country_code():
    board_name = get_board_name()
    if board_name == "armada-385-linksys-shelby":
        sku = subprocess.check_output("cat /tmp/syscfg/syscfg/syscfg.dat | sed -ne 's/^device::cert_region=//p'", shell=True).decode('ascii').rstrip()
        return {
                "AP": "CN",
                "AU": "AU",
                "EU": "DE",
                "US": "US",
        }.get(sku, "")

    return ""

def get_eth0_mac_addr():
    return subprocess.check_output("cat /sys/class/net/eth0/address", shell=True).decode('ascii').rstrip()

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

linksys_switch = [{"name":"switch0",
                   "ports":[{"id":"0","pvid":"1","cpu_port":False},
                            {"id":"1","pvid":"1","cpu_port":False},
                            {"id":"2","pvid":"1","cpu_port":False},
                            {"id":"3","pvid":"1","cpu_port":False},
                            {"id":"4","pvid":"2","cpu_port":False},
                            {"id":"5","pvid":"1","cpu_port":True},
                            {"id":"6","pvid":"2","cpu_port":True}],
                   "vlans":[{"id":"1"},
                            {"id":"2"}],
                 }]

def get_switch_settings():
    board_name = get_board_name()
    return {
            "armada-385-linksys-shelby": linksys_switch,
            "armada-385-linksys-rango": linksys_switch,
    }.get(board_name, [])
    return ""
