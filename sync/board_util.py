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
    }.get(board_name, "eth1")

def get_internal_device_name():
    board_name = get_board_name()
    return {
            "armada-385-linksys-shelby": "eth0.1",
            "armada-385-linksys-rango": "eth0.1",
    }.get(board_name, "eth0")

