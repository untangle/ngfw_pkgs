import re

from support_diagnostics import Analyzer, AnalyzerResult, AnalyzerResultSeverityPass, AnalyzerResultSeverityWarn, AnalyzerResultSeverityFail
from support_diagnostics import Configuration, ImportModules

ImportModules.import_all(globals(), "collectors")

class CloudDatabaseAnalyzer(Analyzer):
    """
    Get apt sources
    """
    categories = ['reports', 'cloud']
    collector = LogreadCollector

    error_re = re.compile("Error calling client.Do: Post https://database.untangle.com/v1/put\?source=.+&type=db&queueName=mfw_events: net/http: request canceled \((.+)\)")

    heading = "Cloud Database"
    results = {
        "client_timeout": AnalyzerResult(
                severity=AnalyzerResultSeverityWarn,
                summary="Unable to send {instances} message to https://database.untangle.com",
                detail="This could be an issue with the client or the server"
        ),
        "pass": AnalyzerResult(
                severity=AnalyzerResultSeverityPass,
                summary="No issues detected with cloud communication"
        ),
    }

    def analyze(self, collector_results):
        results = []

        data_results = {}
        for collector_result in collector_results:
            for line in collector_result.output:
                match = self.error_re.search(line)
                if match is not None:
                    reason = None
                    if "Client.Timeout exceeded" in match.group(1):
                        reason = "client_timeout"
                    
                    if not reason in data_results:
                        data_results[reason] = {
                            'instances': 0
                        }
                    data_results[reason]['instances'] = data_results[reason]['instances'] + 1
                                        
        for key in data_results:
            result = CloudDatabaseAnalyzer.results[key].copy()
            result.analyzer = self
            result.format(data_results[key])
            results.append(result)

        if len(results) == 0:
            result = CloudDatabaseAnalyzer.results["pass"].copy()
            result.analyzer = self
            results.append(result)

        return results
