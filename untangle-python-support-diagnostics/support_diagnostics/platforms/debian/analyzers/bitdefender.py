import re

from support_diagnostics import Analyzer, AnalyzerResult, AnalyzerResultSeverityPass, AnalyzerResultSeverityWarn, AnalyzerResultSeverityFail
from support_diagnostics import ImportModules

ImportModules.import_all(globals(), "collectors")

class BitdefenderAnalyzer(Analyzer):
    # """
    # Analyze BitDefender logs
    # """
    categories = ["mail","virus"]
    collector = {
            'collector': FilesCollector,
            'arguments': {
                'id': 'bitdefender_log',
                'path': '/var/log/bdamserver.*'
            }
    }

    update_error_result_re = re.compile('ERROR: The anti-malware database update failed, error Unknown error \((.+)\)')

    heading = "BitDefender Log"
    results = {
        "update_error": AnalyzerResult(
                severity=AnalyzerResultSeverityFail,
                summary="BitDefender update errors detected",
                detail=[
                    'The update error code {update_error_code} was detected {total} times.',
                    'Many of these may indicate the following issues:',
                    'A web proxy is in front of the system and preventing updates from occuring properly.'
                ],
                recommendation="Perform a tcpdump with -A to the host bd.untangle.com to watch for traffic and look for possibility of web proxy."
        )
    }

    def analyze(self, collector_results):
        results = []

        update_error_codes = {}
        timeouts = 0
        total = 0
        for collector_result in collector_results:
            for line in collector_result.output:
                match = BitdefenderAnalyzer.update_error_result_re.search(line)
                # print(match)
                if match is not None:
                    update_error_code = match.group(1)
                    if update_error_code not in update_error_codes:
                        update_error_codes[update_error_code] = 0
                    update_error_codes[update_error_code] += 1

        update_error_code_keys = update_error_codes.keys()
        if len(update_error_code_keys) > 0:
            for key in update_error_code_keys:
                result = BitdefenderAnalyzer.results["update_error"].copy()
                result.collector_result = collector_result
                result.analyzer = self
                result.format({
                    "update_error_code": update_error_code,
                    "total": total,
                })
                results.append(result)
        return results