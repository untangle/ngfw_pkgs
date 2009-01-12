Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.PacketFilter');

if ( Ung.Alpaca.Glue.hasPageRenderer( "dhcp", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.PacketFilter.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    constructor : function( config )
    {
        var enabledColumn = new Ext.grid.CheckColumn({
            header : "On",
            dataIndex : "enabled",
            width : 55
        });

        this.userRulesGrid = new Ung.Alpaca.EditorGridPanel({
            settings : config.settings,

            recordFields : [ "enabled", "system_id", "target", "filter", "description", "is_custom" ],
            editable : true,
            
            name : "user_rules",

            recordDefaults : {
                enabled : true,
                system_id : null,
                target : "reject",
                filter : "",
                description : "[New Entry]",
                is_custom : false
            },

            columns : [ enabledColumn, {
                header : "Action",
                width: 200,
                sortable: true,
                dataIndex : "target",
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

        this.userRulesGrid.store.load();

        this.systemRulesGrid = new Ung.Alpaca.EditorGridPanel({
            settings : config.settings,

            recordFields : [ "enabled", "system_id", "target", "filter", "description", "is_custom" ],
            editable : true,
            
            name : "system_rules",

            tbar : [],

            columns : [{
                header : "On",
                width: 200,
                sortable: true,
                dataIndex : "enabled",
                editor : new Ext.form.Checkbox({
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

        this.systemRulesGrid.store.load();
        
        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                xtype : "label",
                html : "User Packet Filter Rules"
            }, this.userRulesGrid, {
                xtype : "label",
                html : "System Packet Filter Rules"
            }, this.systemRulesGrid ]
        });
        
        Ung.Alpaca.Pages.PacketFilter.Index.superclass.constructor.apply( this, arguments );
    },

    saveMethod : "/packet_filter/set_settings",
});

Ung.Alpaca.Pages.PacketFilter.Index.settingsMethod = "/packet_filter/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "packet_filter", "index", Ung.Alpaca.Pages.PacketFilter.Index );
