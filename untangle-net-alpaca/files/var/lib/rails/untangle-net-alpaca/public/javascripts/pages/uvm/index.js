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

        var rowEditorConfig = {
            xtype: "roweditor",
            panelItems: [{
                xtype : "fieldset",
                autoHeight : true,
                items:[{
                    xtype: "checkbox",
                    fieldLabel : this._( "Enabled" ),
                    dataIndex: "enabled"
                },{
                    xtype: "textfield",
                    fieldLabel : this._( "Description" ),
                    dataIndex: "description",
                    width: 360
                },{
                    xtype : "checkbox",
                    fieldLabel : this._( "Bypass" ),
                    dataIndex : "subscribe",
                    invert : true
                }]
            },{
                xtype : "fieldset",
                autoWidth : true,
                autoScroll: true,
                autoHeight : true,
                title: "If all of the following conditions are met:",
                items:[{
                    xtype:"rulebuilder",
                    anchor:"98%",
                    dataIndex: "filter",
                    ruleInterfaceValues : this.settings["interface_enum"]
                }]
            }]
        };

        this.userRulesGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,

            recordFields : [ "id", "enabled", "filter", "description", "subscribe", "system_id", "is_custom" ],

            sortable : false,
            hasReorder: true,
            hasEdit : true,
            rowEditorConfig : rowEditorConfig,
            hasDelete: true,
            
            name : "user_subscriptions",

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

            recordFields : [ "id", "enabled", "filter", "description", "subscribe", "system_id", "is_custom" ],
            
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
                xtype : "label",
                cls: 'label-section-heading-2',                    
                html : this._( "Bypass Rules" )
            }, this.userRulesGrid, {
                xtype : "label",
                cls: 'label-section-heading-2',                    
                html : this._( "System Bypass Rules" )
            }, this.systemRulesGrid ]
        });
        
        Ung.Alpaca.Pages.Uvm.Index.superclass.initComponent.apply( this, arguments );
    },

    saveMethod : "/uvm/set_settings"
});

Ung.Alpaca.Pages.Uvm.Index.settingsMethod = "/uvm/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "uvm", "index", Ung.Alpaca.Pages.Uvm.Index );
