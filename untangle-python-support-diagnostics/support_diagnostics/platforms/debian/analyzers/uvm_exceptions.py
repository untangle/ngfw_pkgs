import re

from support_diagnostics import Analyzer, AnalyzerResult, AnalyzerResultSeverityPass, AnalyzerResultSeverityWarn, AnalyzerResultSeverityFail
from support_diagnostics import ImportModules

ImportModules.import_all(globals(), "collectors")

class UvmExceptionsAnalyzer(Analyzer):
    # """
    # Process uvm logs for exceptions
    # """
    categories = ["uvm"]
    collector = {
            'collector': FilesCollector,
            'arguments': {
                'id': 'uvm_log',
                'path': '/var/log/uvm/*',
                'ignore': 'packages.log'
            }
    }

    exception_begin_re = re.compile('\[([^]]+)\] <> ([^\s]+)\s+Exception in ([^\s]+)')
    exception_any_re = re.compile('((com\.|java.*\.|org\.).+)')
    exception_untangle_re = re.compile('(com\.untangle\..+)\(([^:]+):(\d+)\)')

    null_pointer_exception = "java.lang.NullPointerException"
    general_exception = "Exception:"

    heading = "untangle-vm exceptions"
    results = {
        "unknown_exception": AnalyzerResult(
                severity=AnalyzerResultSeverityFail,
                summary="untangle-vm unknown exception detected",
                detail=[
                    'The following exception was found:',
                    '{path} at line {line_number}',
                    'the following exception was encountered {instances} times:'
                    '{last_error}'
                ],
                recommendation="Send this information to Untangle engineering."
        ),
        "known_exception": AnalyzerResult(
                severity=AnalyzerResultSeverityWarn,
                summary="untangle-vm known exception detected",
                detail=[
                    'The following exception was found:',
                    '{path} at line {line_number}',
                    'the following exception was encountered {instances} times:',
                    '{last_error}'
                ],
                recommendation="Untangle engineering is likely aware of this but should review."
        )
    }

    def analyze(self, collector_results):
        results = []

        update_error_codes = {}
        timeouts = 0
        total = 0

        exceptions = {}

        for collector_result in collector_results:
            exception = None

            last_line = None
            for line in collector_result.output:
                match = UvmExceptionsAnalyzer.exception_begin_re.search(line)
                if match is not None:
                    # We've found an uncaught exception.
                    exception = {
                        'last_error': None,
                        'result': UvmExceptionsAnalyzer.results["unknown_exception"]
                    }
                    last_line = line
                    continue

                if exception is None:
                    if UvmExceptionsAnalyzer.null_pointer_exception in line:
                        # We want to know about null pointer exceptions.
                        exception = {
                            'last_error': None,
                            'result': UvmExceptionsAnalyzer.results["unknown_exception"]
                        }
                        # DON'T continue; use this as our last_error
                    elif UvmExceptionsAnalyzer.general_exception in line:
                        # A caught exception.  Not as severe.
                        exception = {
                            'last_error': None,
                            'result': UvmExceptionsAnalyzer.results["known_exception"]
                        }
                        # DON'T continue; use this as our last_error

                if exception is not None:
                    if exception['last_error'] is None:
                        # Next line is the error.
                        match = UvmExceptionsAnalyzer.exception_any_re.search(line)
                        if match is not None:
                            exception['last_error'] = match.group(1)
                        else:
                            exception['last_error'] = line

                    match = UvmExceptionsAnalyzer.exception_untangle_re.search(line)
                    if match is not None:
                        # Everything between the error and our code is likely just
                        # noise; we want to know where we used it.
                        exception['path'] = match.group(1)
                        exception['file'] = match.group(2)
                        exception['line_number'] = match.group(3)
                        exception['instances'] = 0

                        exception_path = "{path}:{line_number}".format(path=exception['path'], line_number=exception['line_number'])
                        exception['path_key'] = exception_path
                        if exception_path not in exceptions:
                            exceptions[exception_path] = exception
                        exceptions[exception_path]['instances'] += 1
                        exception = None

        # Sort by instances, reverse order.  Unlike other stats, we want all of these!
        for exception in sorted(exceptions.values(), key=lambda d: d['instances'], reverse=True):
            key = exception['path_key']
            result = exception['result'].copy()
            result.collector_result = collector_result
            result.analyzer = self
            result.format(exceptions[key])
            results.append(result)

        return results