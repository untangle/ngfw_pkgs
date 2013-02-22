import os
import sys
import subprocess
import datetime
import traceback
import re
from netd.network_util import NetworkUtil

# This class is responsible for writing 
# based on the settings object passed from sync-settings.py
class DnsMasqManager:
    
    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "DnsMasqManager: sync_settings()"
        
        return
