import os
import re

from support_diagnostics import Analyzer, AnalyzerResult, AnalyzerResultSeverityPass, AnalyzerResultSeverityWarn, AnalyzerResultSeverityFail
from support_diagnostics import Configuration, ImportModules
import support_diagnostics.utilities

ImportModules.import_all(globals(), "collectors")
class ProcessCpuAnalyzer(Analyzer):
    """
    Analyze CPU usage
    """
    order = 0
    
    max_records = 10
    heading = "Top 10 Process CPU Usage"
    categories = ["os"]
    collector = ProcessesCollector

    def analyze(self, collector_results):
        results = []

        cpu_sorted_process_results = sorted(filter(lambda r: r.source == "process" and '%cpu' in r.output['top'], collector_results), key=lambda d: d.output['top']['%cpu'], reverse=True)
        for process_result in cpu_sorted_process_results[:ProcessCpuAnalyzer.max_records]:
            result = AnalyzerResult(severity=AnalyzerResultSeverityPass,other_results={ "{severity}" : '{cmdline:<55} {percent}%'})
            if 'cmdline' in process_result.output and process_result.output['cmdline'] != '':
                cmdline = process_result.output['cmdline']
            else:
                cmdline = process_result.output['status']['name']
            cmdline_len = len(cmdline)
            format_fields = {
                'cmdline': '{process}{elide}'.format(process=cmdline[:50], elide='...' if cmdline_len > 50 else ''),
                'percent': process_result.output['top']['%cpu']
            }
            result.collector_result = process_result
            result.analyzer = self
            result.format(format_fields)
            results.append(result)

        return results