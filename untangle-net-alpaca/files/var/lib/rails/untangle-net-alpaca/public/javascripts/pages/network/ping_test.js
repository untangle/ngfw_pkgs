Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

if ( Ung.Alpaca.PingTest != null ) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.PingTest = Ext.extend( Ung.Alpaca.NetworkUtility, {    
    title : Ung.Alpaca.Util._( "Ping Test" ),

    testErrorMessage : Ung.Alpaca.Util._( "Unable to complete ping test." ),
    
    initComponent : function()
    {
        this.testDescription = Ung.Alpaca.Util._("The <b>Ping Test</b> can be used to test that a particular host or client can be pinged");

        this.testTopToolbar = [this.destination = new Ext.form.TextField({
            xtype : "textfield",
            emptyText : Ung.Alpaca.Util._( "IP Address or Hostname" )
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

        this.testEmptyText = Ung.Alpaca.Util._("Ping Test Output");

        Ung.Alpaca.PingTest.superclass.initComponent.apply( this, arguments );
    },

    isValid : function()
    {
        var destination = this.destination.getValue();
        if ( destination == null || 
             ( !Ext.form.VTypes.ipAddress( destination, this.destination ) && 
               !Ext.form.VTypes.hostname( destination, this.destination ))) {
            Ext.MessageBox.show({
                title : Ung.Alpaca.Util._( "Warning" ),
                msg : Ung.Alpaca.Util._( "Please enter a valid IP Address or hostname" ),
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

        Ung.Alpaca.Util.executeRemoteFunction( "/network/start_ping_test",
                                               this.completeStartNetworkUtility.createDelegate( this ),
                                               this.failureStartNetworkUtility.createDelegate( this ),
                                               { "destination" : destination });        
    },

    onHelp : function () 
    {
        var url = Ung.Alpaca.Glue.buildHelpUrl( { controller : "network", page : "ping_test" });
        window.open(url);
    },

    enableParameters : function( isEnabled )
    {
        Ung.Alpaca.PingTest.superclass.enableParameters.apply( this, arguments );

        if ( isEnabled ) {
            this.destination.enable();
        } else {
            this.destination.disable();
        }
    }
});
