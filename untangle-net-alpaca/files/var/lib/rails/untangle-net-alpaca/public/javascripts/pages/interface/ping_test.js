Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

if ( Ung.Alpaca.PingTest != null ) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.PingTest = Ext.extend(Ext.Window, {
    modal : true,
    width : 700,
    height : 500,
    draggable : false,
    resizable : false,                
    layout : "anchor",
    
    title : Ung.Alpaca.Util._( "Ping Test" ),

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
        }],
        
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
                html : Ung.Alpaca.Util._("The <b>Ping Test</b> can be used to test that a particular host or client can be contacted from Untangle"),
                style : "padding-bottom: 10px;"
            },{
                xtype : "panel",
                style : "margin: 10px 0px 0px 0px",
                layout : "anchor",
                height : 392,
                tbar :[this.destination = new Ext.form.TextField({
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
                })],
                items : [this.output = new Ext.form.TextArea({
                    name : "output",
                    emptyText : Ung.Alpaca.Util._("Ping Test Output"),
                    hideLabel : true,
                    readOnly : true,
                    anchor : "100% 100%",
                    style : "padding: 8px"
                })]
            }]
        }];
        
        Ung.Alpaca.PingTest.superclass.initComponent.apply( this, arguments );
    },

    show : function() {
        Ung.Alpaca.PingTest.superclass.show.call(this);
        this.center();
    },


    onHelp : function () 
    {            
        var url = "http://www.untangle.com/docs/get.php?version=6.2&source=ping_test&lang=en";
        window.open(url);
    },
    
    onRunTest : function()
    {
        if ( this.currentCommandKey != null ) {
            Ext.MessageBox.show({
                title : Ung.Alpaca.Util._( "Warning" ),
                msg : Ung.Alpaca.Util._( "A ping test is already running." ),
                icon : Ext.MessageBox.WARNING,
                buttons : Ext.MessageBox.OK
            });
            return;
        }

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
            return;
        }
        
        /* Disable the run test button */
        this.runTest.setIconClass( "icon-test-running" );
        this.output.focus();
        this.runTest.disable();
        this.destination.disable();
        this.currentCommandKey = 0;
        this.stdoutOffset = null;
        this.stderrOffset = null;
        
        Ung.Alpaca.Util.executeRemoteFunction( "/network/start_ping_test",
                                               this.completeStartPingTest.createDelegate( this ),
                                               this.failureStartPingTest.createDelegate( this ),
                                               { "destination" : destination });        
    },

    completeStartPingTest : function( key, response, options )
    {
        this.currentCommandKey = key["key"];
        this.stdoutOffset = null;
        this.stderrOffset = null;
        this.pollCount = 0;
        
        window.setTimeout( this.continuePingTest.createDelegate( this ), 1000 );
    },

    failureStartPingTest : function( response, options )
    {
        Ext.MessageBox.show({
            title : Ung.Alpaca.Util._( "Warning" ),
            msg : Ung.Alpaca.Util._( "Unable to complete the ping test." ),
            icon : Ext.MessageBox.WARNING,
            buttons : Ext.MessageBox.OK
        });

        this.currentCommandKey = null;
        this.stdoutOffset = null;
        this.stderrOffset = null;
        this.pollCount = 0;
        this.runTest.setIconClass( "icon-test-run" );
        this.runTest.enable();
        this.destination.enable();
    },

    continuePingTest : function()
    {
        if ( this.currentCommandKey == null || this.currentCommandKey == 0 ) {
            this.failureStartPingTest();
            return;
        }
        
        var message = { key : this.currentCommandKey };

        if ( this.stdoutOffset != null ) {
            message["stdout_offset"] = this.stdoutOffset;
        }
        if ( this.stderrOffset != null ) {
            message["stderr_offset"] = this.stderrOffset;
        }
        Ung.Alpaca.Util.executeRemoteFunction( "/network/continue_ping_test",
                                               this.completeContinuePingTest.createDelegate( this ),
                                               this.failureStartPingTest.createDelegate( this ),
                                               message );
    },

    completeContinuePingTest : function( output, response, options )
    {
        var element = this.output.getEl();
        this.output.setValue( this.output.getValue() + output["stdout"]);
        element.scroll( "b", 1000 );
        
        this.stdoutOffset = output["stdout_offset"];
        this.stderrOffset = output["stderr_offset"];

        if ( this.pollCount == null ) {
            this.pollCount = 0;
        }

        this.pollCount++;

        if ( this.pollCount > 20 ) {
            this.failureStartPingTest();
            return;
        }

        if ( output["return_code"] < 0 ) {
            window.setTimeout( this.continuePingTest.createDelegate( this ), 1000 );
        } else {
            this.currentCommandKey = null;
            this.stdoutOffset = null;
            this.stderrOffset = null;
            this.runTest.setIconClass( "icon-test-run" );
            this.destination.enable();
            this.runTest.enable();
        }
    },

    onClearOutput : function()
    {
        this.output.setValue( "" );
    },
    
    closeWindow : function()
    {
        this.hide();
    }

    
});
