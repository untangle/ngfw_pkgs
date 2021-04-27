import re

from support_diagnostics import Analyzer, AnalyzerResult, AnalyzerResultSeverityPass, AnalyzerResultSeverityWarn, AnalyzerResultSeverityFail
from support_diagnostics import Configuration, ImportModules

ImportModules.import_all(globals(), "collectors")

class SystemAnalyzer(Analyzer):
    """
    Get apt sources
    """
    order = 0
    
    heading = "System Information"
    categories = ["system"]
    collector = SystemCollector

    results = {
        "unsupported_arch": AnalyzerResult(
                severity=AnalyzerResultSeverityWarn,
                summary="Unsupported architecture",
                detail="Software updates are not supported for this archiecture",
                recommendation="Reinstall using 64 bit",
                other_results={
                    'architecture': '{arch}'
                }
        )
    }

    def analyze(self, collector_results):
        results = []
        result_fields = {}
        format_fields = {}
        severity=None
        for collector_result in collector_results:
            if collector_result.source in ["hostname", 'version', 'uid', 'serial', 'model']:
                result_fields = {
                    collector_result.source: '{{{source}}}'.format(source=collector_result.source)
                }
                format_fields[collector_result.source] = collector_result.output[0]

                result = AnalyzerResult(severity=severity, other_results=result_fields)
                result.collector_result = collector_result
                result.analyzer = self
                result.format(format_fields)
                results.append(result)

            elif collector_result.source == "arch":
                arch_result_fields = {
                    'architecture': '{arch}'
                }
                system_arch = collector_result.output[0]
                # system_arch = 'armv7l'
                arch = None

                result = None
                if system_arch == "x86_64":
                    arch = "64 bit x86"
                    result = AnalyzerResult(other_results=arch_result_fields)
                else:
                    result = self.results['unsupported_arch'].copy()
                    if "86" in system_arch:
                        arch = "32 bit x86"
                    elif "arm" in system_arch:
                        arch = "ARM"
                
                format_fields['arch'] = arch
                result.collector_result = collector_result
                result.analyzer = self
                result.format(format_fields)
                results.append(result)
        
        return results