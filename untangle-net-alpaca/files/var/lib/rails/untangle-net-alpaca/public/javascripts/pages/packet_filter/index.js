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
        this.addAction( "pass", this._( "Pass" ));
        this.addAction( "drop", this._( "Drop" ));
        this.addAction( "reject", this._( "Reject" ));

        var enabledColumn = new Ung.Alpaca.grid.CheckColumn({
            header : this._( "On" ),
            dataIndex : 'enabled',
            sortable: false,
            fixed : true
        });

        this.userRulesGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,

            recordFields : [ "enabled", "system_id", "target", "filter", "description", "is_custom" ],
            selectable : true,
            hasReorder : true,
            
            name : "user_rules",

            recordDefaults : {
                enabled : true,
                system_id : null,
                target : "reject",
                filter : "",
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
                    width : 60,
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

            recordFields : [ "enabled", "system_id", "target", "filter", "description", "is_custom" ],
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

    addAction : function( v, name )
    {
        this.actionMap[v] = name;
        this.actionStore.push([v,name]);
    },

    saveMethod : "/packet_filter/set_settings"
});

Ung.Alpaca.Pages.PacketFilter.Index.settingsMethod = "/packet_filter/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "packet_filter", "index", Ung.Alpaca.Pages.PacketFilter.Index );
