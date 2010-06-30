Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Redirect');

var warnMessage = "By default the server uses HTTPS port 443 for remote administration.  When forwarding port 443 to one of your local servers, remember to configure the External HTTPS port on the Administration page to a different value.";

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

        this.protocolStore = [[ "tcp,udp", this._( "TCP & UDP" ) ],
                              [ "tcp", this._( "TCP" ) ],
                              [ "udp", this._( "UDP" ) ]];

        this.portStore = [[ 21, "FTP (21)" ],
                          [ 22, "FTP (22)" ],
                          [ 25, "SMTP (25)" ],
                          [ 53, "DNS (53)" ],
                          [ 80, "HTTP (80)" ],
                          [ 110, "POP3 (110)" ],
                          [ 143, "IMAP (143)" ],
                          [ 443, "HTTPS (443)" ],
                          [ 1723, "PPTP (1723)" ],
                          [ -1, "Other" ]];

        this.userRulesGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,

            recordFields : ["id", "enabled", "system_id", "new_ip", "new_enc_id", "filter", "description", "is_custom" ],
            selectable : true,
            sortable : false,
            hasEdit : true,
            hasReorder: true,
            
            rowEditor : this.rowEditor = new Ung.Alpaca.Pages.Redirect.RowEditor({
                i18n : this.i18n,
                portStore : this.portStore,
                protocolStore : this.protocolStore,
                name : "user_redirects",
                settings : this.settings
            }),

            name : "user_redirects",

            tbar : [ Ung.Alpaca.EditorGridPanel.AddButtonMarker,
                     Ung.Alpaca.EditorGridPanel.DeleteButtonMarker,
                     this.troubleShootButton ],
        
            recordDefaults : {
                enabled : true,
                system_id : null,
                new_ip : "1.2.3.4",
                new_enc_id : "",
                filter : "simple::true&&d-port::80&&d-local::true&&protocol::tcp",
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

        this.rowEditor.grid = this.userRulesGrid;

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
            this.troubleShootWindow = new Ung.Alpaca.Pages.Redirect.TroubleShoot({ 
                settings : this.settings
            });
        }

        record = record[0];

        this.troubleShootWindow.updateTestData( record.data.new_ip, record.data.filter, record.data.new_enc_id );
        this.troubleShootWindow.show();
    },

    saveMethod : "/redirect/set_settings"
});

Ung.Alpaca.Pages.Redirect.RowEditor = Ext.extend( Ung.Alpaca.RowEditor, {
    constructor : function( config ) {
        this.i18n = config.i18n;
        this._ = this.i18n._.createDelegate( this.i18n );

        this.portStore = config.portStore;
        this.protocolStore = config.protocolStore;
        
        Ung.Alpaca.Pages.Redirect.RowEditor.superclass.constructor.apply( this, arguments );
    },
    
    xtype: "roweditor",
    
    initComponent : function()
    {
        this.panelItems = [{
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
            simpleMode : true,
            autoHeight : true,
            title : this._( "Forward the following traffic:" ),
            items : [{
                editable : false,
                xtype : "combo",
                fieldLabel : this._("Protocol" ),
                width : 100,
                name : "simple_protocol",
                value : this.protocolStore[0][0],
                store : this.protocolStore,
                triggerAction : "all",
                mode : "local"
            },{
                editable : false,
                xtype : "combo",
                fieldLabel : this._("Port" ),
                width : 100,
                name : "simple_basic_port",
                value : this.portStore[0][0],
                store : this.portStore,
                triggerAction : "all",
                mode : "local",
                listeners : {
                    "select" : {
                        fn : this.onBasicPortSelect,
                        scope : this
                    }
                }
            },{
                xtype : "numberfield",
                fieldLabel : this._("Port Number" ),
                name : "simple_destination_port",
                minValue : 1,
                maxValue : 0xFFFF,
                width : 100
            }]
        },{
            xtype : "fieldset",
            autoHeight : true,
            simpleMode : true,
            title : this._( "To the following location:" ),
            items : [{
                xtype : "textfield",
                fieldLabel : this._("Local IP" ),
                name : "simple_new_ip",
                width : 100
            }]
        },{
            xtype : "button",
            simpleMode : true,
            text : this._( "Switch to Advanced" ),
            style : "padding: 10px;",
            handler : this.onToAdvancedMode,
            scope : this
        },{
            xtype : "fieldset",
            autoWidth : true,
            autoScroll: true,
            autoHeight : true,
            simpleMode : false,
            title: "If all of the following conditions are met:",
            items:[{
                xtype:"rulebuilder",
                anchor:"98%",
                dataIndex: "filter",
                ruleInterfaceValues : this.settings["interface_enum"],
                rules : [{
                    name : "d-addr",
                    displayName : this._("Destination Address"),
                    type: "text",
                    vtype:"address"
                },{
                    name : "d-port",
                    displayName : this._("Destination Port"),
                    type: "text",
                    vtype : "port"
                },{
                    name : "d-local",
                    displayName : this._("Destined Local"),
                    type: "boolean"
                },{
                    name : "protocol",
                    displayName : this._("Protocol"),
                    type: "checkgroup",
                    values: Ung.Alpaca.RuleBuilder.DEFAULT_PROTOCOL_VALUES
                },{
                    name:"s-intf",
                    displayName : this._("Source Interface"),
                    type: "checkgroup",
                    values : this.settings["interface_enum"]
                },{
                    name : "s-addr",
                    displayName : this._("Source Address"),
                    type: "text",
                    vtype : "address"
                }]
            }]
        },{
            xtype : "fieldset",
            autoHeight : true,
            simpleMode : false,
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
        }];
        
        Ung.Alpaca.Pages.Redirect.RowEditor.superclass.initComponent.apply(this, arguments);
    },

    populate : function(record)
    {
        Ung.Alpaca.Pages.Redirect.RowEditor.superclass.populate.apply(this, arguments);

        var simpleItems = this.find( "simpleMode", true );
        var advancedItems = this.find( "simpleMode", false );
        var c, filter, field;

        filter = record.data.filter;
        if ( filter == null ) {
            filter = "";
        }

        if ( filter.indexOf( "simple::true" ) >= 0 ) {
            this.simpleMode = true;
            for ( c = 0 ; c < simpleItems.length ; c++ ) {
                simpleItems[c].setVisible( true );
            }
            for ( c = 0 ; c < advancedItems.length ; c++ ) {
                advancedItems[c].setVisible( false );
            }
            
        var values = record.data.filter.split("&&");

            for ( c = 0 ; c < values.length ; c++ ) {
                var value = values[c].split("::");
                switch (value[0]) {
                case "d-port":
                    value[1] = parseInt( value[1] );
                    var isOther = true;
                    for ( var d = 0 ; d < this.portStore.length ; d++ ) {
                        if ( this.portStore[d][0] == value[1] ) {
                            this.find( "name", "simple_basic_port" )[0].setValue( value[1] );
                            this.find( "name", "simple_destination_port" )[0].setContainerVisible( false );
                            isOther = false;
                            break;
                        }
                    }
                    
                    this.find( "name", "simple_destination_port" )[0].setValue( value[1] );
                    if ( isOther ) {
                        this.find( "name", "simple_destination_port" )[0].setContainerVisible( true );
                        this.find( "name", "simple_basic_port" )[0].setValue( -1 );
                    }
                    break;
                    
                case "protocol":
                    this.find( "name", "simple_protocol" )[0].setValue( value[1] );
                    break;
                }
            }

            this.find( "name", "simple_new_ip" )[0].setValue( record.data.new_ip );
        } else {
            this.simpleMode = false;
            
            for ( c = 0 ; c < simpleItems.length ; c++ ) {
                simpleItems[c].setVisible( false );
            }
            for ( c = 0 ; c < advancedItems.length ; c++ ) {
                advancedItems[c].setVisible( true );
            }
        }
    },
    
    updateFieldValue : function( item, index, length, record )
    {
        Ung.Alpaca.Pages.Redirect.RowEditor.superclass.updateFieldValue.apply(this, arguments);

        if ( this.simpleMode ) {
            record.set( "is_custom", false );
            record.set( "new_ip", this.find( "name", "simple_new_ip" )[0].getValue());
            var filter = "simple::true&&d-local::true";
            
            filter += "&&protocol::" + this.find( "name", "simple_protocol" )[0].getValue();
            var port = this.find( "name", "simple_basic_port" )[0].getValue();
            if ( port == -1 ) {
                port = this.find( "name", "simple_destination_port" )[0].getValue();
            }
            filter += "&&d-port::" + port;
            record.set( "new_enc_id", port );
            record.set( "filter", filter );
        }
    },

    onBasicPortSelect : function( field, record, index )
    {
        var isVisible = record.data.value == -1;
        var port = this.find( "name", "simple_destination_port" )[0];

        port.setContainerVisible( isVisible );
        if ( !isVisible ) {
            port.setValue( record.data.value );
        }

        if (record.data.value === 443) {
            Ext.Msg.alert( "Warning" , this._( warnMessage ) );
        }
    },

    onToAdvancedMode : function()
    {
        
        Ext.MessageBox.show({
            title : this._( "Warning" ),
            msg : this._( "Advanced port forwards can not be viewed in simple mode. To switch back to simple view, delete this rule and create a new one." ),
            buttons : {
                ok : this._( "Continue" ),
                cancel : this._( "Cancel" )
            },
            fn : this.confirmToAdvancedMode,
            scope : this,
            icon : Ext.MessageBox.WARNING
        });
    },

    confirmToAdvancedMode : function( buttonId ) {
        if ( buttonId != "ok" ) {
            return;
        }

        this.updateAction();
        this.record.data.filter = this.record.data.filter.replace( "simple::true", "" );
        this.grid.editEntry( this.record );
    }
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
                html : Ung.Alpaca.Util._( "Troubleshooting Port Forwards" )
            },{
                xtype : "label",
                html : Ung.Alpaca.Util._( "Test 1: Verify pinging the <b>new destination</b>" )
            },{
                xtype : "button",
                text : Ung.Alpaca.Util._( "Ping Test" ),
                style : "padding: 10px;",
                handler : this.openPingTest,
                scope : this
            },{
                xtype : "label",
                html : Ung.Alpaca.Util._( "Test 2: Verify connecting to the new destination<br/><i>This test applies only to TCP port forwards.</i>" )
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

