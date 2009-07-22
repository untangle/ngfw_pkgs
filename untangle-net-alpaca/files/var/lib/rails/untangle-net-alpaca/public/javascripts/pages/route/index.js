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
        this.gatewayStore = [];
        this.gatewayMap = {};
        this.gatewayNameToIDMap = {};

        this.gatewayStore.push(["1.2.3.4", "1.2.3.4"]);
        var ie = this.settings["interface_enum"];
        for ( var c = 0; c < ie.length ; c++ ) {
            var i = ie[c];
            Ung.Alpaca.Util.addToStoreMap( i[0], i[1], this.gatewayStore, this.gatewayMap );
            this.gatewayNameToIDMap[i[1]] = i[0];
        }

        this.combobox = new Ext.form.ComboBox({
            name : "combobox-gateway",
            store : this.gatewayStore,
            listWidth : 60,
            width : 70,
            triggerAction : "all",
            mode : "local",
            editable : true
        });

        this.combobox.getValue = this.combobox.getRawValue;

        this.staticRoutesGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,

            recordFields : [ "id", "rule_id", "target", "netmask", "gateway", "name", "category", 
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
                header : this._( "Target" ),
                width: 200,
                sortable: false,
                dataIndex : "target",
                editor : new Ext.form.TextField({
                    allowBlank : false,
                    vtype : 'networkAddress'
                })
            },{
                header : this._( "Netmask" ),
                width: 200,
                sortable: false,
                dataIndex : "netmask",
                editor : new Ext.form.TextField({
                    allowBlank : false,
                    vtype : 'ipAddress'
                })
            },{
                header : this._( "Gateway" ),
                width: 200,
                sortable: false,
                dataIndex : "gateway",
                renderer : function( value, metadata, record )
                {
                    var name = this.gatewayMap[value];
                    return ( name == null ) ? value : name;
                }.createDelegate( this ),
                editor : this.combobox
            },{
                header : this._( "Description" ),
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

            recordFields : [ "target", "netmask", "gateway", "interface" ],
            
            saveData : false,
            name : "active_routes",

            tbar : [],

            columns : [{
                header : this._( "Target" ),
                width: 200,
                sortable: true,
                dataIndex : "target",
                renderer : this.renderActiveTarget.createDelegate( this )
            },{
                header : this._( "Netmask" ),
                width: 200,
                sortable: true,
                dataIndex : "netmask"
            },{
                header : this._( "Gateway" ),
                width: 200,
                sortable: true,
                dataIndex : "gateway",
                renderer : this.renderActiveGateway.createDelegate( this )
            }]
        });

        this.activeRoutesGrid.store.load();

        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                xtype : "label",
                html : this._( "Routes" ),
                cls: 'page-header-text'                
            },{
                xtype : "label",
                html : this._( "Static Routes" ),
                cls: 'label-section-heading-2' 
            }, this.staticRoutesGrid, {
                xtype : "label",
                html : this._( "Active Routes" ),
                cls: 'label-section-heading-2' 
            }, this.activeRoutesGrid ]
        });
        
        Ung.Alpaca.Pages.Route.Index.superclass.initComponent.apply( this, arguments );
    },

    renderActiveTarget : function( value, metadata, record )
    {
        if ( value == "default" ) {
            return this._( "default" );
        }

        return value;
    },

    renderActiveGateway : function( value, metadata, record )
    {
        if ( value == "0.0.0.0" ) {
            return record.data["interface"];
        }

        return value;
    },
    
    updateSettings : function( settings )
    {
        Ung.Alpaca.Pages.Route.Index.superclass.updateSettings.apply( this, arguments );

        /* Update all of the interface routes */
        var c = 0, staticRoutes = settings["static_routes"];
        for ( c = 0 ; c < staticRoutes.length ; c++ ) {
            var staticRoute = staticRoutes[c];
            var gateway = this.gatewayNameToIDMap[staticRoute["gateway"]];
            if ( gateway != null ) staticRoute["gateway"] = gateway;
        }
    },

    saveMethod : "/route/set_settings"
});

Ung.Alpaca.Pages.Route.Index.settingsMethod = "/route/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "route", "index", Ung.Alpaca.Pages.Route.Index );
