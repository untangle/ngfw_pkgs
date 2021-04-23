import json
# import fcntl
# import termios
# import struct
import sys

from support_diagnostics.output import Output

class JsonOutput(Output):
    json_encoding_types = []
# dict
# list
# str
# int
# float
# True    

    def to_json(obj):
        print("to_json")
        print(obj)
        print(type(obj).__class__.__name__)
        print(type(obj))
        print(type(obj).__name__)
        # print(obj)
        # if(type(obj) in [])
        if '__dict__' in obj:
            return obj.__dict__
        return({})

    def generate(self, analyser_results):
        # print(json.dumps(analyser_results, default=JsonOutput.to_json))
        for analyser_result in analyser_results:
            print(json.dumps(analyser_result, default=JsonOutput.to_json))
            # sys.exit(1)
        # for analyzer in analyser_results:
        # #     print(support_diagnostics.Colors.format("{header}{padding}".format(header=analyzer.heading,padding=" " * (ReportOutput.columns - len(analyzer.heading))), support_diagnostics.Colors.WHITE_FOREGROUND, support_diagnostics.Colors.BLUE_BACKGROUND))
        #     if analyser_results[analyzer] is not None:
        #         for analyzer_result in analyser_results[analyzer]:
        #             # !!! filter severity
        #             if analyzer_result.severity is not None:
        #                 print(support_diagnostics.Colors.format(analyzer_result.severity.name, analyzer_result.severity.foreground_color, analyzer_result.severity.background_color))

        #             if 'summary' in analyzer_result.results:
        #                 print(support_diagnostics.Colors.format("{header:<16}{result}".format(header="Summary", result=analyzer_result.results['summary'])))

        #             if 'detail' in analyzer_result.results:
        #                 print(support_diagnostics.Colors.format("{header:<16}{result}".format(header="Detail", result=analyzer_result.results['detail'])))

        #             if 'recommendation' in analyzer_result.results:
        #                 print(support_diagnostics.Colors.format("{header:<16}{result}".format(header="Recommendation", result=analyzer_result.results['recommendation'])))

        #             # All other results.
        #             for key in analyzer_result.results:
        #                 if key != 'summary' and key != 'detail' and key != 'recommendation':
        #                     print(support_diagnostics.Colors.format("{header:<16}{result}".format(header=key.capitalize(), result=analyzer_result.results[key])))

        #             # print()
        # print()
        
# if ReportOutput.rows is None:
#     ReportOutput.static_init()