Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.PacketFilter');

if ( Ung.Alpaca.Glue.hasPageRenderer( "packet_filter", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.PacketFilter.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function()
    {
        this.userRulesGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,

            recordFields : [ "enabled", "system_id", "target", "filter", "description", "is_custom" ],
            selectable : true,
            
            name : "user_rules",

            recordDefaults : {
                enabled : true,
                system_id : null,
                target : "reject",
                filter : "",
                description : "[New Entry]",
                is_custom : false
            },

            columns : [{
                header : this._( "Action" ),
                width: 200,
                sortable: true,
                dataIndex : "target",
                editor : new Ext.form.TextField({
                    allowBlank : false 
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

        this.userRulesGrid.store.load();

        this.systemRulesGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,

            recordFields : [ "enabled", "system_id", "target", "filter", "description", "is_custom" ],
            selectable : false,
            
            name : "system_rules",

            tbar : [],

            columns : [{
                header : this._( "On" ),
                width: 200,
                sortable: true,
                dataIndex : "enabled",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            },{
                header : this._( "Description" ),
                width: 200,
                sortable: true,
                dataIndex : "description"
            }]
        });

        this.systemRulesGrid.store.load();
        
        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                xtype : "label",
                html : this._( "User Packet Filter Rules" )
            }, this.userRulesGrid, {
                xtype : "label",
                html : this._( "System Packet Filter Rules" )
            }, this.systemRulesGrid ]
        });
        
        Ung.Alpaca.Pages.PacketFilter.Index.superclass.initComponent.apply( this, arguments );
    },

    saveMethod : "/packet_filter/set_settings"
});

Ung.Alpaca.Pages.PacketFilter.Index.settingsMethod = "/packet_filter/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "packet_filter", "index", Ung.Alpaca.Pages.PacketFilter.Index );
