import os
import re

from support_diagnostics import Analyzer, AnalyzerResult, AnalyzerResultSeverityPass, AnalyzerResultSeverityWarn, AnalyzerResultSeverityFail
from support_diagnostics import Configuration, ImportModules
import support_diagnostics.utilities

ImportModules.import_all(globals(), "collectors")

class ProcessMemoryAnalyzer(Analyzer):
    """
    Analyze memory usage
    """
    order = 0
    
    max_records = 10
    heading = "Top 10 Process Memory Usage"
    categories = ["os"]
    collector = [ ProcessesCollector, MemoryCollector]

    def analyze(self, collector_results):
        results = []

        memory_total = None
        for result in filter(lambda r: r.source == "memory", collector_results):
            if "memtotal" in result.output:
                memory_total = result.output["memtotal"]

        memory_sorted_process_results = sorted(filter(lambda r: r.source == "process" and 'vmrss' in r.output['status'], collector_results), key=lambda d: d.output['status']['vmrss'], reverse=True)
        for process_result in memory_sorted_process_results[:ProcessMemoryAnalyzer.max_records]:
            result = AnalyzerResult(severity=AnalyzerResultSeverityPass,other_results={ "{severity}" : '{cmdline:<55} {size:<11} {percent:<.2f}%'})
            cmdline_len = len(process_result.output['cmdline'])
            format_fields = {
                'cmdline': '{process}{elide}'.format(process=process_result.output['cmdline'][:50], elide='...' if cmdline_len > 50 else ''),
                'size': support_diagnostics.utilities.SizeConversion.to_human(process_result.output['status']['vmrss']),
                'percent': round(process_result.output['status']['vmrss'] / memory_total * 100, 2)
            }
            result.collector_result = process_result
            result.analyzer = self
            result.format(format_fields)
            results.append(result)

        return results