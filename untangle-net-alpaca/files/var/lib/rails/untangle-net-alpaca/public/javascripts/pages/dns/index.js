Ext.ns('Ung');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Dns');

if ( Ung.Alpaca.Glue.hasPageRenderer( "dns", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Dns.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function()
    {
        this.staticDnsGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,
            recordFields : [ "hostname", "ip_address", "description" ],
            selectable : true,

            /* Name must set in order to get and set the settings */
            name : "dns_static_entries",

            recordDefaults : {
                ip_address : "1.2.3.4",
                hostname : "sample.example.com",
                description : "[New Dns Entry]"
            },

            columns : [{
                header : this._( "IP Address" ),
                width: 200,
                sortable: true,
                dataIndex : "ip_address",
                editor : new Ext.form.TextField({
                    allowBlank : false,
                    vtype : "ipAddress"
                })
            },{
                header : this._( "Hostname(s)" ),
                width: 200,
                sortable: true,
                dataIndex : "hostname",
                editor : new Ext.form.TextField({
                    allowBlank : false,
                    vtype : "hostnameList"
                })
            },{
                header : this._( "Description" ),
                width: 200,
                sortable: true,
                dataIndex : "description",
                editor : new Ext.form.TextField({
                    allowBlank : true
                })
            }]
        });

        this.staticDnsGrid.store.load();
        
        this.automaticDnsGrid = new Ung.Alpaca.EditorGridPanel({
            recordFields : [ "ip_address", "hostname" ],
            
            tbar : [{
                text : "Refresh",
                iconCls : 'icon-autorefresh',
                handler : this.refreshAutomaticEntries,
                scope : this
            }],
            
            entries : this.settings["dns_dynamic_entries"],
            saveData : false,
            
            columns : [{
                header : this._( "IP Address" ),
                width: 200,
                sortable: true,
                dataIndex : "ip_address"
            },{
                header : this._( "Hostname" ),
                width: 200,
                sortable: true,
                dataIndex : "hostname"
            }]
        });

        this.automaticDnsGrid.store.load();
        
        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                xtype : "label",
                cls : 'page-header-text',
                html : this._( "DNS Server" )
            },{
                autoHeight : true,
                defaults : {
                    xtype : "textfield"
                },
                items : [{
                    xtype : "checkbox",
                    name : "dns_server_settings.enabled",
                    fieldLabel : this._( "Enabled" )
                },{
                    fieldLabel : this._( "Domain Name Suffix" ),
                    name : "dns_server_settings.suffix",
                    vtype: 'domainNameSuffix',
                    cls: 'label-width-1'
                }]
            },{
                xtype : "label",
                cls: 'label-section-heading-2',
                html : this._( "Static DNS Entries" )
            }, this.staticDnsGrid, {
                xtype : "label",
                cls: 'label-section-heading-2',
                html : this._( "Automatic DNS Entries" )
            }, this.automaticDnsGrid ]
        });
        
        Ung.Alpaca.Pages.Dns.Index.superclass.initComponent.apply( this, arguments );
    },

    saveMethod : "/dns/set_settings",

    refreshAutomaticEntries : function()
    {
        var handler = this.completeRefreshAutomaticEntries.createDelegate( this );
        Ung.Alpaca.Util.executeRemoteFunction( "/dns/get_leases", handler );
    },

    completeRefreshAutomaticEntries : function( leases, response, options )
    {
        if ( !leases ) return;

        this.automaticDnsGrid.store.loadData( leases );
    }
});

Ung.Alpaca.Pages.Dns.Index.settingsMethod = "/dns/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "dns", "index", Ung.Alpaca.Pages.Dns.Index );
