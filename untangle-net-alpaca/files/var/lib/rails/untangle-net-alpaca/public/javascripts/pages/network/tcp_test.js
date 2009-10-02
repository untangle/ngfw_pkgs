Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

if ( Ung.Alpaca.TcpTest != null ) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.TcpTest = Ext.extend( Ung.Alpaca.NetworkUtility, {    
    title : Ung.Alpaca.Util._( "Connection Test" ),

    testErrorMessage : Ung.Alpaca.Util._( "Unable to complete Connection Test." ),
    
    initComponent : function()
    {
        this.testDescription = Ung.Alpaca.Util._("The <b>Connection Test</b> verifies that Untangle can open a TCP connection to a port on the given host or client.");

        this.testTopToolbar = [this.destination = new Ext.form.TextField({
            xtype : "textfield",
            emptyText : Ung.Alpaca.Util._( "IP Address or Hostname" )
        }),this.port = new Ext.form.NumberField({
            minValue : 1,
            maxValue : 65536,
            xtype : "numberfield",
            emptyText : Ung.Alpaca.Util._( "Port" ),
            style : "margin-left: 10px",
            width : 50
        }),this.runTest = new Ext.Toolbar.Button({
            text : Ung.Alpaca.Util._("Run Test"),
            iconCls : "icon-test-run",
            handler : this.onRunTest,
            scope : this
        }),"->",this.clearOutput = new Ext.Toolbar.Button({
            text : Ung.Alpaca.Util._("Clear Output"),
            iconCls : "icon-clear-output",
            handler : this.onClearOutput,
            scope : this
        })];

        this.testEmptyText = Ung.Alpaca.Util._("Connection Test Output");

        Ung.Alpaca.TcpTest.superclass.initComponent.apply( this, arguments );
    },

    isValid : function()
    {
        var destination = this.destination.getValue();
        if ( destination == null || 
             ( !Ext.form.VTypes.ipAddress( destination, this.destination ) && 
               !Ext.form.VTypes.hostname( destination, this.destination ))) {
            Ext.MessageBox.show({
                title : Ung.Alpaca.Util._( "Warning" ),
                msg : Ung.Alpaca.Util._( "Please enter a valid IP Address or Hostname" ),
                icon : Ext.MessageBox.WARNING,
                buttons : Ext.MessageBox.OK
            });
            return false;
        }

        var port = this.port.getValue();
        if ( port < 1 || port > 0xFFFF ) { 
            Ext.MessageBox.show({
                title : Ung.Alpaca.Util._( "Warning" ),
                msg : Ung.Alpaca.Util._( "Please enter a port between 1 and 65535" ),
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

        Ung.Alpaca.Util.executeRemoteFunction( "/network/start_tcp_test",
                                               this.completeStartNetworkUtility.createDelegate( this ),
                                               this.failureStartNetworkUtility.createDelegate( this ),
                                               { "destination" : destination, "port" : port });
    },

    onHelp : function () 
    {
        var url = Ung.Alpaca.Glue.buildHelpUrl( { controller : "network", page : "tcp_test" });
        window.open(url);
    },

    enableParameters : function( isEnabled )
    {
        Ung.Alpaca.TcpTest.superclass.enableParameters.apply( this, arguments );

        if ( isEnabled ) {
            this.destination.enable();
            this.port.enable();
        } else {
            this.destination.disable();
            this.port.disable();
        }
    }
});
