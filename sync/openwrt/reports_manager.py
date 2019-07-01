"""This class is responsible for managing the reports settings"""
# pylint: disable=unused-argument
from sync import registrar

class ReportsManager:
    """ReportsManager manages the system settings"""
    def initialize(self):
        """initialize this module"""
        pass

    def sanitize_settings(self, settings):
        """sanitizes settings"""
        pass

    def validate_settings(self, settings):
        """validates settings"""
        pass

    def create_settings(self, settings, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        settings['reports'] = default_reports_settings()
        settings['dashboard'] = default_dashboard_settings()

    def sync_settings(self, settings, prefix, delete_list):
        """syncs settings"""
        pass


registrar.register_manager(ReportsManager())


def default_reports_settings():
    """default reports settings"""
    return {
        "entries": []
    }

def default_dashboard_settings():
    """default dashboard settings"""

# {
#            "name": "Map Distribution",
#            "isReport": False,
#            "interval": 30
# }
# {
#            "name": "Top Clients by Bandwidth",
#            "interval": 30
# }
# {
#            "name": "Top Clients Bandwidth by Time",
#            "interval": 30
# }
# {
#            "name": "Top Server Ports by Session Count",
#            "interval": 30
# }
# {
#            "name": "Top Clients by Session Count",
#            "interval": 30
# }
    return {
        "widgets": [{
            "name": "Server Info",
            "isReport": False,
            "interval": 0
        }, {
            "name": "CPU Load",
            "isReport": False,
            "interval": 0
        }, {
            "name": "Network Layout",
            "isReport": False,
            "interval": 0
        }, {
            "name": "Interface Usage",
            "interval": 30
        }, {
            "name": "Interface Average Active Latency",
            "interval": 30
        }, {
            "name": "Top Applications by Bandwidth",
            "interval": 30
        }, {
            "name": "Top Applications Bandwidth by Time",
            "interval": 30
        }, {
            "name": "Session Count Summary",
            "interval": 30
        }]
    }
