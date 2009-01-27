Ext.ns('Ung');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Arp');

if ( Ung.Alpaca.Glue.hasPageRenderer( "arp", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Arp.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function()
    {
        this.staticGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,
            recordFields : [ "hostname", "hw_addr", "id" ],
            selectable : true,

            /* Name must set in order to get and set the settings */
            name : "static_arps",

            recordDefaults : {
                hw_addr : "00:11:22:33:44:66",
                hostname : "1.2.3.4"
            },

            columns : [{
                header : this._( "IP Address" ),
                width: 200,
                sortable: true,
                dataIndex : "hostname",
                editor : new Ext.form.TextField({
                    allowBlank : false,
                    vtype : "ipAddress"
                })
            },{
                header : this._( "MAC Address" ),
                width: 200,
                sortable: true,
                dataIndex : "hw_addr",
                editor : new Ext.form.TextField({
                    allowBlank : false,
                    vtype : "macAddress"
                })
            }]
        });

        this.staticGrid.store.load();

        this.activeGrid = new Ung.Alpaca.EditorGridPanel({
            recordFields : [ "ip_address", "mac_address", "id", "interface" ],
            
            tbar : [{
                text : this._( "Refresh" ),
                handler : this.refreshActiveEntries,
                scope : this
            }],
            
            entries : this.settings["active_arps"],
            saveData : false,
            
            columns : [{
                header : this._( "IP Address" ),
                width: 200,
                sortable: true,
                dataIndex : "ip_address"
            },{
                header : this._( "MAC Address" ),
                width: 200,
                sortable: true,
                dataIndex : "mac_address"
            },{
                header : this._( "Interface" ),
                width: 50,
                sortable: true,
                dataIndex : "interface"
            }]
        });

        this.activeGrid.store.load();
        
        Ext.apply( this, {
            items : [{
                xtype : "label",
                html : this._( "Static ARP Entries" )
            }, this.staticGrid, {
                xtype : "label",
                html : this._( "Active ARP Entries" )
            }, this.activeGrid ]
        });
        
        Ung.Alpaca.Pages.Arp.Index.superclass.initComponent.apply( this, arguments );
    },

    saveMethod : "/arp/set_settings",

    refreshActiveEntries : function()
    {
        var handler = this.completeRefreshActiveEntries.createDelegate( this );
        Ung.Alpaca.Util.executeRemoteFunction( "/arp/get_active", handler );
    },

    completeRefreshActiveEntries : function( activeArps, response, options )
    {
        if ( !activeArps ) return;

        this.activeGrid.store.loadData( activeArps );
    }
});

Ung.Alpaca.Pages.Arp.Index.settingsMethod = "/arp/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "arp", "index", Ung.Alpaca.Pages.Arp.Index );
