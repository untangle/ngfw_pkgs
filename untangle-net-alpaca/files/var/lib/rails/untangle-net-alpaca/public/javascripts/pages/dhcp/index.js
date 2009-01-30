Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Dhcp');

if ( Ung.Alpaca.Glue.hasPageRenderer( "dhcp", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Dhcp.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function()
    {
        this.staticGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,

            recordFields : [ "mac_address", "ip_address", "id", "description" ],
            selectable : true,
            
            name : "dhcp_static_entries",

            recordDefaults : {
                mac_address : "00:11:22:33:44:66",
                ip_address : "1.2.3.4",
                description : this._( "[New Entry]" )
            },

            columns : [{
                header : this._( "MAC Address" ),
                width: 200,
                sortable: true,
                dataIndex : "mac_address",
                editor : new Ext.form.TextField({
                    allowBlank : false,
                    vtype : "macAddress"
                })
            },{
                header : this._( "IP Address" ),
                width: 200,
                sortable: true,
                dataIndex : "ip_address",
                editor : new Ext.form.TextField({
                    allowBlank : false,
                    vtype : "ipAddress"
                })
            },{
                header : this._( "Description" ),
                width: 200,
                sortable: true,
                dataIndex : "description",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            }]
        });

        this.staticGrid.store.load();

        var addStaticColumn = new Ung.Alpaca.grid.IconColumn({
                header : this._( "Add Static" ),
                width : 70,
                handle : this.addStatic.createDelegate( this ),
                iconClass : 'icon-add-row'
        });

        this.currentLeasesGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,
            
            recordFields : [ "mac_address", "ip_address", "hostname", "client_id", "expiration" ],
            selectable : false,
            
            name : "dhcp_dynamic_entries",
            saveData : false,

            tbar : [{
                text : this._( "Refresh" ),
                handler : this.refreshCurrentLeases,
                scope : this
            }],

            plugins : addStaticColumn,

            columns : [{
                header : this._( "MAC Address" ),
                width: 200,
                sortable: true,
                dataIndex : "mac_address"
            },{
                header : this._( "IP Address" ),
                width: 200,
                sortable: true,
                dataIndex : "ip_address"
            },{
                header : this._( "Hostname" ),
                width: 200,
                sortable: true,
                dataIndex : "hostname"
            }, addStaticColumn ]
        });

        this.currentLeasesGrid.store.load();

        var items = [{
            xtype : "checkbox",
            fieldLabel : this._( "Enabled" ),
            name : "dhcp_server_settings.enabled"
        },{
            fieldLabel : this._( "Start" ),
            name : "dhcp_server_settings.start_address",
            vtype : "ipAddress"
        },{
            fieldLabel : this._( "End" ),
            name : "dhcp_server_settings.end_address",
            vtype : "ipAddress"
        }];

        if ( Ung.Alpaca.isAdvanced ) {
            items.push({
                xtype : "numberfield",
                fieldLabel : this._( "Lease Duration" ),
                boxLabel : this._( "(seconds)" ),
                name : "dhcp_server_settings.lease_duration"
            },{
                fieldLabel : this._( "Gateway" ),
                name : "dhcp_server_settings.gateway",
                vtype : "ipAddress"
            },{
                fieldLabel : this._( "Netmask" ),
                name : "dhcp_server_settings.netmask",
                vtype : "ipAddress"
            },{
                xtype : "numberfield",
                fieldLabel : this._( "Lease Limit" ),
                name : "dhcp_server_settings.max_leases"
            },{
                xtype : "checkbox",
                fieldLabel : this._( "Authoritative" ),
                name : "dhcp_server_settings.is_authoritative"
            });
        }

        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            
            items : [{
                xtype : "label",
                cls : 'page-header-text',
                html : this._( "DHCP Server" )
            },
            {
                /* Not in the default in order to accomodate grids. */
                autoHeight : true,
                defaults : {
                    xtype : "textfield"
                },
                items : items
            },{
                xtype : "label",
                cls:'label-section-heading',
                html : this._( "Static DHCP Entries" )
            }, this.staticGrid, {
                xtype : "label",
                cls:'label-section-heading',
                html : this._( "Current DHCP Entries" )       
            }, this.currentLeasesGrid ]
        });
        
        Ung.Alpaca.Pages.Dhcp.Index.superclass.initComponent.apply( this, arguments );
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
    },

    addStatic : function( record, index )
    {
        var d = record.data;
        var entry = new this.staticGrid.record({
            mac_address : d.mac_address,
            ip_address : d.ip_address,
            description : d.hostname
        });

        this.staticGrid.stopEditing();
        this.staticGrid.store.insert( 0, entry );
        application.onFieldChange();
        this.staticGrid.updateChangedData( entry, "added" );
    }
});

Ung.Alpaca.Pages.Dhcp.Index.settingsMethod = "/dhcp/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "dhcp", "index", Ung.Alpaca.Pages.Dhcp.Index );

