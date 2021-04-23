import re
import glob
import subprocess
from os.path import dirname, basename, isfile, join
import os

from support_diagnostics import Collector,CollectorResult
import support_diagnostics.utilities
import support_diagnostics

class MemoryCollector(Collector):
    """
    Collect system memmory information
    """
    meminfo_file_name = "/proc/meminfo"
    
    def collect(self):
        results = []

        file = open(MemoryCollector.meminfo_file_name, "r")
        status = {}
        for line in file.readlines():
            fields = line.strip().split(':')
            key = fields[0].strip().lower()
            value = ':'.join(fields[1:]).strip()
            if support_diagnostics.utilities.SizeConversion.is_human(value):
                value = support_diagnostics.utilities.SizeConversion.from_human(value)
            status[key] = value
        file.close()

        result = CollectorResult(self, 'memory')
        result.output = status
        results.append(result)

        return results