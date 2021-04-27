import glob
import gzip
from os.path import dirname, basename, isfile, join

from support_diagnostics import Collector,CollectorResult

class FilesCollector(Collector):
    """
    Get file entries, handling compressed files as well as plain text.
    """
    id = "files"
    path = "/tmp/*"
    ignores = None

    def __init__(self, id=None, path=None, ignore=None):
        if id is not None:
            self.id = id

        if path is not None:
            if type(path) is not list:
                path = [path]
            self.path = path

        if ignore is not None:
            if type(ignore) is not list:
                ignore = [ignore]
            self.ignores = ignore

    def collect(self):
        results = []

        file_names = []
        for path in self.path:
            file_names.extend(glob.glob(path))
        
        for file_name in file_names:

            # Look for substrings of filenmes to ignore.
            ignore_file_name = False
            if self.ignores is not None:
                for ignore in self.ignores:
                    if ignore in file_name:
                        ignore_file_name = True
                        break
            if ignore_file_name is True:
                continue

            print(".", end='', flush=True)
            result = CollectorResult(self, file_name)
            if file_name.endswith(".gz"):
                result.output = []
                file = gzip.open(file_name, "rb")
                try:
                    for line in file.readlines():
                        result.output.append(line.decode("ascii").rstrip())
                except:
                    # !! Would be better to have a method or super class to read and handle both gz and non gz
                    pass
            else:
                file = open(file_name, "r")
                result.output = [line.rstrip() for line in file.readlines()]
            file.close()
            
            results.append(result)

        return results