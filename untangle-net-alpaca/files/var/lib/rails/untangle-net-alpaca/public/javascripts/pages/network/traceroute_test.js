Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

if ( Ung.Alpaca.TracerouteTest != null ) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.TracerouteTest = Ext.extend( Ung.Alpaca.NetworkUtility, {    
    title : Ung.Alpaca.Util._( "Traceroute Test" ),

    width : 800,

    testErrorMessage : Ung.Alpaca.Util._( "Unable to complete Traceroute." ),
    
    initComponent : function()
    {
        this.testDescription = Ung.Alpaca.Util._("The <b>Traceroute Test</b> traces the route to a given host or client.");

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

        this.testEmptyText = Ung.Alpaca.Util._("Traceroute Output");

        Ung.Alpaca.TracerouteTest.superclass.initComponent.apply( this, arguments );
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

        return true;
    },

    startNetworkUtility : function()
    {
        var destination = this.destination.getValue();

        Ung.Alpaca.Util.executeRemoteFunction( "/network/start_traceroute_test",
                                               this.completeStartNetworkUtility.createDelegate( this ),
                                               this.failureStartNetworkUtility.createDelegate( this ),
                                               { "destination" : destination });
    },

    onHelp : function () 
    {
        var url = Ung.Alpaca.Glue.buildHelpUrl( { controller : "network", page : "traceroute_test" });
        window.open(url);
    },

    enableParameters : function( isEnabled )
    {
        Ung.Alpaca.TracerouteTest.superclass.enableParameters.apply( this, arguments );

        if ( isEnabled ) {
            this.destination.enable();
        } else {
            this.destination.disable();
        }
    }
});
