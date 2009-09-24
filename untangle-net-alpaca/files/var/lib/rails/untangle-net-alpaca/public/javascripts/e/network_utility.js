Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

Ung.Alpaca.NetworkUtility = Ext.extend( Ext.Window, {
    modal : true,
    width : 700,
    height : 500,
    draggable : false,
    resizable : false,                
    layout : "anchor",

    defaults: {
        anchor: '100% 100%',
        autoScroll: true,
        autoWidth : true
    },

    initComponent : function()
    {
        Ext.applyIf( this, {
            testErrorMessage : Ung.Alpaca.Util._( "Unable to run this Network Utility." )
        });

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
                html : this.testDescription,
                style : "padding-bottom: 10px;"
            },{
                xtype : "panel",
                style : "margin: 10px 0px 0px 0px",
                layout : "anchor",
                height : 392,
                tbar : this.testTopToolbar,
                items : [this.output = new Ext.form.TextArea({
                    name : "output",
                    emptyText : this.testEmptyText,
                    hideLabel : true,
                    readOnly : true,
                    anchor : "100% 100%",
                    style : "padding: 8px"
                })]
            }]
        }];
        
        Ung.Alpaca.NetworkUtility.superclass.initComponent.apply( this, arguments );
    },

    show : function() {
        Ung.Alpaca.NetworkUtility.superclass.show.call(this);
        this.center();
    },

    onRunTest : function()
    {
        if ( this.currentCommandKey != null ) {
            Ext.MessageBox.show({
                title : Ung.Alpaca.Util._( "Warning" ),
                msg : Ung.Alpaca.Util._( "A network utility is already running." ),
                icon : Ext.MessageBox.WARNING,
                buttons : Ext.MessageBox.OK
            });
            return;
        }

        if ( this.isValid != null ) {
            if ( !this.isValid()) {
                return;
            }
        }
        
        /* Disable the run test button */
        this.runTest.setIconClass( "icon-test-running" );
        this.output.focus();
        this.runTest.disable();
        this.destination.disable();
        this.currentCommandKey = 0;
        this.stdoutOffset = null;
        this.stderrOffset = null;
        
        this.startNetworkUtility();
    },

    completeStartNetworkUtility : function( key, response, options )
    {
        this.currentCommandKey = key["key"];
        this.stdoutOffset = null;
        this.stderrOffset = null;
        this.pollCount = 0;
        
        window.setTimeout( this.continueNetworkUtility.createDelegate( this ), 1000 );
    },

    failureStartNetworkUtility : function( response, options )
    {
        Ext.MessageBox.show({
            title : Ung.Alpaca.Util._( "Warning" ),
            msg : this.testErrorMessage,
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

    continueNetworkUtility : function()
    {
        if ( this.currentCommandKey == null || this.currentCommandKey == 0 ) {
            this.failureStartNetworkUtility();
            return;
        }

        if ( this.hidden ) {
            try {
                var commandKey = this.currentCommandKey;
                this.currentCommandKey = null;
                Ung.Alpaca.Util.executeRemoteFunction( "/alpaca/stop_background_command",
                                                       function() {}, function() {},
                                                       { "key" : commandKey });
            } catch ( e ) {
                /* ignored */
            }

            this.currentCommandKey = null;
            this.stdoutOffset = null;
            this.stderrOffset = null;
            this.pollCount = 0;
            this.runTest.setIconClass( "icon-test-run" );
            this.runTest.enable();
            this.destination.enable();

            return;
        }
        
        var message = { key : this.currentCommandKey };

        if ( this.stdoutOffset != null ) {
            message["stdout_offset"] = this.stdoutOffset;
        }
        if ( this.stderrOffset != null ) {
            message["stderr_offset"] = this.stderrOffset;
        }
        Ung.Alpaca.Util.executeRemoteFunction( "/alpaca/continue_background_command",
                                               this.completeContinueNetworkUtility.createDelegate( this ),
                                               this.failureStartNetworkUtility.createDelegate( this ),
                                               message );
    },

    completeContinueNetworkUtility : function( output, response, options )
    {
        var element = this.output.getEl();
        var text = [];

        text.push( this.output.getValue());

        if ( this.stdoutOffset == null ) {
            text.push( "" + new Date() + "\n" );
        }
        text.push( output["stderr"] );
        text.push( output["stdout"] );
                
        this.stdoutOffset = output["stdout_offset"];
        this.stderrOffset = output["stderr_offset"];

        if ( this.pollCount == null ) {
            this.pollCount = 0;
        }

        this.pollCount++;

        if ( this.pollCount > 180 ) {
            this.output.setValue( text.join( "" ));
            element.scroll( "b", 10000 );
            this.failureStartNetworkUtility();
            return;
        }

        if ( output["return_code"] < 0 ) {
            window.setTimeout( this.continueNetworkUtility.createDelegate( this ), 1000 );
        } else {
            this.currentCommandKey = null;
            this.stdoutOffset = null;
            this.stderrOffset = null;
            this.runTest.setIconClass( "icon-test-run" );
            this.destination.enable();
            this.runTest.enable();
            text.push( "\n" );
        }

        this.output.setValue( text.join( "" ));
        element.scroll( "b", 10000 );
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
