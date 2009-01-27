Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Network');

if ( Ung.Alpaca.Glue.hasPageRenderer( "network", "e_aliases" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Network.Aliases = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function()
    {
        this.aliasGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,
            
            recordFields : [ "network_string" ],
            selectable : true,
            
            name : "external_aliases",

            recordDefaults : {
                network_string : "1.2.3.4 / 24"
            },

            columns : [{
                header : this._( "Address and Netmask" ),
                width: 200,
                sortable: true,
                dataIndex : "network_string",
                editor : new Ext.form.TextField({
                    allowBlank : false,
                    vtype : "networkAddress"
                })
            }]
        });

        this.aliasGrid.store.load();

        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                xtype : "label",
                html : this._( "IP Address and Aliases" )
            }, this.aliasGrid ]
        });
        
        Ung.Alpaca.Pages.Network.Aliases.superclass.initComponent.apply( this, arguments );
    },

    saveMethod : "/network/set_aliases"
});

Ung.Alpaca.Pages.Network.Aliases.settingsMethod = "/network/get_aliases";
Ung.Alpaca.Glue.registerPageRenderer( "network", "e_aliases", Ung.Alpaca.Pages.Network.Aliases );

