Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Qos');

if ( Ung.Alpaca.Glue.hasPageRenderer( "qos", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Qos.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    constructor : function( config )
    {
        this.qosGrid = this.buildQosGrid( config );
        this.statisticsGrid = this.buildStatisticsGrid( config );
        
        var percentageStore = this.buildPercentageStore();
        var priorityStore = this.buildPriorityStore();

        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                autoHeight : true,
                defaults : {
                    xtype : "textfield"
                },
                items : [{
                    xtype : "checkbox",
                    fieldLabel : "Enabled",
                    name : "qos_settings.enabled"
                },{
                    fieldLabel : "Internet Download Bandwidth",
                    name : "qos_settings.download",
                    boxLabel : "kbps"
                },{
                    xtype : "combo",
                    fieldLabel : "Limit Download To",
                    name : "qos_settings.download_percentage",
                    mode : "local",
                    triggerAction : "all",
                    editable : false,
                    width : 60,
                    listWidth : 50,
                    store : percentageStore
                }]
            },{
                autoHeight : true,
                defaults : {
                    xtype : "textfield"
                },
                items : [{
                    fieldLabel : "Internet Upload Bandwidth",
                    name : "qos_settings.upload",
                    
                    boxLabel : "kbps"
                },{
                    xtype : "combo",
                    fieldLabel : "Limit Upload To",
                    name : "qos_settings.upload_percentage",
                    mode : "local",
                    triggerAction : "all",
                    editable : false,
                    width : 60,
                    listWidth : 50,
                    store : percentageStore
                }]
            },{
                autoHeight : true,
                defaults : {
                    xtype : "textfield"
                },
                items : [{
                    xtype : "combo",
                    fieldLabel : "Ping Priority",
                    name : "qos_settings.prioritize_ping",
                    mode : "local",
                    triggerAction : "all",
                    editable : false,
                    width : 70,
                    listWidth : 60,
                    store : priorityStore
                },{
                    xtype : "combo",
                    fieldLabel : "ACK Priority",
                    boxLabel : "A High ACK Priority speeds up downloads while uploading",
                    name : "qos_settings.prioritize_ack",
                    mode : "local",
                    triggerAction : "all",
                    editable : false,
                    width : 70,
                    listWidth : 60,
                    store : priorityStore
                },{
                    xtype : "combo",
                    fieldLabel : "Gaming Priority",
                    name : "qos_settings.prioritize_gaming",
                    mode : "local",
                    triggerAction : "all",
                    editable : false,
                    width : 70,
                    listWidth : 60,
                    store : priorityStore
                }]
            },{
                xtype : "label",
                html : "QoS Rules"
            }, this.qosGrid, {
                xtype : "label",
                html : "QoS Statistics"
            }, this.statisticsGrid ]
        });
        
        Ung.Alpaca.Pages.Qos.Index.superclass.constructor.apply( this, arguments );
    },

    buildPercentageStore : function()
    {
        var percentageStore = [];
        percentageStore.push([ 100, "100%"]);
        percentageStore.push([ 95, "95%"]);

        for ( var c = 0 ; c < 9 ; c++ ) {
            var v = 100 - ( 10 * ( c + 1 ));
            percentageStore[c+2] = [ v, v + "%"  ];
        }

        return percentageStore;
    },
    
    buildPriorityStore : function()
    {
        return [[ 10, "High" ], [ 20, "Normal" ], [ 30, "Low" ]];
    },

    buildQosGrid : function( config )
    {
        var qosGrid = new Ung.Alpaca.EditorGridPanel({
            settings : config.settings,

            recordFields : [ "enabled", "description", "filter", "priority" ],
            selectable : true,
            sortable : false,
            
            name : "qos_rules",

            recordDefaults : {
                enabled : true,
                priority : 20,
                filter : "",
                description : "[New Entry]",
            },

            columns : [{
                header : "On",
                width: 55,
                sortable: true,
                dataIndex : "enabled",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            },{
                header : "Priority",
                width: 75,
                sortable: true,
                dataIndex : "priority",
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

        qosGrid.store.load();
        
        return qosGrid;
    },

    buildStatisticsGrid : function( config )
    {
        var statisticsGrid = new Ung.Alpaca.EditorGridPanel({
            settings : config.settings,

            recordFields : [ "priority", "rate", "burst", "sent", "tokens", "ctokens" ],
            selectable : false,
            sortable : true,
            saveData : false,
            
            name : "status",

            tbar : [{
                text : "Refresh",
                handler : this.refreshStatistics,
                scope : this
            }],

            columns : [{
                header : "Priority",
                width: 55,
                sortable: true,
                dataIndex : "priority",
            },{
                header : "Rate",
                width: 75,
                sortable: true,
                dataIndex : "rate"
            },{
                header : "Burst",
                width: 75,
                sortable: true,
                dataIndex : "burst"
            },{
                header : "Sent",
                width: 75,
                sortable: true,
                dataIndex : "sent"
            },{
                header : "Tokens",
                width: 75,
                sortable: true,
                dataIndex : "tokens"
            },{
                header : "CTokens",
                width: 75,
                sortable: true,
                dataIndex : "ctokens"
            }]
        });

        statisticsGrid.store.load();
        return statisticsGrid;
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
    }

});

Ung.Alpaca.Pages.Qos.Index.settingsMethod = "/qos/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "qos", "index", Ung.Alpaca.Pages.Qos.Index );
