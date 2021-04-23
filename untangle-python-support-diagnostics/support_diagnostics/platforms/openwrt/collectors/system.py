import subprocess
from os.path import dirname, basename, isfile, join

from support_diagnostics import Collector,CollectorResult

class SystemCollector(Collector):
    id = "system"

    os_release_file_name = "/etc/os-release"
    version_key = "VERSION"
    uid_file_name = "/etc/config/uid"
    hostname_file_name = "/proc/sys/kernel/hostname"
    serial_number_file_name = "/etc/config/serial"

    """
    Get NGFW system information
    """
    def collect(self):
        results = []

        # Hostname
        result = CollectorResult(self, "hostname")
        file = open(SystemCollector.hostname_file_name, "r")
        result.output = [line.rstrip() for line in file.readlines()]
        file.close()
        results.append(result)

        # Product version
        result = CollectorResult(self, "version")
        file = open(SystemCollector.os_release_file_name, "r")
        for line in file.readlines():
            if line.startswith(SystemCollector.version_key):
                version = line.rstrip().split('=')[1].replace('"','')
                result.output = [version]
        file.close()
        results.append(result)

        # Uid
        result = CollectorResult(self, "uid")
        file = open(SystemCollector.uid_file_name, "r")
        result.output = [line.rstrip() for line in file.readlines()]
        file.close()
        results.append(result)

        # Serial
        result = CollectorResult(self, "serial")
        file = open(SystemCollector.serial_number_file_name, "r")
        result.output = [line.rstrip() for line in file.readlines()]
        file.close()
        results.append(result)

        # Hardware architecture
        result = CollectorResult(self, "arch")
        proc = subprocess.Popen(['uname', '-m'], stdout=subprocess.PIPE)
        while True:
            line = proc.stdout.readline()
            if not line:
                break
            result.output = [line.decode("ascii").rstrip()]
        results.append(result)

        return results