Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Qos');

if ( Ung.Alpaca.Glue.hasPageRenderer( "qos", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Qos.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function()
    {
        this.priorityStore = [];
        this.priorityMap = {};

        this.priorityNoDefaultStore = [];
        this.priorityNoDefaultMap = {};

        Ung.Alpaca.Util.addToStoreMap( 0, this._( "Default" ), this.priorityStore, this.priorityMap );
        Ung.Alpaca.Util.addToStoreMap( 1, this._( "Very High" ), this.priorityStore, this.priorityMap );
        Ung.Alpaca.Util.addToStoreMap( 2, this._( "High" ), this.priorityStore, this.priorityMap );
        Ung.Alpaca.Util.addToStoreMap( 3, this._( "Medium" ), this.priorityStore, this.priorityMap );
        Ung.Alpaca.Util.addToStoreMap( 4, this._( "Low" ), this.priorityStore, this.priorityMap );
        Ung.Alpaca.Util.addToStoreMap( 5, this._( "Limited" ), this.priorityStore, this.priorityMap );
        Ung.Alpaca.Util.addToStoreMap( 6, this._( "Limited More" ), this.priorityStore, this.priorityMap );
        Ung.Alpaca.Util.addToStoreMap( 7, this._( "Limited Severely" ), this.priorityStore, this.priorityMap );

        Ung.Alpaca.Util.addToStoreMap( 1, this._( "Very High" ), this.priorityNoDefaultStore, this.priorityNoDefaultMap );
        Ung.Alpaca.Util.addToStoreMap( 2, this._( "High" ), this.priorityNoDefaultStore, this.priorityNoDefaultMap );
        Ung.Alpaca.Util.addToStoreMap( 3, this._( "Medium" ), this.priorityNoDefaultStore, this.priorityNoDefaultMap );
        Ung.Alpaca.Util.addToStoreMap( 4, this._( "Low" ), this.priorityNoDefaultStore, this.priorityNoDefaultMap );
        Ung.Alpaca.Util.addToStoreMap( 5, this._( "Limited" ), this.priorityNoDefaultStore, this.priorityNoDefaultMap );
        Ung.Alpaca.Util.addToStoreMap( 6, this._( "Limited More" ), this.priorityNoDefaultStore, this.priorityNoDefaultMap );
        Ung.Alpaca.Util.addToStoreMap( 7, this._( "Limited Severely" ), this.priorityNoDefaultStore, this.priorityNoDefaultMap );

        this.ruleGrid = this.buildRuleGrid();

        this.classGrid = this.buildClassGrid();

        this.bandwidthLabel = new Ext.form.Label({
            xtype : "label",
            html : this._( "WAN Bandwidth" ),
            cls: 'label-section-heading-2'                
        });

        this.bandwidthGrid = this.buildBandwidthGrid();

        this.statisticsGrid = this.buildStatisticsGrid();
        
	this.sessionsGrid = this.buildSessionsGrid();
        
        var percentageStore = this.buildPercentageStore();
        
        var fieldsetItems = [{
            xtype : "checkbox",
            fieldLabel : this._( "Enabled" ),
            name : "qos_settings.enabled"
        }]

        fieldsetItems = fieldsetItems.concat([{
            xtype : "combo",
            fieldLabel : this._( "Default Priority" ),
            name : "qos_settings.default_class",
            mode : "local",
            triggerAction : "all",
            editable : false,
            width : 140,
            listWidth : 110,
            store : this.priorityNoDefaultStore,
        }]);

//         fieldsetItems = fieldsetItems.concat([{
//             xtype : "combo",
//             fieldLabel : this._( "Scaling Factor" ),
// 	    boxLabel : this._( "What is this? Click Help for more information." ),
//             name : "qos_settings.scaling_factor",
//             mode : "local",
//             triggerAction : "all",
//             editable : false,
//             width : 60,
//             listWidth : 50,
//             store : percentageStore
//         }]);

        var items = [{
            html : this._("QoS"),                
            xtype : "label",
            cls : "page-header-text"
        },{
            autoHeight : true,
            defaults : {
                xtype : "textfield",
                itemCls : 'label-width-2'                         
            },
            items : fieldsetItems
        }];

        items = items.concat([
            this.bandwidthLabel, 
            this.bandwidthGrid ,
        ]);
        
        items = items.concat([{
            xtype : "label",
            html : this._( "QoS Rules" ),
            cls: 'label-section-heading-2'
	},{
            autoHeight : true,
            defaults : {
                xtype : "textfield",
                itemCls : 'label-width-2'                         
            },
	    items : [{
		xtype : "combo",
		fieldLabel : this._( "Ping Priority" ),
		name : "qos_settings.prioritize_ping",
		mode : "local",
		triggerAction : "all",
		editable : false,
		width : 140,
		listWidth : 110,
		store : this.priorityStore
	    },{
		xtype : "combo",
		fieldLabel : this._( "DNS Priority" ),
		name : "qos_settings.prioritize_dns",
		mode : "local",
		triggerAction : "all",
		editable : false,
		width : 140,
		listWidth : 110,
		store : this.priorityStore
	    },{
		xtype : "combo",
		fieldLabel : this._( "SSH Priority" ),
		name : "qos_settings.prioritize_ssh",
		mode : "local",
		triggerAction : "all",
		editable : false,
		width : 140,
		listWidth : 110,
		store : this.priorityStore
	    },{
		xtype : "combo",
		fieldLabel : this._( "TCP Control Priority" ),
		name : "qos_settings.prioritize_tcp_control",
		mode : "local",
		triggerAction : "all",
		editable : false,
		width : 140,
		listWidth : 110,
		store : this.priorityStore
	    },{
		xtype : "combo",
		fieldLabel : this._( "Gaming Priority" ),
		boxLabel : this._( "Priority for Wii, Xbox, Playstation, and Others" ),
		name : "qos_settings.prioritize_gaming",
		mode : "local",
		triggerAction : "all",
		editable : false,
		width : 140,
		listWidth : 110,
		store : this.priorityStore
	    }]
	},{
            xtype : "label",
            html : this._( "QoS Custom Rules" ),
            cls: 'label-section-heading-2'                                
        },{
            xtype : "label",
            html : this._( "<font color=\"red\">Note</font>: Custom Rules only match <b>Bypassed</b> traffic." ),
            cls: 'label-text'                                
        }, this.ruleGrid]);

        items = items.concat([{
            xtype : "label",
            html : this._( "QoS Priorities" ),
            cls: 'label-section-heading-2'                                
        }, this.classGrid ]);

        
        items = items.concat([{
            xtype : "label",
            html : this._( "QoS Statistics" ),
            cls: 'label-section-heading-2'                                                
        }, this.statisticsGrid ]);

        items = items.concat([{
            xtype : "label",
            html : this._( "Current Sessions" ),
            cls: 'label-section-heading-2'                                                
        }, this.sessionsGrid ]);
        
        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            items : items
        });
        
        Ung.Alpaca.Pages.Qos.Index.superclass.initComponent.apply( this, arguments );
    },

    buildPercentageStore : function()
    {
        var percentageStore = [];
        percentageStore.push([ 100, "100%"]);
        percentageStore.push([ 95, "95%"]);
        percentageStore.push([ 90, "90%"]);
        percentageStore.push([ 85, "85%"]);
        percentageStore.push([ 80, "80%"]);
        percentageStore.push([ 75, "75%"]);
        //for ( var c = 0 ; c < 9 ; c++ ) {
        //    var v = 100 - ( 10 * ( c + 1 ));
        //    percentageStore[c+2] = [ v, v + "%"  ];
        //}

        return percentageStore;
    },

    buildRuleGrid : function()
    {
        var enabledColumn = new Ung.Alpaca.grid.CheckColumn({
            header : this._( "On" ),
            dataIndex : 'enabled',
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
                    xtype : "combo",
                    fieldLabel : this._( "Priority" ),
                    dataIndex : "priority",
                    listWidth : 150,
                    editable : false,
                    width : 150,
                    triggerAction : "all",
                    mode : "local",
                    store : this.priorityStore
                }]
            },{
                xtype : "fieldset",
                autoWidth : true,
                autoScroll: true,
                autoHeight : true,
                title: "If all of the following conditions are met:",
                items : [{
                    xtype:"rulebuilder",
                    anchor:"98%",
                    dataIndex: "filter",
                    ruleInterfaceValues : this.settings["interface_enum"]
                }]
            }]
        };

        var ruleGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,

            recordFields : [ "id", "enabled", "description", "filter", "priority" ],
            selectable : true,
            sortable : false,
            hasReorder: true,
            hasEdit : true,
            rowEditorConfig : rowEditorConfig,
            
            name : "qos_rules",

            recordDefaults : {
                enabled : true,
                priority : 3,
                filter : "s-addr::",
                description : this._( "[New Entry]" )
            },
            
            plugins : [ enabledColumn ],

            columns : [ enabledColumn, {
                header : this._( "Priority" ),
                width: 100,
                sortable: false,
                fixed : true,
                dataIndex : "priority",
                renderer : function( value, metadata, record )
                {
                    return this.priorityNoDefaultMap[value];
                }.createDelegate( this ),
                editor : new Ext.form.ComboBox({
                    store : this.priorityNoDefaultStore,
                    listWidth : 150,
                    width : 150,
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

        ruleGrid.store.load();
        
        return ruleGrid;
    },

    buildBandwidthGrid : function()
    {
        var bandwidthGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,
            height : 100,
            recordFields : [ "name", "config_type", "os_name", "mac_address", "index", "id", "upload_bandwidth", "download_bandwidth" ],
            selectable : false,
            sortable : false,
            hasReorder: false,
            hasEdit : false,
            tbar : [],
            
            name : "bandwidth",
            
            columns : [{
                header : this._( "WAN" ),
                width: 80,
                sortable: false,
                fixed : true,
                align : "center",
                dataIndex : "name"
            },{
                header : this._( "Config Type" ),
                width: 84,
                fixed : true,
                align : "center",
                sortable: false,
                dataIndex : "config_type",
                renderer : function( value, metadata, record ) { return value + this._( " (wan)" )}.createDelegate( this )
            },{
                header : this._( "Download Bandwidth" ),
                width: 84,
                dataIndex : "download_bandwidth",
                editor : new Ext.form.NumberField({
                    allowBlank : false 
                }),
                renderer : function( value, metadata, record ) { return value + this._( " kbps" )}.createDelegate( this )
            },{
                header : this._( "Upload Bandwidth" ),
                width: 84,
                dataIndex : "upload_bandwidth",
                editor : new Ext.form.NumberField({
                    allowBlank : false 
                }),
                renderer : function( value, metadata, record ) { return value + this._( " kbps" )}.createDelegate( this )
            }]
        });

        var store = bandwidthGrid.store;

        store.on( "update", this.updateTotalBandwidth, this );
        store.load();

        this.updateTotalBandwidth( store, null, null );

        return bandwidthGrid;
    },

    buildClassGrid : function()
    {
        var classGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,
            height : 200,
            recordFields : [ "class_id", "upload_reserved", "upload_limit", "download_reserved", "download_limit" ],
            selectable : false,
            sortable : false,
            hasReorder: false,
            hasEdit : false,
            tbar : [],
            
            name : "qos_classes",
            
            columns : [{
                header : this._( "Priority" ),
                width: 100,
                sortable: false,
                fixed : true,
                dataIndex : "class_id",
                renderer : function( value, metadata, record )
                {
                    return this.priorityMap[value];
                }.createDelegate( this ),
            },{
                header : this._( "Upload Reservation" ),
                width: 40,
                dataIndex : "upload_reserved",
                editor : new Ext.form.NumberField({
                    allowBlank : false,
		    minValue : 1,
		    maxValue : 100
                }),
                renderer : function( value, metadata, record ) { 
		    if (value == 0) 
			return this._("No reservation"); 
		    else 
			return value + "%";
		}.createDelegate( this )
            },{
                header : this._( "Upload Limit" ),
                width: 40,
                dataIndex : "upload_limit",
                editor : new Ext.form.NumberField({
                    allowBlank : false,
		    minValue : 1,
		    maxValue : 100
                }),
                renderer : function( value, metadata, record ) { 
		    if (value == 0) 
			return this._("No limit"); 
		    else 
			return value + "%";
		}.createDelegate( this )
            },{
                header : this._( "Download Reservation" ),
                width: 40,
                dataIndex : "download_reserved",
                editor : new Ext.form.NumberField({
                    allowBlank : false,
		    minValue : 1,
		    maxValue : 100
                }),
                renderer : function( value, metadata, record ) { 
		    if (value == 0) 
			return this._("No reservation"); 
		    else 
			return value + "%";
		}.createDelegate( this )
            },{
                header : this._( "Download Limit" ),
                width: 40,
                dataIndex : "download_limit",
                editor : new Ext.form.NumberField({
                    allowBlank : false,
		    minValue : 1,
		    maxValue : 100
                }),
                renderer : function( value, metadata, record ) { 
		    if (value == 0) 
			return this._("No limit"); 
		    else 
			return value + "%";
		}.createDelegate( this )
            }]
        });

        classGrid.store.load();
        
        return classGrid;
    },

    buildStatisticsGrid : function()
    {
        var store = new Ext.data.GroupingStore({
            proxy : new Ext.data.MemoryProxy( this.settings["status"] ),
            reader : new Ext.data.ArrayReader( {}, [{
                name :  "interface_name",
                mapping : "interface_name"
            },{
                name :  "priority",
                mapping : "priority"
            },{
                name : "rate",
                mapping : "rate"
            },{
                name : "burst",
                mapping : "burst"
            },{
                name : "sent",
                mapping : "sent"
            },{
                name : "tokens",
                mapping : "tokens"
            },{
                name : "ctokens",
                mapping : "ctokens"
            }]),
            groupField : "interface_name",
            sortInfo : { field : "priority", direction : "ASC" }
        });

        var view = new Ext.grid.GroupingView({
            forceFit : true,
            groupTextTpl : '{text}'
        });

        var statisticsGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,

            store : store,
            view : view,
            selectable : false,
            sortable : true,
            saveData : false,
            height : 250,
            
            name : "status",

            tbar : [{
                text : "Refresh",
                iconCls : 'icon-autorefresh',
                handler : this.refreshStatistics,
                scope : this
            }],

            columns : [{
                header : this._( "Interface" ),
                width: 55,
                sortable: true,
                dataIndex : "interface_name"
            },{
                id : "priority",
                header : this._( "Priority" ),
                width: 55,
                sortable: true,
                dataIndex : "priority"
            },{
                header : this._( "Rate" ),
                hidden : true,
                width: 75,
                sortable: true,
                dataIndex : "rate"
            },{
                header : this._( "Burst" ),
                hidden : true,
                width: 75,
                sortable: true,
                dataIndex : "burst"
            },{
                header : this._( "Data" ),
                width: 75,
                sortable: true,
                dataIndex : "sent"
            },{
                header : this._( "Tokens" ),
                hidden : true,
                width: 75,
                sortable: true,
                dataIndex : "tokens"
            },{
                header : this._( "CTokens" ),
                hidden : true,
                width: 75,
                sortable: true,
                dataIndex : "ctokens"
            }]
        });

        statisticsGrid.store.load();
        return statisticsGrid;
    },


    buildSessionsGrid : function()
    {
        var store = new Ext.data.GroupingStore({
            proxy : new Ext.data.MemoryProxy( this.settings["sessions"] ),

            reader : new Ext.data.ArrayReader( {}, [{
                name :  "proto",
                mapping : "proto"
            },{
                name :  "state",
                mapping : "state"
            },{
                name : "src",
                mapping : "src"
            },{
                name : "dst",
                mapping : "dst"
            },{
                name : "src_port",
                mapping : "src_port"
            },{
                name : "dst_port",
                mapping : "dst_port"
            },{
                name : "packets",
                mapping : "packets"
            },{
                name : "bytes",
                mapping : "bytes"
            },{
                name : "priority",
                mapping : "priority"
            }]),
            sortInfo : { field : "proto", direction : "ASC" }
        });

        var sessionsGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,

            store : store,
            selectable : false,
            sortable : true,
            saveData : false,
            height : 250,
            
            name : "sessions",

            tbar : [{
                text : "Refresh",
                iconCls : 'icon-autorefresh',
                handler : this.refreshSessions,
                scope : this
            }],

            columns : [{
                header : this._( "Protocol" ),
                width: 55,
                sortable: true,
                dataIndex : "proto"
            },{
                header : this._( "Source IP" ),
                width: 75,
                sortable: true,
                dataIndex : "src"
            },{
                header : this._( "Destination IP" ),
                width: 75,
                sortable: true,
                dataIndex : "dst"
            },{
                header : this._( "Source Port" ),
                width: 60,
                sortable: true,
                dataIndex : "src_port"
            },{
                header : this._( "Destination Port" ),
                width: 60,
                sortable: true,
                dataIndex : "dst_port"
            },{
                id : "priority",
                header : this._( "Priority" ),
                width: 60,
                sortable: true,
                dataIndex : "priority",
                renderer : function( value, metadata, record )
                {
                    return this.priorityMap[value];
                }.createDelegate( this )
            }]
        });

        sessionsGrid.store.load();
        return sessionsGrid;
    },

    saveMethod : "/qos/set_settings",

    refreshStatistics : function()
    {
        var handler = this.completeRefreshStatistics.createDelegate( this );
        Ung.Alpaca.Util.executeRemoteFunction( "/qos/get_statistics", handler );
    },

    completeRefreshStatistics : function( statistics, response, options )
    {
        if ( !statistics ) return;

        this.statisticsGrid.store.loadData( statistics );
    },

    refreshSessions : function()
    {
        var handler = this.completeRefreshSessions.createDelegate( this );
        Ung.Alpaca.Util.executeRemoteFunction( "/qos/get_sessions", handler );
    },

    completeRefreshSessions : function( sessions, response, options )
    {
        if ( !sessions ) return;

        this.sessionsGrid.store.loadData( sessions );
    },

    updateTotalBandwidth : function( store, record, operation ) {
        var items = store.data.items;
        
        var u = 0;
        var d = 0;

        for ( var c = 0 ; c < items.length ; c++ ) {
            u += items[c].data.upload_bandwidth;
            d += items[c].data.download_bandwidth;
        }

	var d_Mbit = d/1000;
	var u_Mbit = u/1000;

        var message = String.format( this._( "WAN Bandwidth &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<i>Total: {0} kbps ({1} Mbit) download, {2} kbps ({3} Mbit) upload</i>" ), d, d_Mbit, u, u_Mbit );
	this.bandwidthLabel.html = message;
        //this.bandwidthLabel.setText( message );
    }
});

Ung.Alpaca.Pages.Qos.Index.settingsMethod = "/qos/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "qos", "index", Ung.Alpaca.Pages.Qos.Index );
