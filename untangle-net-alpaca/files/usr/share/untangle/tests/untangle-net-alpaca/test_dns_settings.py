from untangle.ats.alpaca_setup import AlpacaSetup

class TestDnsSettings(AlpacaSetup):
    @classmethod
    def setup_class(cls):
        AlpacaSetup.setup_class.im_func(cls)
        cls.original_settings = cls.handler.make_request( "dns/get_settings" )

    def teardown_class(cls):
        cls.handler.make_request( "dns/set_settings", cls.original_settings )
        
    def test_modify_settings( self ):
        for x,y in (( "enabled", True ), ( "enabled", False ), ( "suffix", "new.unknown.com" ), ( "suffix", "example.com" )):
            yield self.check_modify_settings, "dns_server_settings", x, y, y

    def check_modify_settings( self, key_1, key_2, new_value, expected ):
        dns_settings = self.handler.make_request( "dns/get_settings" )
        dns_settings[key_1][key_2] = new_value
        self.handler.make_request( "dns/set_settings", dns_settings )
        dns_settings = self.handler.make_request( "dns/get_settings" )
        assert dns_settings[key_1][key_2] == expected

    ## Hide the dynamic entries if the DNS server is disabled.
    def test_get_settings_dynamic_empty( self ):
        self.check_modify_settings( "dns_server_settings", "enabled", False, False )
        dns_settings = self.handler.make_request( "dns/get_settings" )
        assert len( dns_settings["dns_dynamic_entries"] ) == 0

    def test_get_leases_dynamic_empty( self ):
        self.check_modify_settings( "dns_server_settings", "enabled", False, False )
        dns_leases = self.handler.make_request( "dns/get_leases" )
        assert len( dns_leases ) == 0
        
    def test_add_static_entry( self ):
        entry = {"hostname":"simple.example.com","ip_address":"1.2.3.4","description":"test rule"}

        dns_settings = self.handler.make_request( "dns/get_settings" )
        dns_settings["dns_static_entries"].append(entry)
        self.handler.make_request( "dns/set_settings", dns_settings )
        dns_settings = self.handler.make_request( "dns/get_settings" )

        found_entry = False
        for dns_entry in dns_settings["dns_static_entries"]:
            if ( dns_entry["ip_address"] != entry["ip_address"] ):
                continue

            assert not found_entry
            for key in entry: assert entry[key] == dns_entry[key]
            found_entry = True

        assert found_entry
        
        
        
                                                    
