import re
import subprocess
from os.path import dirname, basename, isfile, join
import os

from support_diagnostics import Collector,CollectorResult
import support_diagnostics
class FilesystemCollector(Collector):

    platform_entries = {
        'openwrt': [ '/tmp/reports.db'],
        'debian': [ '/var/log', '/var/lib/postgresql', '/etc', '/usr/share/untangle' ]
    }

    """
    Get NGFW system information
    """
    def collect(self):
        results = []

        # Partition usage
        result = CollectorResult(self, "partition")

        partitions = {
            '/tmp': {
                'match': None,
                'blocks': None,
                # Either physical or filesystem
                'type': 'unknown'
            }
        }
        drive_type_map = {}
        # Fdisk is not installed for mfw, so parse partition table directly
        # to get all availble partitions including parent disks.
        with open('/proc/partitions') as file:
            for line in file.readlines():
                line = line.strip()
                fields = re.split(r'\s+',line)
                if len(line) == 0 or fields[0] == 'major' or fields[3] == 'loop0':
                    continue

                partition = fields[3]
                type = 'unknown'
                sys_block_name = '/sys/block/{name}'.format(name=partition)
                if os.path.isdir(sys_block_name):
                    # Attempt to determine partition type from the block link.
                    sys_block_name_target = os.readlink(sys_block_name)
                    if "usb" in sys_block_name_target:
                        drive_type_map[partition] = "usb"
                    elif "ata2" in sys_block_name_target:
                        drive_type_map[partition] = "cdrom"
                for p in drive_type_map:
                    # Inherit parent type
                    if partition.startswith(p):
                        type = drive_type_map[p]

                partitions["/dev/{partition}".format(partition=partition)] = {
                    'match': None,
                    'blocks': int(fields[2]),
                    'type': type
                }

        # Examine mounted file systems and map back to partitions.
        # The only "virtual" non-physical partition we care about is tmpfs
        proc = subprocess.Popen(['df','-T'], stdout=subprocess.PIPE)
        while True:
            line = proc.stdout.readline()
            if not line:
                break
            line = line.decode("ascii").rstrip()
            fields = re.split(r'\s+',line)
            if len(fields) > 5:
                mount_point = fields[0]
                if mount_point == 'tmpfs':
                    if fields[6] not in ['/tmp', '/dev/shm']:
                        continue
                    mount_point = "/tmp"
                if mount_point in partitions:
                    partitions[mount_point]['match'] = 'df'
                    partitions[mount_point]['type'] = fields[1]
                    partitions[mount_point]['used'] = int(fields[3]) * 1024
                    partitions[mount_point]['available'] = int(fields[4]) * 1024
                    partitions[mount_point]['mount'] = fields[6]
                    if 'size' not in partitions[mount_point]:
                        partitions[mount_point]['size'] = int(fields[2]) * 1024

        # Determine swap partition
        proc = subprocess.Popen(['swapon', "-s"], stdout=subprocess.PIPE)
        while True:
            line = proc.stdout.readline()
            if not line:
                break
            line = line.decode("ascii").rstrip()
            fields = re.split(r'\s+',line)
            if len(fields) > 3:
                mount_point = fields[0]
                if mount_point in partitions:
                    partitions[mount_point]['match'] = 'swapon'
                    partitions[mount_point]['type'] = 'swap'


        ## Remove partitions that are "super-partitions" that are otherwise accounted for.
        deletes = []
        for partition in partitions:
            if partitions[partition]['blocks'] == 1:
                # This appears to be an extended partition that is being used by something
                # else like swap.
                deletes.append(partition)
                continue
            for partition_delete in partitions:
                if partition != partition_delete:
                    if partitions[partition]['match'] is None:
                        if partition_delete.startswith(partition):
                            # Partition name contains this partition, so likely a case of
                            # drive like sda1 appearing in sda
                            if partition not in deletes:
                                deletes.append(partition)
        for delete in deletes:
            del partitions[delete]

        result.output = partitions
        results.append(result)

        # Entry usage
        result = CollectorResult(self, "entries")
        entries = {}
        platform = support_diagnostics.Configuration.platform
        if platform in self.platform_entries:
            for entry in self.platform_entries[support_diagnostics.Configuration.platform]:
                # openwrt does not have -b option.
                proc = subprocess.Popen(['du', "-s", entry], stdout=subprocess.PIPE)
                while True:
                    line = proc.stdout.readline()
                    if not line:
                        break
                    line = line.decode("ascii").rstrip()
                    fields = re.split(r'\s+',line)
                    # convert to bytes
                    entries[entry] = int(fields[0]) * 1024

        result.output = entries
        results.append(result)

        return results