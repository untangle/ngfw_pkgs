Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Route');

if ( Ung.Alpaca.Glue.hasPageRenderer( "route", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Route.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function()
    {
        this.staticRoutesGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,

            recordFields : [ "rule_id", "target", "netmask", "gateway", "name", "category", 
                             "description", "live", "alert", "log", "settings_id" ],
            selectable : true,
            
            name : "static_routes",

            recordDefaults : {
                rule_id : 0,
                target : "",
                netmask : "255.255.255.0",
                gateway : "",
                name : "",
                category : "[]",
                description : "[New Route]",
                live : true,
                alert : true,
                log : true,
                settings_id : 0
            },

            columns : [{
                header : "Target",
                width: 200,
                sortable: false,
                dataIndex : "target",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            },{
                header : "Netmask",
                width: 200,
                sortable: false,
                dataIndex : "netmask",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            },{
                header : "Gateway",
                width: 200,
                sortable: false,
                dataIndex : "gateway",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            },{
                header : "Description",
                width: 200,
                sortable: false,
                dataIndex : "name",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            }]
        });

        this.staticRoutesGrid.store.load();

        this.activeRoutesGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,

            recordFields : [ "target", "netmask", "gateway" ],
            
            saveData : false,
            name : "active_routes",

            tbar : [],

            columns : [{
                header : "Target",
                width: 200,
                sortable: true,
                dataIndex : "target"
            },{
                header : "Netmask",
                width: 200,
                sortable: true,
                dataIndex : "netmask"
            },{
                header : "Gateway",
                width: 200,
                sortable: true,
                dataIndex : "gateway"
            }]
        });

        this.activeRoutesGrid.store.load();

        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                xtype : "label",
                html : "Static Routes"
            }, this.staticRoutesGrid, {
                xtype : "label",
                html : "Active Routes"
            }, this.activeRoutesGrid ]
        });
        
        Ung.Alpaca.Pages.Route.Index.superclass.initComponent.apply( this, arguments );
    },

    saveMethod : "/route/set_settings"
});

Ung.Alpaca.Pages.Route.Index.settingsMethod = "/route/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "route", "index", Ung.Alpaca.Pages.Route.Index );
