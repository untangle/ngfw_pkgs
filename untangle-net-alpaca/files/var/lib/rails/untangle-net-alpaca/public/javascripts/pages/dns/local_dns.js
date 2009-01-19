Ext.ns('Ung');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Dns');

if ( Ung.Alpaca.Glue.hasPageRenderer( "dns", "local_dns" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Dns.LocalDns = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function()
    {
        this.localDnsGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,
            recordFields : [ "server_ip", "domain_name_list", "enabled" ],
            selectable : true,

            /* Name must set in order to get and set the settings */
            name : "upstream_servers",

            recordDefaults : {
                enabled : true,
                server_ip : "1.2.3.4",
                domain_name_list : "example.com"
            },

            columns : [{
                header : "Server Address",
                width: 200,
                sortable: true,
                dataIndex : "server_ip",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            },{
                header : "Domain List",
                width: 200,
                sortable: true,
                dataIndex : "domain_name_list",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            }]
        });

        this.localDnsGrid.store.load();
        
        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                xtype : "label",
                html : "Local DNS Servers"
            }, this.localDnsGrid ]
        });
        
        Ung.Alpaca.Pages.Dns.LocalDns.superclass.initComponent.apply( this, arguments );
    },

    saveMethod : "/dns/set_settings"
});

Ung.Alpaca.Pages.Dns.LocalDns.settingsMethod = "/dns/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "dns", "local_dns", Ung.Alpaca.Pages.Dns.LocalDns );
