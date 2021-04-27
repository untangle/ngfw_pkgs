import re

from support_diagnostics import Analyzer, AnalyzerResult, AnalyzerResultSeverityPass, AnalyzerResultSeverityWarn, AnalyzerResultSeverityFail
from support_diagnostics import ImportModules

ImportModules.import_all(globals(), "collectors")

class SpamBlockerAnalyzer(Analyzer):
    # """
    # Analyze spam logs
    # """
    categories = ["mail"]
    collector = {
            'collector': FilesCollector,
            'arguments': {
                'id': 'mail_log',
                'path': '/var/log/mail.*'
            }
    }

    spam_result_re = re.compile('spamd: result: ([^\s]+) ([^\s]+) - ([^\s]+)')
    spam_test_time_limit_exceeded = "TIME_LIMIT_EXCEEDED"

    heading = "Spam Blocker Mail Log"
    results = {
        "timeout": AnalyzerResult(
                severity=AnalyzerResultSeverityWarn,
                summary="Spam processing timeouts detected",
                detail=[
                    '{timeouts} msgs (of {total} msgs) matched TIME_LIMIT_EXCEEDED result.',
                    'This may point to a DNS resolver that limits queries which can cause incomplete spam analysis.'
                ],
                recommendation="Consider changing WAN resolver to a public resolver like 8.8.8.8"
        )
    }

    def analyze(self, collector_results):
        results = []

        timeouts = 0
        total = 0
        for collector_result in collector_results:
            for line in collector_result.output:
                match = self.spam_result_re.search(line)
                if match is not None:
                    tests = match.group(3).split(',')
                    total = total + 1
                    if self.spam_test_time_limit_exceeded in tests:
                        timeouts = timeouts + 1

        if timeouts > 0:
            result = SpamBlockerAnalyzer.results["timeout"].copy()
            result.collector_result = collector_result
            result.analyzer = self
            result.format({
                "timeouts": timeouts,
                "total": total,
            })
            results.append(result)
        return results