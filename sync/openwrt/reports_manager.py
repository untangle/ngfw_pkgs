import os
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar
from sync import nftables_util

# This class is responsible for managing the reports settings


class ReportsManager:
    def initialize(self):
        pass

    def preprocess_settings(self, settings):
        pass

    def validate_settings(self, settings):
        pass

    def create_settings(self, settings, prefix, delete_list, filename):
        print("%s: Initializing settings" % self.__class__.__name__)
        settings['reports'] = default_reports_settings()
        pass

    def sync_settings(self, settings, prefix, delete_list):
        pass


registrar.register_manager(ReportsManager())


def default_reports_settings():
    return {
        "entries": [{
            "uniqueId": "12341234",
            "name": "Example Report",
            "category": "Category",
            "description": "Report long description Report long description Report long description.",
            "displayOrder": 100,
            "readOnly": True,
            "type": "CHART",
            "rendering": {
                "units": "hits",
                "pieNumSlices": 10,
                "pieStyle": "PIE"
            }
        }]
    }
