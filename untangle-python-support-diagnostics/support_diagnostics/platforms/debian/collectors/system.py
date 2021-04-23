import subprocess
from os.path import dirname, basename, isfile, join

from support_diagnostics import Collector,CollectorResult

class SystemCollector(Collector):
    id = "system"

    hostname_file_name = "/proc/sys/kernel/hostname"
    version_file_name = "/usr/share/untangle/lib/untangle-libuvm-api/VERSION"
    pub_version_file_name = "/usr/share/untangle/lib/untangle-libuvm-api/PUBVERSION"
    uid_file_name = "/usr/share/untangle/conf/uid"
    serial_number_file_name = "/sys/devices/virtual/dmi/id/product_serial"
    appliance_model_file_name = "/usr/share/untangle/conf/appliance-model"

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
        file = open(SystemCollector.version_file_name, "r")
        result.output = [line.rstrip() for line in file.readlines()]
        file.close()
        results.append(result)

        # Pub version version
        result = CollectorResult(self, "pubversion")
        file = open(SystemCollector.pub_version_file_name, "r")
        result.output = [line.rstrip() for line in file.readlines()]
        file.close()
        results.append(result)

        # Appliance model
        if isfile(SystemCollector.appliance_model_file_name):
            result = CollectorResult(self, "model")
            file = open(SystemCollector.appliance_model_file_name, "r")
            result.output = [line.rstrip() for line in file.readlines()]
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