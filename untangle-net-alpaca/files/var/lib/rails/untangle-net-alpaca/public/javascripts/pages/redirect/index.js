Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Redirect');

if ( Ung.Alpaca.Glue.hasPageRenderer( "redirect", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Redirect.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function()
    {
        var enabledColumn = new Ung.Alpaca.grid.CheckColumn({
            //invert: true,
            header : this._( "On" ),
            dataIndex : "enabled",
            sortable: false,
            fixed : true
        });

        this.troubleShootButton = new Ext.Toolbar.Button({
            text : this._("Troubleshooting"),
            handler : this.troubleshoot,
            scope : this,
            disabled : true
        });

        this.userRulesGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,

            recordFields : ["id", "enabled", "system_id", "new_ip", "new_enc_id", "filter", "description", "is_custom" ],
            selectable : true,
            sortable : false,
            hasEdit : true,
            hasReorder: true,
            
            rowEditorConfig: {
                xtype: "roweditor",
                panelItems: [{
                    xtype : "fieldset",
                    autoHeight : true,
                    items:[{
                        xtype: "checkbox",
                        fieldLabel : this._( "Enabled" ),
                        dataIndex: "enabled"
                    }, {
                        xtype: "textfield",
                        fieldLabel : this._( "Description" ),
                        dataIndex: "description",
                        width: 360
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
                        ruleInterfaceValues : this.settings["interface_enum"],
                        rules : [{
                            name : "s-addr",
                            displayName : Ung.Alpaca.Util._("Source Address"),
                            type: "text",
                            vtype : "address"
                        },{
                            name : "d-local",
                            displayName : Ung.Alpaca.Util._("Destined Local"),
                            type: "boolean"
                        },{
                            name : "d-addr",
                            displayName : Ung.Alpaca.Util._("Destination Address"),
                            type: "text",
                            vtype:"address"
                        },{
                            name : "d-port",
                            displayName : Ung.Alpaca.Util._("Destination Port"),
                            type: "text",
                            vtype : "port"
                        },{
                            name:"s-intf",
                            displayName : Ung.Alpaca.Util._("Source Interface"),
                            type: "checkgroup",
                            values : this.settings["interface_enum"]
                        },{
                            name : "protocol",
                            displayName : Ung.Alpaca.Util._("Protocol"),
                            type: "checkgroup",
                            values: Ung.Alpaca.RuleBuilder.DEFAULT_PROTOCOL_VALUES
                        }]
                    }]
                },{
                    xtype : "fieldset",
                    autoHeight : true,
                    title: "Forward traffic to the following location",
                    items:[{
                        xtype: "textfield",
                        fieldLabel : this._( "New Destination" ),
                        dataIndex: "new_ip",
                        vtype : "ipAddress",
                        width: 150
                    }, {
                        xtype: "numberfield",
                        vtype : "port",
                        fieldLabel : this._( "New Port (optional)" ),
                        dataIndex: "new_enc_id",
                        width: 150
                        
                    }]
                }]
            },
            name : "user_redirects",

            tbar : [ Ung.Alpaca.EditorGridPanel.AddButtonMarker,
                     Ung.Alpaca.EditorGridPanel.DeleteButtonMarker,
                     this.troubleShootButton ],
        
            recordDefaults : {
                enabled : true,
                system_id : null,
                new_ip : "1.2.3.4",
                new_enc_id : "",
                filter : "d-port::&&d-local::true&&protocol::tcp",
                description : "[New Entry]",
                is_custom : false
            },
            plugins: [enabledColumn],
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

        this.userRulesGrid.store.load();

        /* Add a listener to enable the troubleshoot button */
        this.userRulesGrid.getSelectionModel().addListener({
            "selectionchange" : {
                fn : this.onSelectItem,
                scope : this
            }
        });

        /* Add a field change listener to disable the troubleshoot button as soon
         * as a field changes */
        application.addListener({
            "fieldchanged" : {
                fn : this.onFieldChange,
                scope : this
            }
        });

        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                xtype : "label",
                cls : 'page-header-text',                    
                html : this._( "Port Forwards" )
            }, this.userRulesGrid ]
        });

        Ung.Alpaca.Pages.Redirect.Index.superclass.initComponent.apply( this, arguments );
    },

    onSelectItem : function( sm )
    {
        if (( application.saveButton.disabled == true ) && ( sm.getCount() == 1 )) {
            this.troubleShootButton.enable();
        } else {
            this.troubleShootButton.disable();
        }
    },

    onFieldChange : function()
    {
        this.troubleShootButton.disable();
    },

    troubleshoot : function()
    {
        var sm=this.userRulesGrid.getSelectionModel();
        var record=sm.getSelections();

        if ( record.length != 1 ) {
            this.troubleShootButton.disable();
            return;
        }

        if ( this.troubleShootWindow == null ) {
            this.troubleShootWindow = new Ung.Alpaca.Pages.Redirect.TroubleShoot();
        }

        record = record[0];

        this.troubleShootWindow.updateTestData( record.data.new_ip, record.data.filter, record.data.new_enc_id );
        this.troubleShootWindow.show();
    },

    saveMethod : "/redirect/set_settings"
});

Ung.Alpaca.Pages.Redirect.TroubleShoot = Ext.extend( Ext.Window, {
    modal : true,
    width : 700,
    height : 500,
    draggable : false,
    resizable : false,                
    layout : "anchor",

    title : Ung.Alpaca.Util._( "Port Forward Troubleshooter" ),

    defaults: {
        anchor: '100% 100%',
        autoScroll: true,
        autoWidth : true
    },

    initComponent : function()
    {
        this.closeAction = "closeWindow";

        this.bbar = [{
            iconCls : 'icon-help',
            text : Ung.Alpaca.Util._('Help'),
            handler : this.onHelp,
            scope : this
        },'->',{
            iconCls : 'cancel-icon',
            text : Ung.Alpaca.Util._('Close'),
            handler : this.closeWindow,
            scope : this
        }];

        var helpString = String.format( Ung.Alpaca.Util._( "For more help troubleshooting port forwards view the<br/>{0}Port Forward Troubleshooting Guide{1}" ), "<a href='http://wiki.untangle.com/index.php/Port_Forward_Troubleshooting_Guide'target='_blank'>", "</a>");

        this.items = [{
            xtype : "panel",
            anchor: "100% 100%",
            autoScroll: true,
            autoWidth : true,
            border : false,
            layout : "form",
            autoScroll : true,
            style : "padding: 0px",
            bodyStyle : "padding: 10px 10px 0px 10px;",
            buttonAlign : 'right',
            cls : "alpaca-panel",
            
            items : [{
                xtype : "label",
                cls : 'page-header-text',                    
                html : Ung.Alpaca.Util._( "Troubleshooting Port Forwards" ),
            },{
                xtype : "label",
                html : Ung.Alpaca.Util._( "Test 1: Verify Untangle can ping the <b>new destination</b>" ),
            },{
                xtype : "button",
                text : Ung.Alpaca.Util._( "Ping Test" ),
                style : "padding: 10px;",
                handler : this.openPingTest,
                scope : this
            },{
                xtype : "label",
                html : Ung.Alpaca.Util._( "Test 2: Verify Untangle can connect to the new destination<br/><i>This test applies only to TCP port forwards.</i>" )
            },this.tcpTestButton = new Ext.Button({
                xtype : "button",
                text : Ung.Alpaca.Util._( "Connect Test" ),
                style : "padding: 10px;",
                handler : this.openTcpTest,
                scope : this
            }),{
                xtype : "label",
                html : Ung.Alpaca.Util._( "Test 3: Watch traffic using the Packet Test" )
            },{
                xtype : "button",
                text : Ung.Alpaca.Util._( "Packet Test" ),
                style : "padding: 10px;",
                handler : this.openPacketTest,
                scope : this
            },{
                xtype : "label",
                html : helpString
            }]
        }];

        Ung.Alpaca.Pages.Redirect.TroubleShoot.superclass.initComponent.apply(this,arguments);
    },

    show : function() {
        Ung.Alpaca.Pages.Redirect.TroubleShoot.superclass.show.call(this);
        this.center();
    },

    updateTestData : function( newIP, filter, newPort )
    {
        this.newIP = newIP;
        this.filter = filter;
        this.newPort = newPort;

        if ( this.filter.indexOf( "tcp" ) >= 0 ) {
            this.tcpTestButton.enable();
        } else {
            this.tcpTestButton.disable();
        }
    },

    openPingTest : function()
    {
        if ( this.pingTest != null ) {
            this.completeOpenPingTest();
            return;
        }

        var queryPath = ({ "controller" : "network", "page" : "ping_test" });
        Ung.Alpaca.Util.loadScript( queryPath, this.completeOpenPingTest.createDelegate( this ));
    },

    completeOpenPingTest : function()
    {
        if ( this.pingTest == null ) {
            this.pingTest = new Ung.Alpaca.PingTest();
        }

        this.pingTest.destination.setValue( this.newIP );
        
        this.pingTest.show();
    },

    openTcpTest : function()
    {
        if ( this.tcpTest != null ) {
            this.completeOpenTcpTest();
            return;
        }

        var queryPath = ({ "controller" : "network", "page" : "tcp_test" });
        Ung.Alpaca.Util.loadScript( queryPath, this.completeOpenTcpTest.createDelegate( this ));
    },

    completeOpenTcpTest : function()
    {
        if ( this.tcpTest == null ) {
            this.tcpTest = new Ung.Alpaca.TcpTest();
        }

        this.tcpTest.destination.setValue( this.newIP );
        this.tcpTest.port.setValue( this.newPort );
        
        this.tcpTest.show();
    },

    openPacketTest : function()
    {
        if ( this.packetTest != null ) {
            this.completeOpenPacketTest();
            return;
        }

        var queryPath = ({ "controller" : "network", "page" : "packet_test" });
        Ung.Alpaca.Util.loadScript( queryPath, this.completeOpenPacketTest.createDelegate( this ));
    },

    completeOpenPacketTest : function()
    {
        if ( this.packetTest == null ) {
            this.packetTest = new Ung.Alpaca.PacketTest({
                interfaceStore : this.settings["interface_enum"]
            });
        }
        
        this.packetTest.show();
    },
    closeWindow : function()
    {
        this.hide();
    },

    onHelp : function () 
    {
        var url = Ung.Alpaca.Glue.buildHelpUrl( { controller : "redirect", page : "troubleshoot" });
        window.open(url);
    }
});

Ung.Alpaca.Pages.Redirect.Index.settingsMethod = "/redirect/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "redirect", "index", Ung.Alpaca.Pages.Redirect.Index );
