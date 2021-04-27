import re

class SizeConversion():

    human_re = re.compile('^(\d)+\s*(|k|m|g|t|p|e|z|y)(b)$',re.IGNORECASE)

    def is_human(value):
        matches = SizeConversion.human_re.search(value)
        if matches is not None:
            return True
        return False

    def from_human(size):
        """
        Convert a human readable value like 20G to 21474836480
        """
        size = size.upper()
        result = 0
        size_name = ("B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB")
        match = re.search('([\d+\.]+)\s*(.+)', size)
        if match is not None:
            number = float(match.group(1))
            unit = match.group(2).upper()
            if not unit.endswith('B'):
                unit = unit + 'B'
            if unit in size_name:
                factor = 1024 ** size_name.index(unit)
                result = number * factor
        return int(result)

    def to_human(size, decimal_places=2):
        for unit in [ 'B', 'KB', 'MB', 'GB', 'TB', 'PB']:
            if size < 1024.0 or unit == 'PB':
                break
            size /= 1024.0
        return f"{size:.{decimal_places}f} {unit}"
