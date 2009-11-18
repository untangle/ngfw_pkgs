
## Install python-codespeak-lib in order to run tests.

import commands
import logging
import pycurl
import shutil
import os
import urllib
from StringIO import StringIO

from untangle.jsonrpc.json import dumps, loads

import tempfile
import sqlite3

## This is for simple JSON applications, things like the shield or cpd.
class UntangleJSONRequestHandler(object):
    def __init__(self, port, timeout = 30 ):
        self.__curl = pycurl.Curl()
        self.__curl.setopt( pycurl.NOSIGNAL, 1 )
        self.__curl.setopt( pycurl.CONNECTTIMEOUT, 30 )
        self.__curl.setopt( pycurl.TIMEOUT, timeout )
        self.__curl.setopt( pycurl.COOKIEFILE, "" )
        self.__curl.setopt( pycurl.FOLLOWLOCATION, 0 )

        self.__base_url = "http://localhost:%d/" % port
    
    def make_request(self, func_name, params = {} ):
        response = StringIO()

        self.__curl.setopt( pycurl.URL, self.__base_url )

        params["function"] = func_name
        postdata = "json_request=%s" % urllib.quote( dumps(params))
        
        self.__curl.setopt( pycurl.HTTPHEADER, [ "Content-Type: application/x-www-form-urlencoded" ])

        self.__curl.setopt( pycurl.HTTPGET, 0 )
        self.__curl.setopt( pycurl.POST, 1 )
        self.__curl.setopt( pycurl.POSTFIELDS, str( postdata ))

        self.__curl.setopt( pycurl.VERBOSE, False )
        self.__curl.setopt( pycurl.WRITEFUNCTION, response.write )
        self.__curl.perform()

        if ( self.__curl.getinfo( pycurl.HTTP_CODE ) != 200 ):
            raise Exception, "Error executing command '%s'" % page

        json_response = loads( response.getvalue())
        if ( json_response["status"] != 104 ):
            raise Exception( "Error executing command[%s] '%s'" % ( json_response["status"], func_name ))

        return json_response

    def set_timeout( self, timeout ):
        self.__curl.setopt( pycurl.TIMEOUT, timeout )


class TestHostDatabase():
    def setup_class( cls ):
        cls.handler = UntangleJSONRequestHandler( 3005 )
        cls.database_path = "/etc/untangle-cpd/host_database.db"

        if ( "CPD_HOST_DATABASE" in os.environ ):
            cls.database_path = os.environ["CPD_HOST_DATABASE"]

        cls.database_conn = sqlite3.connect( cls.database_path )
        cls.database_conn.row_factory = sqlite3.Row

    def setup_method(self, method):
        ## Flush out all of the entries to start with a clean slate.
        self.handler.make_request( "clear_host_database" )
            
    ## Simple test to just create one entry.
    def test_create_ipv4_entry(self):
        user = "test_user"
        ipv4_addr = "1.2.3.4"
        self.handler.make_request( "replace_host", { "ipv4_addr" : ipv4_addr, "username" : user })

        results = self.get_entries( ipv4_addr )        
        assert len(results) == 1
        
        assert results[0]["username"] == user
        assert results[0]["hw_addr"] == None

    ## Simple test to just create one entry.
    def test_create_hw_addr_entry(self):
        ipv4_addr = "1.2.3.4"
        hw_addr = "00:11:22:33:44:55"
        user = "test_user"
        
        self.handler.make_request( "replace_host", { "ipv4_addr" : ipv4_addr, "username" : user, "hw_addr" : hw_addr })
        results = self.get_entries( ipv4_addr )
        
        assert len(results) == 1
        assert results[0]["username"] == user
        assert results[0]["hw_addr"] == hw_addr

        ## Simple test to verify the code expands the HW Address.  (IPSet requires the full format).
    def test_create_hw_addr_entry_2(self):
        ipv4_addr = "1.2.3.4"
        hw_addr = "0:1:2:3:4:5"
        user = "test_user"
        
        self.handler.make_request( "replace_host", { "ipv4_addr" : ipv4_addr, "username" : user, "hw_addr" : hw_addr })
        hw_addr = "00:01:02:03:04:05"
        results = self.get_entries( ipv4_addr )
        
        assert len(results) == 1
        assert results[0]["username"] == user
        assert results[0]["hw_addr"] == hw_addr

    def test_replace_ipv4_entry(self):
        ipv4_addr = "1.2.3.4"
        test_time = "2009-11-18 01:33:45"

        self.handler.make_request( "replace_host", { "ipv4_addr" : ipv4_addr, "username" : "no_user" })
        results = self.get_entries( ipv4_addr )[0]
        assert results["username"] == "no_user"
        self.run_update( "UPDATE host_database SET last_session=?,session_start=? WHERE ipv4_addr=?",
                        ( test_time, test_time, ipv4_addr ))
        self.handler.make_request( "replace_host", { "ipv4_addr" : ipv4_addr, "username" : "new_user" })
        results = self.get_entries( ipv4_addr )

        assert len( results ) == 1
        ## Verify the session start time was not changed.
        assert results[0]["username"] == "new_user"
        assert results[0]["hw_addr"] == None
        assert results[0]["session_start"] == test_time
        assert results[0]["last_session"] != test_time

    def test_replace_ipv4_entry_1(self):
        ipv4_addr = "1.2.3.4"
        test_time = "2009-11-18 01:33:45"
        
        self.handler.make_request( "replace_host", { "ipv4_addr" : ipv4_addr, "username" : "no_user" })
        results = self.get_entries( ipv4_addr )[0]
        assert results["username"] == "no_user"
        self.run_update( "UPDATE host_database SET last_session=?,session_start=? WHERE ipv4_addr=?",
                         ( test_time, test_time, ipv4_addr ))
        self.handler.make_request( "replace_host", { "ipv4_addr" : ipv4_addr, "username" : "new_user", "update_session_start" : "true" })
        results = self.get_entries( ipv4_addr )

        ## Verify that the session start time was updated because the update username flag.
        assert len( results ) == 1
        assert results[0]["username"] == "new_user"
        assert results[0]["hw_addr"] == None
        assert results[0]["session_start"] != test_time
        assert results[0]["last_session"] != test_time

    ## Change the MAC Address of an entry
    def test_replace_hw_addr_entry_1(self):
        ipv4_addr = "1.2.3.4"
        hw_addr = "00:11:22:33:44:55"
        user = "test_user"
        
        self.handler.make_request( "replace_host", { "ipv4_addr" : ipv4_addr, "username" : user, "hw_addr" : hw_addr })
        results = self.get_entries( ipv4_addr )
        
        assert len(results) == 1

        hw_addr = "00:11:22:33:44:56"
        self.handler.make_request( "replace_host", { "ipv4_addr" : ipv4_addr, "username" : user, "hw_addr" : hw_addr })
        results = self.get_entries( ipv4_addr )
        
        assert len(results) == 1
        assert results[0]["username"] == user
        assert results[0]["hw_addr"] == hw_addr

    ## Change the MAC Address of an entry to NULL
    def test_replace_hw_addr_entry_2(self):
        ipv4_addr = "1.2.3.4"
        hw_addr = "00:11:22:33:44:55"
        user = "test_user"
        
        self.handler.make_request( "replace_host", { "ipv4_addr" : ipv4_addr, "username" : user, "hw_addr" : hw_addr })
        results = self.get_entries( ipv4_addr )
        
        assert len(results) == 1

        hw_addr = None
        self.handler.make_request( "replace_host", { "ipv4_addr" : ipv4_addr, "username" : user, "hw_addr" : hw_addr })
        results = self.get_entries( ipv4_addr )
        
        assert len(results) == 1
        assert results[0]["username"] == user
        assert results[0]["hw_addr"] == hw_addr

    def get_entries(self, ipv4_addr = None, username = None, hw_addr=None ):
        params = []
        query = 'SELECT * FROM host_database WHERE 1 '

        if ( ipv4_addr != None ):
            query = query + " AND ipv4_addr=?"
            params.append( ipv4_addr )

        if ( username != None ):
            query = query + " AND username=?"
            params.append( username )

        if ( hw_addr != None ):
            query = query + " AND hw_addr=?"
            params.append( hw_addr )

        cursor = self.database_conn.cursor()
        cursor.execute( query, params )
        results = cursor.fetchall()
        cursor.close()

        return results

    def run_update( self, query, params = ()):
        curs = self.database_conn.cursor()
        try:
            curs.execute( query, params )
            self.database_conn.commit()
            
        finally:
            curs.close()

        
            
        

        


        
        
        
        
    

