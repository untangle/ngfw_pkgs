Ext.ns('Ung');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Network');

if ( Ung.Alpaca.Glue.hasPageRenderer( "network", "troubleshoot" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Network.TroubleShoot = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function()
    {
        this.testArray = [{
            divClass : "ua-cell-test-connectivity",
            onClick : "openConnectivityTest",
            name : this._( "Connectivity Test" )
        },{
            divClass : "ua-cell-test-ping",
            onClick : "openPingTest",
            name : this._( "Ping Test" )
        },{
            divClass : "ua-cell-test-dns",
            onClick : "openDnsTest",
            name : this._( "DNS Test" )
        },{
            divClass : "ua-cell-test-tcp",
            onClick : "openTcpTest",
            name : this._( "Connection Test" )
        },{
            divClass : "ua-cell-test-traceroute",
            onClick : "openTracerouteTest",
            name : this._( "Traceroute Test" )
        },{
            divClass : "ua-cell-test-packet",
            onClick : "openPacketTest",
            name : this._( "Packet Test" )
        }];

        this.testGrid = new Ung.Alpaca.EditorGridPanel({
            recordFields : [ "divClass", "onClick", "name" ],
            
            entries : this.testArray,
            saveData : false,
            autoExpandColumn : "col-network-test",

            tbar : [],
            
            columns : [{
                id : "col-network-test",
                header : this._( "Network Tests" ),
                width: 200,
                sortable: false,
                dataIndex : "ip_address",
                renderer : this.renderNetworkTests.createDelegate( this )
            }]
        });

        this.testGrid.store.load();
        
        Ext.apply( this, {
            items : [ {
                xtype : "label",
                html : this._( "Network Tests" ),
                cls: 'page-header-text'                
            }, this.testGrid ]
        });
        
        Ung.Alpaca.Pages.Network.TroubleShoot.superclass.initComponent.apply( this, arguments );
    },

    renderNetworkTests : function( value, metadata, record )
    {
        var data = record.data, link = "javascript:application.layout.activeItem." + data.onClick + "()";

        return "<a href='" + link + "'><div class=' ua-cell-test " + data.divClass + "'>" + data.name + "</div></a>";
    },

    openConnectivityTest : function()
    {
        if ( this.connectivityTest != null ) {
            this.completeOpenConnectivityTest();
            return;
        }

        var queryPath = ({ "controller" : "network", "page" : "connectivity_test" });
        Ung.Alpaca.Util.loadScript( queryPath, this.completeOpenConnectivityTest.createDelegate( this ));
    },

    completeOpenConnectivityTest : function()
    {
        if ( this.connectivityTest == null ) {
            this.connectivityTest = new Ung.Alpaca.ConnectivityTest();
        }
        
        this.connectivityTest.show();
    },

    openPingTest : function()
    {
        if ( this.pingTest != null ) {
            this.completeOpenPingTest();
            return;
        }

        var queryPath = ({ "controller" : "network", "page" : "ping_test" });
        Ung.Alpaca.Util.loadScript( queryPath, this.completeOpenPingTest.createDelegate( this ));
    },

    completeOpenPingTest : function()
    {
        if ( this.pingTest == null ) {
            this.pingTest = new Ung.Alpaca.PingTest();
        }
        
        this.pingTest.show();
    },
    
    openDnsTest : function()
    {
        if ( this.dnsTest != null ) {
            this.completeOpenDnsTest();
            return;
        }

        var queryPath = ({ "controller" : "network", "page" : "dns_test" });
        Ung.Alpaca.Util.loadScript( queryPath, this.completeOpenDnsTest.createDelegate( this ));
    },

    completeOpenDnsTest : function()
    {
        if ( this.dnsTest == null ) {
            this.dnsTest = new Ung.Alpaca.DnsTest();
        }
        
        this.dnsTest.show();
    },

    openTcpTest : function()
    {
        if ( this.tcpTest != null ) {
            this.completeOpenTcpTest();
            return;
        }

        var queryPath = ({ "controller" : "network", "page" : "tcp_test" });
        Ung.Alpaca.Util.loadScript( queryPath, this.completeOpenTcpTest.createDelegate( this ));
    },

    completeOpenTcpTest : function()
    {
        if ( this.tcpTest == null ) {
            this.tcpTest = new Ung.Alpaca.TcpTest();
        }
        
        this.tcpTest.show();
    },

    openTracerouteTest : function()
    {
        if ( this.tracerouteTest != null ) {
            this.completeOpenTracerouteTest();
            return;
        }

        var queryPath = ({ "controller" : "network", "page" : "traceroute_test" });
        Ung.Alpaca.Util.loadScript( queryPath, this.completeOpenTracerouteTest.createDelegate( this ));
    },

    completeOpenTracerouteTest : function()
    {
        if ( this.tracerouteTest == null ) {
            this.tracerouteTest = new Ung.Alpaca.TracerouteTest();
        }
        
        this.tracerouteTest.show();
    },

    openPacketTest : function()
    {
        if ( this.packetTest != null ) {
            this.completeOpenPacketTest();
            return;
        }

        var queryPath = ({ "controller" : "network", "page" : "packet_test" });
        Ung.Alpaca.Util.loadScript( queryPath, this.completeOpenPacketTest.createDelegate( this ));
    },

    completeOpenPacketTest : function()
    {
        if ( this.packetTest == null ) {
            this.packetTest = new Ung.Alpaca.PacketTest({
                interfaceStore : this.settings["interface_enum"]
            });
        }
        
        this.packetTest.show();
    }



});

Ung.Alpaca.Pages.Network.TroubleShoot.settingsMethod = "/network/get_troubleshoot_settings";
Ung.Alpaca.Glue.registerPageRenderer( "network", "troubleshoot", Ung.Alpaca.Pages.Network.TroubleShoot );
