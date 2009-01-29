Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Uvm');

if ( Ung.Alpaca.Glue.hasPageRenderer( "uvm", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Uvm.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function()
    {
        var enabledColumn = new Ung.Alpaca.grid.CheckColumn({
            header : this._( "On" ),
            dataIndex : 'enabled',
            sortable: false,
            fixed : true
        });

        var bypassColumn = new Ung.Alpaca.grid.CheckColumn({
            invert: true,
            header : this._( "Bypass" ),
            dataIndex : 'subscribe',
            sortable: false,
            fixed : true
        });

        this.userRulesGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,

            recordFields : [ "enabled", "filter", "description", "subscribe", "system_id", "is_custom" ],
            selectable : true,
            sortable : false,
            hasReorder: true,
            
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

            plugins : [ enabledColumn, bypassColumn ],

            columns : [enabledColumn, bypassColumn, {
                header : this._( "Description" ),
                width: 200,
                sortable: false,
                dataIndex : "description"
            }]
        });

        this.userRulesGrid.store.load();

        enabledColumn = new Ung.Alpaca.grid.CheckColumn({
            header : this._( "On" ),
            dataIndex : 'enabled',
            sortable: false,
            fixed : true
        });

        this.systemRulesGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,

            recordFields : [ "enabled", "filter", "description", "subscribe", "system_id", "is_custom" ],
            selectable : false,
            
            name : "system_subscriptions",

            tbar : [],

            plugins : [enabledColumn],

            columns : [enabledColumn, {
                header : this._( "Description" ),
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
                    fieldLabel : this._( "Untangle Administration overrides Port Forwards" )
                },{
                    xtype : "checkbox",
                    name : "enable_sip_helper",
                    fieldLabel : this._( "Enable SIP NAT Helper" )
                }]
            },{
                xtype : "label",
                html : this._( "Bypass Rules" )
            }, this.userRulesGrid, {
                xtype : "label",
                html : this._( "System Bypass Rules" )
            }, this.systemRulesGrid ]
        });
        
        Ung.Alpaca.Pages.Uvm.Index.superclass.initComponent.apply( this, arguments );
    },

    saveMethod : "/uvm/set_settings"
});

Ung.Alpaca.Pages.Uvm.Index.settingsMethod = "/uvm/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "uvm", "index", Ung.Alpaca.Pages.Uvm.Index );
