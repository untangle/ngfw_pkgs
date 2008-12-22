Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Dhcp');

if ( Ung.Alpaca.Application.hasPageRenderer( "dhcp", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Dhcp.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function()
    {
        this.staticGrid = new Ung.Alpaca.EditorGridPanel({
            recordFields : [ "mac_address", "ip_address", "id", "description" ],

             tbar : [{
                 text : "Add",
                 handler : this.addStaticEntry.createDelegate( this )
             }],
            
            entries : this.settings["dhcp_static_entries"],

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
            }, this.staticGrid ]
        });
        
        Ung.Alpaca.Pages.Dhcp.Index.superclass.initComponent.apply( this, arguments );
    },

    onRender : function()
    {
        Ung.Alpaca.Pages.Dhcp.Index.superclass.onRender.apply( this, arguments );
    },

    saveSettings : function()
    {
        Ext.MessageBox.wait("Saving...", "Please wait");

        this.updateSettings( this.settings );

        Ung.Alpaca.Util.executeRemoteFunction( "/dhcp/set_settings", 
                                               this.completeSaveSettings.createDelegate( this ), 
                                               null,
                                               this.settings );
    },

    completeSaveSettings : function()
    {
        Ext.MessageBox.show({  
            title : 'Saved Settings',
            msg : 'Settings have been saved successfuly',
            buttons : Ext.MessageBox.OK,
            icon : Ext.MessageBox.INFO
        });

        /* Reload the page in the background */
        Ung.Alpaca.Application.reloadCurrentPath();
    },

    addStaticEntry : function()
    {
        var staticEntry = new this.staticRecord({
            mac_address : "00:11:22:33:44:66",
            ip_address : "1.2.3.4",
            description : "[Sample Entry]"
        });
        
        this.staticGrid.stopEditing();
        this.staticGrid.store.insert( 0, staticEntry );
        this.staticGrid.startEditing( 0, 0 );
    }
});

Ung.Alpaca.Pages.Dhcp.Index.settingsMethod = "/dhcp/get_settings";
Ung.Alpaca.Application.registerPageRenderer( "dhcp", "index", Ung.Alpaca.Pages.Dhcp.Index );

