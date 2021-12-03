import os
import socket
import struct
import fcntl
import errno

from untangle_button_led_monitor import Logger, Settings

class NetlinkWatcher:
    """
    Singleton class to monitor network changes using netlink.
    """
    # Constants that map to Linux kernel values.
    RTMGRP_LINK = 1

    NLMSG_NOOP = 1
    NLMSG_ERROR = 2

    RTM_NEWLINK = 16
    RTM_DELLINK = 17

    IFLA_IFNAME = 3

    ready = None
    watch_manager = None
    event_notifier = None

    device_method = {}

    sock = None

    @classmethod
    def static_init(cls):
        """
        Create the netlink socket and bind to RTMGRP_LINK,
        """
        NetlinkWatcher.sock = socket.socket(socket.AF_NETLINK, socket.SOCK_RAW, socket.NETLINK_ROUTE)
        fcntl.fcntl(NetlinkWatcher.sock, fcntl.F_SETFL, os.O_NONBLOCK)
        NetlinkWatcher.sock.bind((os.getpid(), NetlinkWatcher.RTMGRP_LINK))

        NetlinkWatcher.ready = True

    @classmethod
    def register(cls, device, method=None):
        if Settings.Debug:
            Logger.message(f'device={device}, method={method}')
        NetlinkWatcher.device_method[device] = method

    @classmethod
    def clear_registers(cls):
        NetlinkWatcher.device_method = {}

    @classmethod
    def check(cls):
        if Settings.Debug:
            Logger.message()

        try:
            data = NetlinkWatcher.sock.recv(65535)
        except socket.error as e:
            err = e.args[0]
            if err == errno.EAGAIN or err == errno.EWOULDBLOCK:
                return
            else:
                # a "real" error occurred.  Try to recover
                Logger.message(e)
                NetlinkWatcher.static_init()

        msg_len, msg_type, flags, seq, pid = struct.unpack("=LHHLL", data[:16])

        if msg_type == NetlinkWatcher.NLMSG_NOOP:
            # Ignore no-op
            return
        elif msg_type == NetlinkWatcher.NLMSG_ERROR:
            NetlinkWatcher.static_init()
            return

        # We fundamentally only care about NEWLINK messages in this version.
        if msg_type != NetlinkWatcher.RTM_NEWLINK:
            return

        data = data[16:]

        family, _, if_type, index, flags, change = struct.unpack("=BBHiII", data[:16])

        remaining = msg_len - 32
        data = data[16:]

        while remaining:
            rta_len, rta_type = struct.unpack("=HH", data[:4])

            # This check comes from RTA_OK, and terminates a string of routing attributes.
            if rta_len < 4:
                break

            rta_data = data[4:rta_len]

            increment = (rta_len + 4 - 1) & ~(4 - 1)
            data = data[increment:]
            remaining -= increment

            # Link change.
            if rta_type == NetlinkWatcher.IFLA_IFNAME:
                device = rta_data.decode("ascii").rstrip('\x00')
                if device in list(NetlinkWatcher.device_method.keys()):
                    NetlinkWatcher.device_method[device](device)

if NetlinkWatcher.ready is None:
    NetlinkWatcher.static_init()
