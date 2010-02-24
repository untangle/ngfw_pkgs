Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

if ( Ung.Alpaca.PacketTest != null ) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.PacketTest = Ext.extend( Ung.Alpaca.NetworkUtility, {    
    title : Ung.Alpaca.Util._( "Packet Test" ),

    testErrorMessage : Ung.Alpaca.Util._( "Unable to complete the Packet Test." ),

    width :  800,
    
    initComponent : function(config)
    {
        this.testDescription = Ung.Alpaca.Util._("The <b>Packet Test</b> can be used to view packets on the network wire for troubleshooting.");

        var timeouts = [[ 5, Ung.Alpaca.Util._( "5 seconds" )],
                        [ 30, Ung.Alpaca.Util._( "30 seconds" )],
                        [ 120, Ung.Alpaca.Util._( "120 seconds" )]];

        this.testTopToolbar = [this.destination = new Ext.form.TextField({
            xtype : "textfield",
            value : "any",
            emptyText : Ung.Alpaca.Util._( "IP Address or Hostname" )
        }),this.port = new Ext.form.NumberField({
            minValue : 1,
            maxValue : 65536,
            xtype : "numberfield",
            emptyText : Ung.Alpaca.Util._( "Port" ),
            style : "margin-left: 10px",
            width : 50
        }),this.intf = new Ext.form.ComboBox({
            editable : false,
            xtype : "combo",
            style : "margin-left: 10px",
            width : 100,
            value : this.interfaceStore[0][0],
            store : this.interfaceStore,
            triggerAction : "all",
            mode : "local"
        }),{
            xtype : "label",
            html : Ung.Alpaca.Util._("Timeout:"),
            style : "margin-left: 18px"
        },this.timeout = new Ext.form.ComboBox({
            style : "margin-left: 2px",
            value : timeouts[0][0],
            editable : false,
            xtype : "combo",
            width : 100,
            store : timeouts,
            triggerAction : "all",
            mode : "local"
        }),this.runTest = new Ext.Toolbar.Button({
            text : Ung.Alpaca.Util._("Run Test"),
            style : "margin-left: 18px",
            iconCls : "icon-test-run",
            handler : this.onRunTest,
            scope : this
        }),"->",this.clearOutput = new Ext.Toolbar.Button({
            text : Ung.Alpaca.Util._("Clear Output"),
            iconCls : "icon-clear-output",
            handler : this.onClearOutput,
            scope : this
        })];

        this.testEmptyText = Ung.Alpaca.Util._("Packet Test Output");

        Ung.Alpaca.PacketTest.superclass.initComponent.apply( this, arguments );
    },

    isValid : function()
    {
        var destination = this.destination.getValue();
        if ( destination != null &&
             destination != "" &&
             destination != "any" &&
             ( !Ext.form.VTypes.ipAddress( destination, this.destination ) && 
               !Ext.form.VTypes.hostname( destination, this.destination ))) {
            Ext.MessageBox.show({
                title : Ung.Alpaca.Util._( "Warning" ),
                msg : Ung.Alpaca.Util._( "Please enter a valid IP Address, Hostname or 'any'" ),
                icon : Ext.MessageBox.WARNING,
                buttons : Ext.MessageBox.OK
            });
            return false;
        }

        var port = this.port.getValue();
        if ( port != null && port != "" && ( port < 1 || port > 0xFFFF )) {
            Ext.MessageBox.show({
                title : Ung.Alpaca.Util._( "Warning" ),
                msg : Ung.Alpaca.Util._( "Please enter a port between 1 and 65535.  Leave the port blank to capture all traffic." ),
                icon : Ext.MessageBox.WARNING,
                buttons : Ext.MessageBox.OK
            });
            return false;
        }

        return true;
    },

    startNetworkUtility : function()
    {
        var destination = this.destination.getValue();
        var port = this.port.getValue();
        var intf = this.intf.getValue();
        var timeout = this.timeout.getValue();

        Ung.Alpaca.Util.executeRemoteFunction( "/network/start_packet_test",
                                               this.completeStartNetworkUtility.createDelegate( this ),
                                               this.failureStartNetworkUtility.createDelegate( this ),
                                               { "destination" : destination,
                                                 "port" : port,
                                                 "interface" : intf,
                                                 "timeout" : timeout
                                               });
    },

    onHelp : function () 
    {
        var url = Ung.Alpaca.Glue.buildHelpUrl( { controller : "network", page : "dns_test" });
        window.open(url);
    },

    enableParameters : function( isEnabled )
    {
        Ung.Alpaca.PacketTest.superclass.enableParameters.apply( this, arguments );

        if ( isEnabled ) {
            this.destination.enable();
            this.port.enable();
            this.intf.enable();
            this.timeout.enable();
        } else {
            this.destination.disable();
            this.port.disable();
            this.intf.disable();
            this.timeout.disable();
        }
    }
});
