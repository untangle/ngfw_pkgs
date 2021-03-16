"""enabled services for license management"""
from enum import Enum

class Service:
    """this class is a struct for holding the settings pieces of an enabled service"""
    name = ""
    settings_pieces = []

    def __init__(self, name, settings_pieces):
        self.name = name
        self.settings_pieces = settings_pieces

    def get_settings_pieces(self):
        return self.settings_pieces

def get_nginx_services():
    """get the settings pieces of the possible enabled services for nginx(waf)"""
    services = {}
    services["allEnabled"] = Service("allEnabled", None)
    services["loadBalancing"] = Service("loadBalancing", ["server", "upstreamBackend", "lbMethod"])
    services["sslCertUpload"] = Service("sslUpload", None)
    services["advancedLogging"] = Service("advancedLogging", None)
    services["manualRuleConfig"] = Service("manualRuleConfig", None)
    services["ruleException"] = Service("ruleException", None)
    return services

def get_default_value_json(json_obj, segments):
    """get the default value of given segments"""
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
    """set the settings with a given value given segments"""
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