Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

if ( Ung.Alpaca.DnsTest != null ) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.DnsTest = Ext.extend( Ung.Alpaca.NetworkUtility, {    
    title : Ung.Alpaca.Util._( "DNS Test" ),

    testErrorMessage : Ung.Alpaca.Util._( "Unable to complete DNS test." ),
    
    initComponent : function()
    {
        this.testDescription = Ung.Alpaca.Util._("The <b>DNS Test</b> can be used to test DNS lookups");

        this.testTopToolbar = [this.hostname = new Ext.form.TextField({
            xtype : "textfield",
            emptyText : Ung.Alpaca.Util._( "Hostname" )
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

        this.testEmptyText = Ung.Alpaca.Util._("DNS Test Output");

        Ung.Alpaca.DnsTest.superclass.initComponent.apply( this, arguments );
    },

    isValid : function()
    {
        var hostname = this.hostname.getValue();
        if ( hostname == null || 
             ( !Ext.form.VTypes.ipAddress( hostname, this.hostname ) && 
               !Ext.form.VTypes.hostname( hostname, this.hostname ))) {
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
        var hostname = this.hostname.getValue();

        Ung.Alpaca.Util.executeRemoteFunction( "/network/start_dns_test",
                                               this.completeStartNetworkUtility.createDelegate( this ),
                                               this.failureStartNetworkUtility.createDelegate( this ),
                                               { "hostname" : hostname });        
    },

    onHelp : function () 
    {
        var url = Ung.Alpaca.Glue.buildHelpUrl( { controller : "network", page : "dns_test" });
        window.open(url);
    },

    enableParameters : function( isEnabled )
    {
        Ung.Alpaca.DnsTest.superclass.enableParameters.apply( this, arguments );

        if ( isEnabled ) {
            this.hostname.enable();
        } else {
            this.hostname.disable();
        }
    }
});
