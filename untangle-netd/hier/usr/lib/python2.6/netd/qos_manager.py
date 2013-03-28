import os
import sys
import subprocess
import datetime
import traceback
import re
from netd.network_util import NetworkUtil

# This class is responsible for writing /etc/untangle-netd/iptables-rules.d/790-qos
# and others based on the settings object passed from sync-settings.py
class QosManager:
    qosFilename = "/etc/untangle-netd/iptables-rules.d/790-qos"

    def find_priority( self, qosPriorities, priorityId ):
        for qosPriority in qosPriorities:
            if qosPriority.get('priorityId') == priorityId:
                return qosPriority
        return None

    def write_qos_hook( self, settings, prefix, verbosity ):

        if settings == None or settings.get('interfaces') == None or settings.get('interfaces').get('list') == None:
            return;
        if settings.get('qosSettings') == None:
            return;
        qosSettings = settings.get('qosSettings')
        interfaces = settings.get('interfaces').get('list')

        filename = prefix + self.qosFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        file.write("export QOS_ENABLED=%s" % ( "YES" if qosSettings.get('qosEnabled') else "NO" ) + "\n");

        space=""
        wans_string=""
        for intfSettings in interfaces:
            if intfSettings['configType'] == 'ADDRESSED' and intfSettings['isWan']:
                wans_string = wans_string + space + intfSettings['systemDev']
                space=" "
        file.write("export UPLINKS=\"%s\"" % wans_string + "\n")

        file.write("export DEFAULT_CLASS=%s" % str(qosSettings.get('defaultPriority')) + "\n");

        file.write("\n");

        if qosSettings.get('qosEnabled'):
            for intfSettings in interfaces:
                if intfSettings['configType'] == 'ADDRESSED' and intfSettings['isWan']:
                    file.write("export %s_DOWNLOAD_BANDWIDTH=%s" % (intfSettings['systemDev'], str(intfSettings['downloadBandwidthKbps'])) + "\n")
                    file.write("export %s_UPLOAD_BANDWIDTH=%s" % (intfSettings['systemDev'], str(intfSettings['uploadBandwidthKbps'])) + "\n")
            file.write("\n");
            for intfSettings in interfaces:
                if intfSettings['configType'] == 'ADDRESSED' and intfSettings['isWan']:
                    for classInt in range(1,8):
                        qosPriority = self.find_priority( qosSettings.get('qosPriorities').get('list'), classInt )
                        if qosPriority == None:
                            print "ERROR: Missing QoS class %i" % classInt
                            continue
                        file.write("export %s_CLASS%i_UPLOAD_RESERVED=%i" % (intfSettings['systemDev'], classInt, round(intfSettings['uploadBandwidthKbps']*qosPriority['uploadReservation']/100)) + "\n")
                        file.write("export %s_CLASS%i_UPLOAD_LIMIT=%i" % (intfSettings['systemDev'], classInt, round(intfSettings['uploadBandwidthKbps']*qosPriority['uploadLimit']/100)) + "\n")
                        file.write("export %s_CLASS%i_DOWNLOAD_RESERVED=%i" % (intfSettings['systemDev'], classInt, round(intfSettings['downloadBandwidthKbps']*qosPriority['downloadReservation']/100)) + "\n")
                        file.write("export %s_CLASS%i_DOWNLOAD_LIMIT=%i" % (intfSettings['systemDev'], classInt, round(intfSettings['downloadBandwidthKbps']*qosPriority['downloadLimit']/100)) + "\n")
                        file.write("\n");

        file.write("\n\n");

        file.write("export" + "\n")
        file.write("/home/dmorris/work/pkgs/untangle-netd/hier/usr/share/untangle-netd/bin/qos-service start" + "\n")
        file.write("\n\n");

        file.flush()
        file.close()

        os.system("chmod a+x %s" % filename)
        if verbosity > 0: print "QosManager: Wrote %s" % filename

        return


    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "QosManager: sync_settings()"
        
        self.write_qos_hook( settings, prefix, verbosity )

        return
