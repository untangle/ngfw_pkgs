Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Dhcp');

if ( Ung.Alpaca.Glue.hasPageRenderer( "dhcp", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Dhcp.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    constructor : function( config )
    {
        this.staticGrid = new Ung.Alpaca.EditorGridPanel({
            settings : config.settings,

            recordFields : [ "mac_address", "ip_address", "id", "description" ],
            editable : true,
            
            name : "dhcp_static_entries",

            recordDefaults : {
                mac_address : "00:11:22:33:44:66",
                ip_address : "1.2.3.4",
                description : "[Sample Entry]"
            },

            columns : [{
                header : "MAC Address",
                width: 200,
                sortable: true,
                dataIndex : "mac_address",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            },{
                header : "IP Address",
                width: 200,
                sortable: true,
                dataIndex : "ip_address",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            },{
                header : "Description",
                width: 200,
                sortable: true,
                dataIndex : "description",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            }]
        });

        this.staticGrid.store.load();

        this.currentLeasesGrid = new Ung.Alpaca.EditorGridPanel({
            settings : config.settings,

            recordFields : [ "mac_address", "ip_address", "hostname", "client_id", "expiration" ],
            editable : false,
            
            name : "dhcp_dynamic_entries",

            tbar : [{
                text : "Refresh",
                handler : this.refreshCurrentLeases,
                scope : this
            }],

            columns : [{
                header : "MAC Address",
                width: 200,
                sortable: true,
                dataIndex : "mac_address"
            },{
                header : "IP Address",
                width: 200,
                sortable: true,
                dataIndex : "ip_address"
            },{
                header : "Hostname",
                width: 200,
                sortable: true,
                dataIndex : "hostname"
            }]
        });

        this.currentLeasesGrid.store.load();
        
        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                /* Not in the default in order to accomodate grids. */
                autoHeight : true,
                defaults : {
                    xtype : "textfield",
                },
                items : [{
                    xtype : "checkbox",
                    fieldLabel : "Enabled",
                    name : "dhcp_server_settings.enabled"
                },{
                    fieldLabel : "Start",
                    name : "dhcp_server_settings.start_address"
                },{
                    fieldLabel : "End",
                    name : "dhcp_server_settings.end_address"
                },{
                    fieldLabel : "Lease Duration (seconds)",
                    name : "dhcp_server_settings.lease_duration"
                },{
                    fieldLabel : "Gateway",
                    name : "dhcp_server_settings.gateway"
                },{
                    fieldLabel : "Netmask",
                    name : "dhcp_server_settings.netmask"
                },{
                    fieldLabel : "Lease Limit",
                    name : "dhcp_server_settings.max_leases"
                },{
                    xtype : "checkbox",
                    fieldLabel : "Authoritative",
                    name : "dhcp_server_settings.is_authoritative"
                }]
            },{
                xtype : "label",
                html : "Static DHCP Entries"
            }, this.staticGrid, {
                xtype : "label",
                html : "Current DHCP Entries"                
            }, this.currentLeasesGrid ]
        });
        
        Ung.Alpaca.Pages.Dhcp.Index.superclass.constructor.apply( this, arguments );
    },

    saveMethod : "/dhcp/set_settings",

    refreshCurrentLeases : function()
    {
        var handler = this.completeRefreshCurrentLeases.createDelegate( this );
        Ung.Alpaca.Util.executeRemoteFunction( "/dhcp/get_leases", handler );
    },

    completeRefreshCurrentLeases : function( leases, response, options )
    {
        if ( !leases ) return;

        this.currentLeasesGrid.store.loadData( leases );
    }
});

Ung.Alpaca.Pages.Dhcp.Index.settingsMethod = "/dhcp/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "dhcp", "index", Ung.Alpaca.Pages.Dhcp.Index );

