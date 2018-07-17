import os
import sys
import subprocess
import string

def is_there_a_switch():
    return (0 == subprocess.call("swconfig list | grep -q 'Found'", shell=True))

def get_switches():
    switch_list = []
    switches = subprocess.check_output("swconfig list | grep Found | cut -f 2 -d ' '", shell=True).decode('ascii')
    for s in switches.splitlines():
        if s:
            switch_list.append(s)
    return switch_list

def get_switch_vlans(swi):
    vlan_list = []
    vlans = subprocess.check_output("swconfig dev %s show | grep VLAN | cut -f 1 -d ':' | cut -f 2 -d ' '" % swi, shell=True).decode('ascii')
    for vlan in vlans.splitlines():
        if vlan:
            vlan_list.append(vlan)
    return vlan_list

def get_switch_vlan_ports(swi, vlan):
    port_list = []
    ports = subprocess.check_output("swconfig dev %s vlan %s show | grep ports | cut -f 2- -d ' '" % (swi, vlan), shell=True).decode('ascii')
    for port in ports.split():
        if port:
            port_list.append(port)
    return port_list
