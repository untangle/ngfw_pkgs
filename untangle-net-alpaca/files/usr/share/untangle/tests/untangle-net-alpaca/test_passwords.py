import commands

from untangle.ats.alpaca_setup import AlpacaSetup

PASSWORD_STRING = "-[![N \"]"

class TestPasswords(AlpacaSetup):    
    def test_hostname(self):
        settings = self.handler.make_request( "hostname/get_settings" )
        assert settings["ddclient_settings"]["password"] == PASSWORD_STRING        

    def test_hostname_set(self):
        new_password = "simple string"
        
        settings = self.handler.make_request( "hostname/get_settings" )
        assert settings["ddclient_settings"]["password"] == PASSWORD_STRING

        settings["ddclient_settings"]["password"] = new_password
        
        self.handler.make_request( "hostname/set_settings", settings )

        settings = self.handler.make_request( "hostname/get_settings" )
        assert settings["ddclient_settings"]["password"] == PASSWORD_STRING

        ## Verify that the password is in the database
        current_password = self.run_sql_command( "SELECT password FROM ddclient_settings" )
        
        assert current_password == new_password

    def test_hostname_unchanged(self):
        new_password = "simple string"
        
        ## Change the password, and then try to save the settings with the unmodified
        ## password string and verify that it is not lost.
        settings = self.handler.make_request( "hostname/get_settings" )
        settings["ddclient_settings"]["password"] = new_password
        self.handler.make_request( "hostname/set_settings", settings )
        settings = self.handler.make_request( "hostname/get_settings" )
        assert settings["ddclient_settings"]["password"] == PASSWORD_STRING        
        self.handler.make_request( "hostname/set_settings", settings )

        ## Verify that the password is not modified in the database
        current_password = self.run_sql_command( "SELECT password FROM ddclient_settings" )
        
        assert current_password == new_password

    def test_network_pppoe(self):
        self.run_sql_command( "UPDATE alapca_settings SET config_level=1000" )
        settings = self.handler.make_request( "network/get_settings" )
        interface = settings["config_list"][0]
        
        assert interface["pppoe"]["password"] == PASSWORD_STRING        

    def test_network_pppoe_set(self):
        new_password = "simple string"
        
        self.run_sql_command( "UPDATE alapca_settings SET config_level=1000" )
        settings = self.handler.make_request( "network/get_settings" )
        interface = settings["config_list"][0]
        assert interface["pppoe"]["password"] == PASSWORD_STRING        

        interface["pppoe"]["username"] = "foo"
        interface["pppoe"]["password"] = new_password
        interface["interface"]["config_type"] = "pppoe"
        
        self.handler.make_request( "network/set_settings", settings )

        settings = self.handler.make_request( "network/get_settings" )
        interface = settings["config_list"][0]
        assert interface["pppoe"]["password"] == PASSWORD_STRING        

        ## Verify that the password is in the database
        current_password = self.run_sql_command( "SELECT password FROM intf_pppoes WHERE interface_id=%d", interface["interface"]["id"] )
        
        assert current_password == new_password

    def test_network_pppoe_unchanged(self):
        new_password = "simple string"
        
        self.run_sql_command( "UPDATE alapca_settings SET config_level=1000" )
        settings = self.handler.make_request( "network/get_settings" )
        interface = settings["config_list"][0]
        interface["pppoe"]["username"] = "foo"
        interface["pppoe"]["password"] = new_password
        interface["interface"]["config_type"] = "pppoe"
        self.handler.make_request( "network/set_settings", settings )
        settings = self.handler.make_request( "network/get_settings" )
        self.handler.make_request( "network/set_settings", settings )
        
        settings = self.handler.make_request( "network/get_settings" )
        interface = settings["config_list"][0]
        assert interface["pppoe"]["password"] == PASSWORD_STRING        

        ## Verify that the password is in the database
        current_password = self.run_sql_command( "SELECT password FROM intf_pppoes WHERE interface_id=%d", interface["interface"]["id"] )
        
        assert current_password == new_password

    def test_interface_pppoe(self):
        self.run_sql_command( "UPDATE alpaca_settings SET config_level=2000" )
        settings = self.handler.make_request( "interface/get_settings/1" )
        assert settings["pppoe"]["password"] == PASSWORD_STRING 

    def test_interface_pppoe_set(self):
        new_password = "simple string"
        
        self.run_sql_command( "UPDATE alpaca_settings SET config_level=2000" )
        
        settings = self.handler.make_request( "interface/get_settings/1" )
        
        assert settings["pppoe"]["password"] == PASSWORD_STRING        

        settings["pppoe"]["username"] = "foo"
        settings["pppoe"]["password"] = new_password
        
        self.handler.make_request( "interface/set_settings/1", settings )

        settings = self.handler.make_request( "interface/get_settings/1" )
        assert settings["pppoe"]["password"] == PASSWORD_STRING        

        ## Verify that the password is in the database
        current_password = self.run_sql_command( "SELECT password FROM intf_pppoes WHERE interface_id=%d",
                                                 settings["interface"]["id"] )
        
        assert current_password == new_password

    def test_interface_pppoe_unchanged(self):
        new_password = "simple string"
        
        self.run_sql_command( "UPDATE alpaca_settings SET config_level=2000" )
        settings = self.handler.make_request( "interface/get_settings/1" )
        settings["pppoe"]["username"] = "foo"
        settings["pppoe"]["password"] = new_password
        self.handler.make_request( "interface/set_settings/1", settings )
        settings = self.handler.make_request( "interface/get_settings/1" )
        self.handler.make_request( "interface/set_settings/1", settings )
        
        settings = self.handler.make_request( "interface/get_settings/1" )
        assert settings["pppoe"]["password"] == PASSWORD_STRING        

        ## Verify that the password is in the database
        current_password = self.run_sql_command( "SELECT password FROM intf_pppoes WHERE interface_id=%d", settings["interface"]["id"] )
        
        assert current_password == new_password

