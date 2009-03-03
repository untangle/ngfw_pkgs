Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.MultiWan');


if ( Ung.Alpaca.Glue.hasPageRenderer( "multi_wan", "failover" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.MultiWan.Failover = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function()
    {
        this.interfaceStore = [];
        this.interfaceMap = {};

        for ( var c = 0 ;c < this.settings["interfaces"].length ; c++ ) {
            var i = this.settings["interfaces"][c];
            Ung.Alpaca.Util.addToStoreMap( i.index, i.name, this.interfaceStore, this.interfaceMap )
        }

        this.interfaceMap[-1] = this._( "Total" );

        this.typeMap = {};
        this.typeStore = [];

        Ung.Alpaca.Util.addToStoreMap( "ping", this._( "Ping" ), this.typeStore, this.typeMap );
        Ung.Alpaca.Util.addToStoreMap( "arp", this._( "ARP" ), this.typeStore, this.typeMap  );
        Ung.Alpaca.Util.addToStoreMap( "dns", this._( "DNS" ), this.typeStore, this.typeMap );
        Ung.Alpaca.Util.addToStoreMap( "http", this._( "HTTP" ), this.typeStore, this.typeMap );
        Ung.Alpaca.Util.addToStoreMap( "custom", this._( "Custom" ), this.typeStore, this.typeMap );

        var grid = this.testGrid( this.settings );

        var statusGrid = this.statusGrid( this.settings );

        var items = [];

        items.push({
                xtype : "label",
                cls : 'page-header-text',                    
                html : this._( "Failover" )
            },{
                autoHeight : true,
                items : [{
                    xtype : "checkbox",
                    fieldLabel : this._( "Enabled" ),
                    name : "failover_settings.enabled"
                }]
            },{
                xtype : "label",
                html : this._( "Failover Detection Rules" ),
                cls: 'label-section-heading-2'                                
            },grid,{
                xtype : "label",
                html : this._( "Interface Uptimes" ),
                cls: 'label-section-heading-2'                                
            });
        
        var uptimes = this.settings["uptimes"];

        if ( uptimes == null || uptimes.length == 0 ) {
            items.push({
                xtype : "label",
                html : this._( "There is no data available for the WAN interfaces." )
            });
        } else {
            var uptimeItems = [];

            for ( var c = 0 ; c < uptimes.length ; c++ ) {
                var u = uptimes[c];
                
                uptimeItems.push({
                    xtype : "textfield",
                    fieldLabel : this.interfaceMap[u["interface"]],
                    defaultValue : String.format( this._( "{0}% over the last {1} {2}"), u["percent"], u["duration"], u["unit"] ),
                    readOnly : true
                });
            }
            
            items.push({
                xtype : "fieldset",
                autoHeight : true,
                items : uptimeItems
            });
        }

        items.push({
                xtype : "label",
                html : this._( "Failover Detection Logs" ),
                cls: 'label-section-heading-2'                                
        }, statusGrid );
                   
        
        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            items : items
        });

        Ung.Alpaca.Pages.MultiWan.Failover.superclass.initComponent.apply( this, arguments );
    },
    
    saveMethod : "/multi_wan/set_settings",

    testGrid : function( settings )
    {
        var items = [ 
            this.pingPanel( settings ),
            this.arpPanel( settings ),
            this.dnsPanel( settings ),
            this.httpPanel( settings ),
            this.customPanel( settings )
        ];

        this.switchBlade = new Ext.Panel({
            layout : 'card',
            activeItem : 0,
            border : false,
            defaults : {
                border : false
            },
            items : items
        });

        var rowEditorConfig = {
            xtype : "roweditor",
            onShowRowEditorConfig : this.onShowRowEditorConfig.createDelegate( this ),
            panelItems : [{
                xtype : "fieldset",
                autoHeight : true,
                items : [{
                    xtype: "checkbox",
                    fieldLabel : this._( "Enabled" ),
                    dataIndex: "enabled"
                },{
                    xtype : "combo",
                    fieldLabel : this._( "Interface" ),
                    dataIndex : "interface",
                    store : this.interfaceStore,
                    width: 70,
                    listWidth : 60,
                    triggerAction : "all",
                    mode : "local",
                    editable : false
                },{
                    xtype: "textfield",
                    fieldLabel : this._( "Description" ),
                    dataIndex: "description",
                    width: 360
                }]
            },{
                xtype : "fieldset",
                autoHeight : true,
                items : [{
                    xtype : "numberfield",
                    width : 60,
                    fieldLabel : this._( "Delay" ),
                    dataIndex : "delay",
                    boxLabel : this._( "(seconds)" )
                },{
                    xtype : "numberfield",
                    width : 60,
                    fieldLabel : this._( "Timeout" ),
                    dataIndex : "timeout",
                    boxLabel : this._( "(seconds)" )
                },{
                    xtype : "numberfield",
                    width : 60,
                    dataIndex : "failures",
                    fieldLabel : this._( "Consecutive Failures" )
                }]},{
                    xtype : "combo",
                    fieldLabel : this._( "Test Type" ),
                    dataIndex : "type",
                    store : this.typeStore,
                    width: 70,
                    listWidth : 60,
                    triggerAction : "all",
                    mode : "local",
                    editable : false,
                    listeners : {
                        "select" : {
                            fn : this.onSelectTestType,
                            scope : this
                        }
                    }
                }, this.switchBlade ]
        };
        
        var grid = new Ung.Alpaca.EditorGridPanel({
            settings : settings,
            recordFields : [ "id", "enabled", "description", "type", "params", "interface", "timeout",
                             "failures", "delay" ],
            name : "user_tests",
            selectable : true,
            sortable : true,
            hasEdit : true,
            hasReorder : false,
            
            rowEditorConfig : rowEditorConfig,

            recordDefaults : {
                enabled : true,
                type : "ping",
                delay : 5,
                timeout : 3,
                failures : 7,
                params : {},
                description : "[New Entry]",
                "interface" : 1
            },

            columns : [new Ung.Alpaca.grid.CheckColumn({
                header : this._( "On" ),
                dataIndex : 'enabled',
                sortable: false,
                fixed : true
            }),{
                header : this._( "Interface" ),
                width: 70,
                sortable: false,
                fixed : true,
                dataIndex : "interface",
                renderer : function( value, metadata, record )
                {
                    return this.interfaceMap[value];
                }.createDelegate( this ),
                editor : new Ext.form.ComboBox({
                    store : this.interfaceStore,
                    listWidth : 60,
                    width : 70,
                    triggerAction : "all",
                    mode : "local",
                    editable : false
                })
            },{
                header : this._( "Type" ),
                width: 70,
                sortable: false,
                fixed : true,
                dataIndex : "type",
                renderer : function( value, metadata, record )
                {
                    return this.typeMap[value];
                }.createDelegate( this )
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

        grid.store.load();
        return grid;
    },

    pingPanel : function( settings )
    {
        return new Ext.Panel({
            layout : 'form',
            defaults : {
                xtype : "fieldset",
                autoHeight : true
            },
            items : [{
                items : [{
                    xtype : "textfield",
                    vtype : "ipAddress",
                    dataIndex : "params.ping_address",
                    fieldLabel : this._( "IP Address" )
                },{
                    xtype : "button",
                    text : this._( "Generate Suggestions" )
                }]
            }]
        });
    },

    arpPanel : function()
    {
        return new Ext.Panel({
            layout : 'form',
            defaults : {
                xtype : "fieldset",
                autoHeight : true
            },
            items : [{
                xtype : 'label',
                html : this._( "ARP the default gateway for this interface." )
            }]
        });        
    },

    dnsPanel : function()
    {
        return new Ext.Panel({
            layout : 'form',
            defaults : {
                xtype : "fieldset",
                autoHeight : true
            },
            items : [{
                xtype : 'label',
                html : this._( "Generate DNS requests to your upstream DNS servers." )
            }]
        });        
    },

    httpPanel : function()
    {
        return new Ext.Panel({
            layout : 'form',
            defaults : {
                xtype : "fieldset",
                autoHeight : true
            },
            items : [{
                items : [{
                    xtype : "textfield",
                    fieldLabel : this._( "URL" ),
                    dataIndex : "params.http_url"
                }]
            }]});
    },
    
    customPanel : function()
    {
        return new Ext.Panel({
            layout : 'form',
            defaults : {
                xtype : "fieldset",
                autoHeight : true
            },
            items : [{
                items : [{
                    xtype : "textarea",
                    fieldLabel : this._( "Script" ),
                    dataIndex : "params.script"
                }]
            }]
        });        
    },

    statusGrid : function( settings )
    {
        var grid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,
            recordFields : [ "start_time", "end_time", "description", "interface", "online" ],
            recordTypes : {
                "start_time" : "date",
                "end_time" : "date"
            },
            
            name : "status",

            tbar : [{
                text : "Refresh",
                handler : this.refreshStatistics,
                scope : this
            }],
            
            columns : [{
                header : this._( "Start Time" ),
                width: 125,
                fixed : true,
                sortable: true,
                dataIndex : "start_time",
                renderer : Ext.util.Format.dateRenderer( this.i18n.map["timestamp_fmt"] )
            },{
                header : this._( "End Time" ),
                dataIndex : "end_time",
                width: 125,
                fixed : true,
                sortable: true,
                renderer : Ext.util.Format.dateRenderer( this.i18n.map["timestamp_fmt"] )
            },{
                header : this._( "Interface" ),
                width: 70,
                fixed : true,
                sortable: true,
                dataIndex : "interface",
                renderer : function( value, metadata, record )
                {
                    return this.interfaceMap[value];
                }.createDelegate( this )
            },{
                header : this._( "Description" ),
                width: 200,
                sortable: true,
                dataIndex : "description"
            },{
                header : this._( "Online" ),
                dataIndex : 'online',
                sortable: true,
                fixed : true,
                width : 50,
                renderer : this.renderOnlineStatus.createDelegate( this )
            }]
        });
        
        grid.store.load();

        return grid;
    },
    
    addInterface : function( v, name )
    {
        this.interfaceMap[v] = name;
        this.interfaceStore.push([v,name]);
    },

    onShowRowEditorConfig : function( component )
    {
        var index = -1;
        var combo = component.find( "dataIndex", "type" )[0];
        
        var v = combo.getValue();
        index = -1;
        
        for ( var c = 0 ; c < this.typeStore.length ; c++ ) {
            if ( this.typeStore[c][0] == v ) {
                index = c;
                break;
            }
        }

        if ( index < 0 ) {
            return;
        }

        if ( this.switchBlade.layout ) {
            this.switchBlade.layout.setActiveItem( index );
        } else {
            this.switchBlade.activeItem = index;
        }
    },

    onSelectTestType : function( __, record, index )
    {
        this.switchBlade.layout.setActiveItem( index );
    },

    renderOnlineStatus : function( value, metadata, record )
    {
        var divClass = ( value ) ? "ua-cell-enabled" : "ua-cell-disabled";
        
        return "<div class='" + divClass + "'>&nbsp;</div>";
    }
});

Ung.Alpaca.Pages.MultiWan.Failover.settingsMethod = "/multi_wan/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "multi_wan", "failover", Ung.Alpaca.Pages.MultiWan.Failover );


