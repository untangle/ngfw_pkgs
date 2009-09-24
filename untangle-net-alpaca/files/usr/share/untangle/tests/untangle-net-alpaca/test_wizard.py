import random

from untangle.ats.alpaca_setup import AlpacaSetup

class TestWizard(AlpacaSetup):
    def test_external_interface_static_1( self ):
        settings = {
            "ip" : "1.2.3.4",
            "netmask" : "255.255.0.0",
            "default_gateway" : "1.2.3.1",
            "dns_1" : "1.2.3.1",
            "dns_2" : None,
            "single_nic_mode" : False
            }

        self.handler.make_request( "uvm/wizard_external_interface_static", settings )

        settings = self.handler.make_request( "interface/get_settings/1" )
        aliases = settings["static_aliases"]

        assert settings["interface"]["config_type"] == "static"

        assert len( aliases ) == 1
        i = aliases[0]
        assert i["ip"] == "1.2.3.4"
        assert i["netmask"] == "16"
        assert settings["static"]["default_gateway"] == "1.2.3.1"
        assert settings["static"]["dns_1"] == "1.2.3.1"
        assert settings["static"]["dns_2"] == None

        assert self.run_sql_command( 'SELECT * FROM arp_eater_settings WHERE enabled = "f"') != ""
        assert self.run_sql_command( 'SELECT * FROM arp_eater_networks WHERE enabled = "f"' ) != ""

    def test_external_interface_static_2( self ):
        settings = {
            "ip" : "4.3.2.2",
            "netmask" : "255.128.0.0",
            "default_gateway" : "4.3.2.1",
            "dns_1" : "4.2.2.1",
            "dns_2" : "4.2.2.2",
            "single_nic_mode" : False
            }

        self.handler.make_request( "uvm/wizard_external_interface_static", settings )

        settings = self.handler.make_request( "interface/get_settings/1" )
        aliases = settings["static_aliases"]

        assert settings["interface"]["config_type"] == "static"

        assert len( aliases ) == 1
        i = aliases[0]
        assert i["ip"] == "4.3.2.2"
        assert i["netmask"] == "9"
        assert settings["static"]["default_gateway"] == "4.3.2.1"
        assert settings["static"]["dns_1"] == "4.2.2.1"
        assert settings["static"]["dns_2"] == "4.2.2.2"

        assert self.run_sql_command( 'SELECT * FROM arp_eater_settings WHERE enabled = "f"') != ""
        assert self.run_sql_command( 'SELECT * FROM arp_eater_networks WHERE enabled = "f"' ) != ""

    def test_external_interface_static_3( self ):
        settings = {
            "ip" : "1.2.3.4",
            "netmask" : "255.255.0.0",
            "default_gateway" : "1.2.3.1",
            "dns_1" : "1.2.3.1",
            "dns_2" : None,
            "single_nic_mode" : True
            }

        self.handler.make_request( "uvm/wizard_external_interface_static", settings )

        settings = self.handler.make_request( "interface/get_settings/1" )
        aliases = settings["static_aliases"]

        assert settings["interface"]["config_type"] == "static"

        assert len( aliases ) == 1
        i = aliases[0]
        assert i["ip"] == "1.2.3.4"
        assert i["netmask"] == "16"
        assert settings["static"]["default_gateway"] == "1.2.3.1"
        assert settings["static"]["dns_1"] == "1.2.3.1"
        assert settings["static"]["dns_2"] == None

        assert self.run_sql_command( 'SELECT * FROM arp_eater_settings WHERE enabled = "t"') != ""
        assert self.run_sql_command( 'SELECT * FROM arp_eater_networks WHERE enabled = "t"' ) != ""

    def test_external_interface_dynamic_1( self ):
        settings = {
            "single_nic_mode" : False
            }

        self.handler.make_request( "uvm/wizard_external_interface_dynamic", settings )

        settings = self.handler.make_request( "interface/get_settings/1" )
        aliases = settings["dynamic_aliases"]

        assert settings["interface"]["config_type"] == "dynamic"

        assert len( aliases ) == 0

        assert self.run_sql_command( 'SELECT * FROM arp_eater_settings WHERE enabled = "f"') != ""
        assert self.run_sql_command( 'SELECT * FROM arp_eater_networks WHERE enabled = "f"' ) != ""

    def test_external_interface_dynamic_2( self ):
        settings = {
            "single_nic_mode" : True
            }

        self.handler.make_request( "uvm/wizard_external_interface_dynamic", settings )

        settings = self.handler.make_request( "interface/get_settings/1" )
        aliases = settings["dynamic_aliases"]

        assert settings["interface"]["config_type"] == "dynamic"

        assert len( aliases ) == 0

        assert self.run_sql_command( 'SELECT * FROM arp_eater_settings WHERE enabled = "t"') != ""
        assert self.run_sql_command( 'SELECT * FROM arp_eater_networks WHERE enabled = "t"' ) != ""

    def test_external_interface_dynamic_3( self ):
        settings = {
            }

        self.handler.make_request( "uvm/wizard_external_interface_dynamic", settings )

        settings = self.handler.make_request( "interface/get_settings/1" )
        aliases = settings["dynamic_aliases"]

        assert settings["interface"]["config_type"] == "dynamic"

        assert len( aliases ) == 0

        assert self.run_sql_command( 'SELECT * FROM arp_eater_settings WHERE enabled = "f"') != ""
        assert self.run_sql_command( 'SELECT * FROM arp_eater_networks WHERE enabled = "f"' ) != ""


    def test_external_interface_pppoe_1( self ):
        password = random.random()
        settings = {
            "username" : "test_user",
            "password" : password,
            "single_nic_mode" : False
            }

        self.handler.make_request( "uvm/wizard_external_interface_pppoe", settings )

        settings = self.handler.make_request( "interface/get_settings/1" )
        aliases = settings["pppoe_aliases"]

        assert settings["interface"]["config_type"] == "pppoe"
        assert len( aliases ) == 0

        assert settings["pppoe"]["username"] == "test_user"
        assert settings["pppoe"]["password"] == '-[![N "]'

        assert self.run_sql_command( 'SELECT * FROM intf_pppoes WHERE password = "%s"' % password ) != ""

        assert self.run_sql_command( 'SELECT * FROM arp_eater_settings WHERE enabled = "f"') != ""
        assert self.run_sql_command( 'SELECT * FROM arp_eater_networks WHERE enabled = "f"' ) != ""

    def test_external_interface_pppoe_2( self ):
        password = random.random()
        settings = {
            "username" : "test_user_2",
            "password" : password,
            "single_nic_mode" : True
            }

        self.handler.make_request( "uvm/wizard_external_interface_pppoe", settings )

        settings = self.handler.make_request( "interface/get_settings/1" )
        aliases = settings["pppoe_aliases"]

        assert settings["interface"]["config_type"] == "pppoe"
        assert len( aliases ) == 0

        assert settings["pppoe"]["username"] == "test_user_2"
        assert settings["pppoe"]["password"] == '-[![N "]'

        assert self.run_sql_command( 'SELECT * FROM intf_pppoes WHERE password = "%s"' % password ) != ""
        assert self.run_sql_command( 'SELECT * FROM arp_eater_settings WHERE enabled = "f"') != ""
        assert self.run_sql_command( 'SELECT * FROM arp_eater_networks WHERE enabled = "f"' ) != ""









            
        

