from untangle.ats.alpaca_setup import AlpacaSetup

class TestInterfaces(AlpacaSetup):
    def test_ethernet_media_set( self ):
        self.run_sql_command( "UPDATE alpaca_settings SET config_level=2000" )
        
        self.run_sql_command( "UPDATE interfaces SET speed=\"auto\",duplex=\"auto\"")
        
        settings = self.handler.make_request( "interface/get_settings/2" )
        assert settings["media"] == "autoauto"
        settings["media"] = "100full"
        self.handler.make_request( "interface/set_settings/2", settings )
        
        settings = self.handler.make_request( "interface/get_settings/2" )
        assert settings["media"] == "100full"

    def test_ethernet_media_null_bridge( self ):
        self.run_sql_command( "UPDATE alpaca_settings SET config_level=2000" )
        self.run_sql_command( "UPDATE interfaces SET speed=\"auto\",duplex=\"auto\"")

        settings = self.handler.make_request( "interface/get_settings/2" )
        settings["bridge"]["bridge_interface_id"] = None
        settings["media"] = "100full"
        self.handler.make_request( "interface/set_settings/2", settings )
        settings = self.handler.make_request( "interface/get_settings/2" )
        assert settings["media"] == "100full"

        
        
        
