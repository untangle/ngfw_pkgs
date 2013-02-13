import os
import sys
import subprocess
import datetime
import traceback
import string

# This class is a utility class with utility functions providing
# useful tools for dealing with iptables rules
class NetworkUtil:

    settings = None

    @staticmethod
    def wan_list( verbosity=0 ):
        
        settings = NetworkUtil.settings
        ret = []

        if settings is None or 'interfaces' not in settings or 'list' not in settings['interfaces']:
            return ret

        for intf in settings['interfaces']['list']:
            if 'interfaceId' not in intf:
                continue

            if 'isWan' in intf and intf['isWan']:
                ret.append(int(intf['interfaceId']))
        
        return ret

    @staticmethod
    def non_wan_list( verbosity=0 ):
        
        settings = NetworkUtil.settings
        ret = []

        if settings is None or 'interfaces' not in settings or 'list' not in settings['interfaces']:
            return ret

        for intf in settings['interfaces']['list']:
            if 'interfaceId' not in intf:
                continue

            if 'isWan' in intf and intf['isWan']:
                continue
            else:
                ret.append(int(intf['interfaceId']))
        
        return ret

    @staticmethod
    def any_wan_string( verbosity=0 ):
        
        settings = NetworkUtil.settings
        retstr = ""

        if settings is None or 'interfaces' not in settings or 'list' not in settings['interfaces']:
            return retstr

        for intf in settings['interfaces']['list']:
            if 'interfaceId' not in intf:
                continue

            if 'isWan' in intf and intf['isWan']:
                retstr = retstr + str(intf['interfaceId']) + ( "" if retstr == "" else "," )
        
        return retstr

    @staticmethod
    def any_non_wan_string( verbosity=0 ):
        
        settings = NetworkUtil.settings
        retstr = ""

        if settings is None or 'interfaces' not in settings or 'list' not in settings['interfaces']:
            return retstr

        for intf in settings['interfaces']['list']:
            if 'interfaceId' not in intf:
                continue

            if 'isWan' in intf and intf['isWan']:
                continue
            else:
                retstr = retstr + str(intf['interfaceId']) + ( "" if retstr == "" else "," )
        
        return retstr
