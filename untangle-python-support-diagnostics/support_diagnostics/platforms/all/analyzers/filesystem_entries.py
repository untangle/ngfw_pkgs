import os
import re

import urllib.parse

from support_diagnostics import Analyzer, AnalyzerResult, AnalyzerResultSeverityPass, AnalyzerResultSeverityWarn, AnalyzerResultSeverityFail
from support_diagnostics import Configuration, ImportModules
import support_diagnostics.utilities

ImportModules.import_all(globals(), "collectors")
class FilesystemEntriesAnalyzer(Analyzer):
    """
    Analyze file system entries for size.
    """
    order = 0
    
    heading = "Top File/Directory Usage"
    categories = ["os"]
    collector = FilesystemCollector

    def analyze(self, collector_results):
        results = []
        result_fields = {}
        format_fields = {}
        severity=None
        for collector_result in collector_results:
            if collector_result.source == "entries":
                for entry in collector_result.output:
                    result = AnalyzerResult(severity=AnalyzerResultSeverityPass,other_results={ "{severity}" : '{type:<12}{entry:<20} {size}'})
                    format_fields = {
                        'entry': entry,
                        'size': support_diagnostics.utilities.SizeConversion.to_human(collector_result.output[entry])
                    }
                    if os.path.isfile(entry):
                        format_fields['type'] = "file";
                    else:
                        format_fields['type'] = "directory";
                    result.collector_result = collector_result
                    result.analyzer = self
                    result.format(format_fields)
                    results.append(result)


        return results