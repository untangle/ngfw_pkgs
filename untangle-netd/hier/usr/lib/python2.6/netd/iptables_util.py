import os
import sys
import subprocess
import datetime
import traceback
import string
from netd.network_util import NetworkUtil

# This class is a utility class with utility functions providing
# useful tools for dealing with iptables rules
class IptablesUtil:

    settings = None

    @staticmethod
    def interface_matcher_string_to_interface_list( value ):
        intfs = []
        
        for substr in value.split(","):
            if substr == "wan":
                intf_values  = NetworkUtil.wan_list()
                for intfId in intf_values:
                    if intfId not in intfs:
                        intfs.append(intfId)
            elif substr == "non_wan":
                intf_values  = NetworkUtil.non_wan_list()
                for intfId in intf_values:
                    if intfId not in intfs:
                        intfs.append(intfId)
            else:
                intfs.append(int(substr))

        return intfs
                    

    # This method takes a list of matchers (conditions) from a rule and translates them into a string containing the iptables conditions
    # It returns a list of strings, because some set of matchers require multiple iptables rules
    # Example input: ['matcherType':'SRC_INTF', 'value':'1'] -> ["-m connmark --mark 0x01/0xff"]
    # Example input: ['matcherType':'DST_PORT', 'value':'123'] -> ["-p udp --dport 123", "-p tcp --dport 123"]
    @staticmethod
    def conditions_to_iptables_string( matchers, comment=None, verbosity=0 ):
        
        current_strings = [ "" ];

        if matchers is None:
            return current_strings;

        if comment != None:
                current_strings = [ current + (" -m comment --comment \"%s\" " % comment)  for current in current_strings ]

        hasProtocolMatcher = False
        for matcher in matchers:
            if 'matcherType' not in matcher:
                print "ERROR: Ignoring invalid matcher: %s" % str(matcher)
                continue
            if matcher['matcherType'] == 'PROTOCOL':
                hasProtocolMatcher = True

        for matcher in matchers:
            if 'matcherType' not in matcher:
                print "ERROR: Ignoring invalid matcher: %s" % str(matcher)
                continue

            matcherStr = ""
            matcherType = matcher['matcherType']
            invert = False
            value = None
            if 'value' in matcher:
                value = matcher['value']
            if 'invert' in matcher and matcher['invert']:
                invert = True

            if matcherType == "PROTOCOL":
                protos = value.split(",")
                if invert:
                    print "ERROR: invert not support on protocol matcher"
                    continue
                orig_current_strings = current_strings
                current_strings = []
                # split current rules for each protocol specified
                for i in range(0 , len(protos) ):
                    matcherStr = matcherStr + " --protocol %s " % string.lower(protos[i])
                    current_strings = current_strings + [ matcherStr + current for current in orig_current_strings ]

            if matcherType == "SRC_INTF":
                if "any" in value:
                    continue # no need to do anything

                intfs = IptablesUtil.interface_matcher_string_to_interface_list( value )

                if invert:
                    print "ERROR: invert not support on interface matcher"
                    continue
                orig_current_strings = current_strings
                current_strings = []
                # split current rules for each intf specified
                for i in range(0 , len(intfs) ):
                    matcherStr = " -m connmark --mark 0x%04X/0x00FF " % int(intfs[i])
                    current_strings = current_strings + [ current + matcherStr for current in orig_current_strings ]

            if matcherType == "DST_INTF":
                if "any" in value:
                    continue # no need to do anything

                intfs = IptablesUtil.interface_matcher_string_to_interface_list( value )

                if invert:
                    print "ERROR: invert not support on interface matcher"
                    continue
                orig_current_strings = current_strings
                current_strings = []
                # split current rules for each intf specified
                for i in range(0 , len(intfs) ):
                    matcherStr = " -m connmark --mark 0x%04X/0xFF00 " % (int(intfs[i]) << 8)
                    current_strings = current_strings + [ current + matcherStr for current in orig_current_strings ]

            if matcherType == "SRC_ADDR":
                if invert:
                    matcherStr = matcherStr + " ! "
                matcherStr = matcherStr + " --source %s " % value
                current_strings = [ current + matcherStr for current in current_strings ]

            if matcherType == "DST_ADDR":
                if invert:
                    matcherStr = matcherStr + " ! "
                matcherStr = matcherStr + " --destination %s " % value
                current_strings = [ current + matcherStr for current in current_strings ]

            if matcherType == "SRC_PORT":
                if invert:
                    matcherStr = matcherStr + " ! "
                value = value.replace("-",":").replace(" ","") # iptables uses colon to represent range not dash
                matcherStr = matcherStr + " -m multiport  --source-ports %s " % value
                if not hasProtocolMatcher:
                    # port explicitly means either TCP or UDP, since no protocol matcher has been specified, use "TCP,UDP" as the protocol matcher
                    current_strings = [ " --protocol udp " + current for current in current_strings ] + [ " --protocol tcp " + current for current in current_strings ]
                current_strings = [ current + matcherStr for current in current_strings ]

            if matcherType == "DST_PORT":
                if invert:
                    matcherStr = matcherStr + " ! "
                value = value.replace("-",":").replace(" ","") # iptables uses colon to represent range not dash
                matcherStr = matcherStr + " -m multiport --destination-ports %s " % value
                if not hasProtocolMatcher:
                    # port explicitly means either TCP or UDP, since no protocol matcher has been specified, use "TCP,UDP" as the protocol matcher
                    current_strings = [ " --protocol udp " + current for current in current_strings ] + [ " --protocol tcp " + current for current in current_strings ]
                current_strings = [ current + matcherStr for current in current_strings ]

            if matcherType == "DST_LOCAL":
                if invert:
                    matcherStr = matcherStr + " ! "
                matcherStr = matcherStr + " -m addrtype --dst-type local "
                current_strings = [ current + matcherStr for current in current_strings ]
                

        
        return current_strings;
        
