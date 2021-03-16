from enum import Enum

class Service:
    name = ""
    settings_pieces = []

    def __init__(self, name, settings_pieces):
        self.name = name
        self.settings_pieces = settings_pieces

    def get_settings_pieces(self):
        return self.settings_pieces

def get_nginx_services():
    services = {}
    services["allEnabled"] = Service("allEnabled", None)
    services["loadBalancing"] = Service("loadBalancing", ["server", "upstreamBackend", "lbMethod"])
    services["sslCertUpload"] = Service("sslUpload", None)
    services["advancedLogging"] = Service("advancedLogging", None)
    services["manualRuleConfig"] = Service("manualRuleConfig", None)
    services["ruleException"] = Service("ruleException", None)
    return services

def get_default_value_json(json_obj, segments):
    if len(segments) == 0:
        return json_obj
    elif len(segments) == 1:
        return json_obj[segments[0]]
    else: 
        element = segments[0]
        new_segments = segments[1:]

        new_object = json_obj[element]

        return get_default_value_json(new_object, new_segments)

def set_settings_value(json_obj, segments, value):
    if len(segments) == 0:
        return value
    elif len(segments) == 1:
        json_obj[segments[0]] = value
        return json_obj
    else:
        element = segments[0]
        new_segments = segments[1:]

        if json_obj[element] is None:
            json_obj[element] = {}

        json_obj[element] = set_settings_value(json_obj[element], new_segments, value)

        return json_obj