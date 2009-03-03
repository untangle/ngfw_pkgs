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
        this.actionStore = [];
        this.actionMap = {};
        Ung.Alpaca.Util.addToStoreMap( "pass", this._( "Pass" ), this.actionStore, this.actionMap );
        Ung.Alpaca.Util.addToStoreMap( "drop", this._( "Drop" ), this.actionStore, this.actionMap );
        Ung.Alpaca.Util.addToStoreMap( "reject", this._( "Reject" ), this.actionStore, this.actionMap );

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
                    xtype : "combo",
                    fieldLabel : this._( "Action" ),
                    store : this.actionStore,
                    listWidth : 60,
                    width : 70,
                    dataIndex : "target",
                    triggerAction : "all",
                    mode : "local",
                    editable : false
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

        var enabledColumn = new Ung.Alpaca.grid.CheckColumn({
            header : this._( "On" ),
            dataIndex : 'enabled',
            sortable: false,
            fixed : true
        });

        this.userRulesGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,

            recordFields : [ "id", "enabled", "system_id", "target", "filter", "description", "is_custom" ],
            selectable : true,
            hasReorder : true,
            hasEdit : true,
            name : "user_rules",

            rowEditorConfig : rowEditorConfig,

            recordDefaults : {
                enabled : true,
                system_id : null,
                target : "reject",
                filter : "s-addr::",
                description : "[New Entry]",
                is_custom : false
            },

            plugins : [ enabledColumn ],

            columns : [enabledColumn, {
                header : this._( "Action" ),
                width: 80,
                fixed : true,
                sortable: false,
                dataIndex : "target",
                renderer : function( value, metadata, record )
                {
                    return this.actionMap[value];
                }.createDelegate( this ),
                editor : new Ext.form.ComboBox({
                    store : this.actionStore,
                    listWidth : 60,
                    width : 70,
                    triggerAction : "all",
                    mode : "local",
                    editable : false
                })
            },{
                header : this._( "Description" ),
                width: 200,
                sortable: false,
                dataIndex : "description",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
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

            recordFields : [ "id", "enabled", "system_id", "target", "filter", "description", "is_custom" ],
            selectable : false,
            
            name : "system_rules",

            tbar : [],
            
            plugins : [ enabledColumn ],

            columns : [enabledColumn,{
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
            items : [
            {
                xtype : "label",
                html : this._( "Packet Filters" ),
                cls: 'page-header-text'                
            }, 
            {
                xtype : "label",
                html : this._( "User Packet Filter Rules" ),
                cls: 'label-section-heading-2'                
            }, this.userRulesGrid, {
                xtype : "label",
                html : this._( "System Packet Filter Rules" ),
                cls: 'label-section-heading-2'                
            }, this.systemRulesGrid ]
        });
        
        Ung.Alpaca.Pages.PacketFilter.Index.superclass.initComponent.apply( this, arguments );
    },

    saveMethod : "/packet_filter/set_settings"
});

Ung.Alpaca.Pages.PacketFilter.Index.settingsMethod = "/packet_filter/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "packet_filter", "index", Ung.Alpaca.Pages.PacketFilter.Index );
