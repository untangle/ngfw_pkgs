import re

import urllib.parse

from support_diagnostics import Analyzer, AnalyzerResult, AnalyzerResultSeverityPass, AnalyzerResultSeverityWarn, AnalyzerResultSeverityFail
from support_diagnostics import Configuration, ImportModules

ImportModules.import_all(globals(), "collectors")

class UpdateSourceAnalyzer(Analyzer):
    """
    Analyze apt sources
    """
    categories = ["updates"]
    collector = [SystemCollector,
    {
            'collector': FilesCollector,
            'arguments': {
                'id': 'apt_sources',
                'path': ['/etc/apt/*.list', '/etc/apt/sources.list.d/*.list']
            }
    }]

    deb_re = re.compile('^(?P<type>deb[^\s]*)\s+(\[.+\]\s+|)(?P<url>[^\s+]+)\s+(?P<distribution>[^\s+]+)(.*)')

    distribution_prefix = "stable-"

    heading = "Debian apt sources"
    results = {
        "public": AnalyzerResult(
                severity=AnalyzerResultSeverityPass,
                summary="Pointing to production package server '{host}'",
                detail="All customer units should be using this package server."
        ),
        "internal": AnalyzerResult(
                severity=AnalyzerResultSeverityWarn,
                summary="Pointing to development package server '{host}'",
                detail="For internal Untangle corporate units this is acceptable, but not for customer units.",
                recommendation="If this is a customer facing system, change the host to updates.untangle.com"
        ),
        "unknown": AnalyzerResult(
                severity=AnalyzerResultSeverityFail,
                summary="Pointing to unknown server '{host}'",
                detail="No customer or corporate units should be pointing to an unknown package server",
                recommendation=[
                    'From file:',
                    '{collector_result_source}:',
                    'delete entry:',
                    '{entry}'
                ]
        ),
        "bad_distribution": AnalyzerResult(
                severity=AnalyzerResultSeverityFail,
                summary="Distribution is incorrect '{distribution}'",
                detail="Incorrect distribution affects downloading correct updates",
                recommendation=[
                    'In file:',
                    '{collector_result_source}:',
                    'modify entry:',
                    '{entry}',
                    'to:',
                    'deb http://{uid}:untangle@updates.untangle.com/public/buster {distribution_prefix}{pubversion} main non-free'
                ]
        ),
        "none_found": AnalyzerResult(
                severity=AnalyzerResultSeverityFail,
                summary="No active sources found",
                detail="This unit is in an un-upgradable state",
                recommendation=[
                    'In file:',
                    '/etc/apt/sources.list.d/untangle.list:',
                    'Add entry:',
                    'deb http://{uid}:untangle@updates.untangle.com/public/buster {distribution_prefix}{pubversion} main non-free'
                ]
        )
    }

    def analyze(self, collector_results):
        uid = "0000-0000-0000-0000"
        pubversion = "0"

        results = []

        # Get uid, version
        for collector_result in collector_results:
            if collector_result.collector.id == "system":
                if collector_result.source == 'uid':
                    uid = collector_result.output[0]
                elif collector_result.source == 'pubversion':
                    pubversion = collector_result.output[0].replace('.','')

        for collector_result in collector_results:
            if collector_result.collector.id == "apt_sources":
                for line in collector_result.output:
                    if line.startswith('#') or len(line) == 0:
                        # Ignore comments, blank lines.
                        continue
                    match = self.deb_re.search(line)
                    if match is not None:
                        url = match.group("url")
                        parsed_url = urllib.parse.urlsplit(url)

                        result = None
                        if parsed_url.hostname == 'updates.untangle.com':
                            # Correct target; how does everything else look?
                            if match.group("distribution") != '{distribution_prefix}{pubversion}'.format(distribution_prefix=UpdateSourceAnalyzer.distribution_prefix,pubversion=pubversion):
                                result = UpdateSourceAnalyzer.results["bad_distribution"].copy()
                            else:
                                # All good!
                                result = UpdateSourceAnalyzer.results["public"].copy()
                        elif parsed_url.hostname == 'package-server.untangle.int':
                            # Legit for internal, almost certainly not for customers.
                            result = UpdateSourceAnalyzer.results["internal"].copy()
                        else:
                            # Not legit at all.
                            result = UpdateSourceAnalyzer.results["unknown"].copy()
                        
                        result.collector_result = collector_result
                        result.analyzer = self
                        result.format({
                            "entry": line,
                            "host": parsed_url.hostname,
                            "distribution": match.group("distribution"),
                            'uid': uid,
                            "distribution_prefix": UpdateSourceAnalyzer.distribution_prefix,
                            'pubversion': pubversion
                        })
                        results.append(result)
        
        if len(results) == 0:
            # Inexplicably, no active entrie found
            result = UpdateSourceAnalyzer.results["none_found"].copy()
            result.analyzer = self
            result.format({
                'uid': uid,
                "distribution_prefix": UpdateSourceAnalyzer.distribution_prefix,
                'pubversion': pubversion
            })
            results.append(result)

        return results