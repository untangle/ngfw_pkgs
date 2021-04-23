import re
import glob
import subprocess
from os.path import dirname, basename, isfile, join
import os

from support_diagnostics import Collector,CollectorResult
import support_diagnostics.utilities
import support_diagnostics

class ProcessesCollector(Collector):
    """
    Collect memmory from running processes
    """
    top_cpu_column_name = '%CPU'
    top_pid_column_name= 'PID'

    process_id_re = re.compile('.*\/(\d+)$')

    process_cmdline_name = "/proc/{process_id}/cmdline"
    process_status_name = "/proc/{process_id}/status"
    
    def collect(self):
        results = []
        # Get CPU usage information
        proc = subprocess.Popen(['top','-bn1'], stdout=subprocess.PIPE)

        pid_top = {}
        column_names = None
        while True:
            line = proc.stdout.readline()
            if not line:
                break
            line = line.decode("ascii").rstrip()

            if column_names is None:
                # Look for top header columns to get index for pid and cpu
                if ProcessesCollector.top_cpu_column_name in line:
                    column_names = line.lower().split()
                continue

            fields = line.split()
            if len(fields) == 0:
                continue

            top = {}
            for index, key in enumerate(column_names):
                value = fields[index]
                if value.endswith('%'):
                    # Remove percent sign
                    value = value[:-1]
                top[key] = value
            pid_top[fields[0]] = top

        # Get procsss-specific information
        for process_id in glob.glob("/proc/*"):
            matches = ProcessesCollector.process_id_re.search(process_id)
            if matches is None:
                continue
            process_id = matches.group(1)

            try:
                result = CollectorResult(self, 'process')
                file = open(ProcessesCollector.process_status_name.format(process_id=process_id), "r")
                status = {}
                for line in file.readlines():
                    fields = line.strip().split(':')
                    key = fields[0].strip().lower()
                    value = ':'.join(fields[1:]).strip()
                    if support_diagnostics.utilities.SizeConversion.is_human(value):
                        value = support_diagnostics.utilities.SizeConversion.from_human(value)
                    status[key] = value
                file.close()

                cmdline = open(ProcessesCollector.process_cmdline_name.format(process_id=process_id), "rb").read().replace(b'\0',b' ').decode()

                process_result = {
                    'id': process_id,
                    'cmdline': cmdline,
                    'status': status,
                    'top': pid_top[process_id]
                }

                result.output = process_result
                results.append(result)
            except:
                # Process gone, so we can ignore.
                pass

        return results