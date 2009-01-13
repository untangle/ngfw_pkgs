Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Uvm');

if ( Ung.Alpaca.Glue.hasPageRenderer( "uvm", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Uvm.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    constructor : function( config )
    {
        this.userRulesGrid = new Ung.Alpaca.EditorGridPanel({
            settings : config.settings,

            recordFields : [ "enabled", "filter", "description", "subscribe", "system_id", "is_custom" ],
            selectable : true,
            sortable : false,
            
            name : "user_subscriptions",

            tbar : [ Ung.Alpaca.EditorGridPanel.AddButtonMarker,
                     Ung.Alpaca.EditorGridPanel.DeleteButtonMarker, {
                         text : "Edit",
                         handler : this.editEntry,
                         scope : this
                     }],

            recordDefaults : {
                enabled : true,
                filter : "",
                description : "[New Entry]",
                subscribe : false,
                system_id : null,
                is_custom : false
            },

            columns : [{
                header : "On",
                width: 55,
                sortable: false,
                dataIndex : "enabled",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            },{
                header : "Bypass",
                width: 55,
                sortable: false,
                dataIndex : "subscribe",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            },{
                header : "Description",
                width: 200,
                sortable: false,
                dataIndex : "description"
            }]
        });

        this.userRulesGrid.store.load();

        this.systemRulesGrid = new Ung.Alpaca.EditorGridPanel({
            settings : config.settings,

            recordFields : [ "enabled", "filter", "description", "subscribe", "system_id", "is_custom" ],
            selectable : false,
            
            name : "system_subscriptions",

            tbar : [],

            columns : [{
                header : "On",
                width: 55,
                sortable: false,
                dataIndex : "enabled",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            },{
                header : "Description",
                width: 200,
                sortable: false,
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
                autoHeight : true,
                items : [{
                    xtype : "checkbox",
                    name : "uvm.override_redirects",
                    fieldLabel : "Untangle Administration overrides Port Forwards"
                }]
            },{
                xtype : "label",
                html : "Bypass Rules"
            }, this.userRulesGrid, {
                xtype : "label",
                html : "System Bypass Rules"
            }, this.systemRulesGrid ]
        });
        
        Ung.Alpaca.Pages.Uvm.Index.superclass.constructor.apply( this, arguments );
    },

    saveMethod : "/uvm/set_settings",
});

Ung.Alpaca.Pages.Uvm.Index.settingsMethod = "/uvm/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "uvm", "index", Ung.Alpaca.Pages.Uvm.Index );
