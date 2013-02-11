import os
import sys
import subprocess
import datetime
import traceback
import string

# This class is a utility class with utility functions providing
# useful tools for dealing with iptables rules
class IptablesUtil:

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

            str = ""
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
                    str = str + " --protocol %s " % string.lower(protos[i])
                    current_strings = current_strings + [ str + current for current in orig_current_strings ]

            if matcherType == "SRC_INTF":
                intfs = value.split(",")
                if invert:
                    print "ERROR: invert not support on interface matcher"
                    continue
                orig_current_strings = current_strings
                current_strings = []
                # split current rules for each intf specified
                for i in range(0 , len(intfs) ):
                    str = " -m connmark --mark 0x%04X/0x00FF " % int(intfs[i])
                    current_strings = current_strings + [ current + str for current in orig_current_strings ]

            if matcherType == "DST_INTF":
                intfs = value.split(",")
                if invert:
                    print "ERROR: invert not support on interface matcher"
                    continue
                orig_current_strings = current_strings
                current_strings = []
                # split current rules for each intf specified
                for i in range(0 , len(intfs) ):
                    str = " -m connmark --mark 0x%04X/0xFF00 " % (int(intfs[i]) << 8)
                    current_strings = current_strings + [ current + str for current in orig_current_strings ]

            if matcherType == "SRC_ADDR":
                if invert:
                    str = str + " ! "
                str = str + " --source %s " % value
                current_strings = [ current + str for current in current_strings ]

            if matcherType == "DST_ADDR":
                if invert:
                    str = str + " ! "
                str = str + " --destination %s " % value
                current_strings = [ current + str for current in current_strings ]

            if matcherType == "SRC_PORT":
                if invert:
                    str = str + " ! "
                str = str + " --source-port %s " % value
                if not hasProtocolMatcher:
                    # port explicitly means either TCP or UDP, since no protocol matcher has been specified, use "TCP,UDP" as the protocol matcher
                    current_strings = [ " --protocol udp " + current for current in current_strings ] + [ " --protocol tcp " + current for current in current_strings ]
                current_strings = [ current + str for current in current_strings ]

            if matcherType == "DST_PORT":
                if invert:
                    str = str + " ! "
                str = str + " --destination-port %s " % value
                if not hasProtocolMatcher:
                    # port explicitly means either TCP or UDP, since no protocol matcher has been specified, use "TCP,UDP" as the protocol matcher
                    current_strings = [ " --protocol udp " + current for current in current_strings ] + [ " --protocol tcp " + current for current in current_strings ]
                current_strings = [ current + str for current in current_strings ]

            if matcherType == "DST_LOCAL":
                if invert:
                    str = str + " ! "
                str = str + " -m addrtype --dst-type local "
                current_strings = [ current + str for current in current_strings ]
                

        
        return current_strings;
        
