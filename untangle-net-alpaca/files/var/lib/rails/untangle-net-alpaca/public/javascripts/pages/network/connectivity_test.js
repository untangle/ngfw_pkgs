Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

if ( Ung.Alpaca.ConnectivityTest != null ) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.ConnectivityTest = Ext.extend( Ung.Alpaca.NetworkUtility, {    
    title : Ung.Alpaca.Util._( "Connectivity Test" ),

    testErrorMessage : Ung.Alpaca.Util._( "Unable to complete the Connectivity Test." ),
    
    initComponent : function()
    {
        this.testDescription = Ung.Alpaca.Util._("The <b>Connectivity Test</b> verifies a working connection to the Internet.");

        this.testTopToolbar = [this.runTest = new Ext.Toolbar.Button({
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

        this.testEmptyText = Ung.Alpaca.Util._("Connectivity Test Output");

        Ung.Alpaca.ConnectivityTest.superclass.initComponent.apply( this, arguments );
    },

    isValid : function()
    {
        return true;
    },

    startNetworkUtility : function()
    {
        Ung.Alpaca.Util.executeRemoteFunction( "/network/start_connectivity_test",
                                               this.completeStartNetworkUtility.createDelegate( this ),
                                               this.failureStartNetworkUtility.createDelegate( this ),
                                               {});        
    },

    onHelp : function () 
    {
        var url = Ung.Alpaca.Glue.buildHelpUrl( { controller : "network", page : "connectivity_test" });
        window.open(url);
    }    
});
