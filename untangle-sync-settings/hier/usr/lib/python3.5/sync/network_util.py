import os
import sys
import subprocess
import datetime
import traceback
import string
import socket
import struct

# This class is a utility class with utility functions providing
# useful tools for dealing with iptables rules
class NetworkUtil:

    settings = None

    @staticmethod
    def interface_list( verbosity=0 ):
        """
        returns a list of the interfaceId's extracted from the settings
        """
        settings = NetworkUtil.settings
        ret = []

        if settings is None or 'interfaces' not in settings or 'list' not in settings['interfaces']:
            return ret

        for intf in settings['interfaces']['list']:
            if 'interfaceId' not in intf:
                continue
            ret.append(int(intf['interfaceId']))
        
        return ret
        

    @staticmethod
    def wan_list( verbosity=0 ):
        """
        returns a list of the interfaceId's for WANS extracted from the settings
        """
        settings = NetworkUtil.settings
        ret = []

        if settings == None or settings.get('interfaces') == None or settings.get('interfaces').get('list') == None:
            return ret

        for intf in settings['interfaces']['list']:
            if intf.get('interfaceId') == None:
                continue
            if intf.get('configType') == 'ADDRESSED' and intf.get('isWan'):
                ret.append(int(intf['interfaceId']))

        for intf in settings['virtualInterfaces']['list']:
            if intf.get('interfaceId') == None:
                continue
            if intf.get('isWan'):
                ret.append(int(intf['interfaceId']))
                
        return ret

    @staticmethod
    def non_wan_list( verbosity=0 ):
        """
        returns a list of the interfaceId's for non-WANS extracted from the settings
        """
        settings = NetworkUtil.settings
        ret = []

        if settings == None or settings.get('interfaces') == None or settings.get('interfaces').get('list') == None:
            return ret

        for intf in settings['interfaces']['list']:
            if intf.get('interfaceId') == None:
                continue
            if intf.get('configType') == 'ADDRESSED' and intf.get('isWan'):
                continue
            else:
                ret.append(int(intf['interfaceId']))
        for intf in settings['virtualInterfaces']['list']:
            if intf.get('interfaceId') == None:
                continue
            if intf.get('isWan'):
                continue
            else:
                ret.append(int(intf['interfaceId']))
                
        return ret

