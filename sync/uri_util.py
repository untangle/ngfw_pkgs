import os
import sys
import subprocess
import datetime
import traceback
import string
import re
from urllib3 import util

# This class is a utility class with utility functions providing
# useful tools for dealing with uris.
class UriUtil:

    @staticmethod
    def get_parsed_uri(uri):
        return util.url.parse_url(uri)

    @staticmethod
    def build_uri(original_uri, uri_settings):
        current_uri = util.url.parse_url(original_uri)
        scheme = current_uri.scheme
        if 'scheme' in uri_settings and uri_settings['scheme'] != None:
            scheme = uri_settings['scheme']
        host = current_uri.host
        if 'host' in uri_settings and uri_settings['host'] != None:
            host = uri_settings['host']
        port = current_uri.port
        if 'port' in uri_settings and uri_settings['port'] != None:
            port = uri_settings['port']
        path = current_uri.path
        if 'path' in uri_settings and uri_settings['path'] != None:
            path = uri_settings['path']
        return util.url.Url(scheme=scheme, host=host, port=port, path=path)
                    


