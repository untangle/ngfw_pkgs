Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

Ung.Alpaca.Util = {
    stopLoadingObject  : {},

    loadScript : function( queryPath, handler, failure )
    {
        var src = this.getQueryPathScript( queryPath );

        /* Now build the query */
        return Ext.Ajax.request({
            url : src,
            success : this.loadScriptSuccess.createDelegate( this, [ handler ], true ),
            failure : this.loadScriptFailure.createDelegate( this, [ failure ], true )
        });
    },

    loadScriptSuccess : function( response, options, handler )
    {
        var error = null;

        try {
            if( window.execScript) {
                window.execScript(response.responseText);
            } else {
                window.eval(response.responseText);
            }
        } catch ( e ) {
            if ( e != this.stopLoadingObject ) {
                throw e;
            }
        }
        
        handler( response, options );
    },

    loadScriptFailure : function( response, options, handler )
    {
        if ( handler != null ) {
            return handler( response, options );
        }

        throw "Unable to load script";
    },

    /**
     * @param path : The path to the request.
     * @param handler : Callback to call on success.
     * @param failure : Callback to call on failure.
     * @param *args : All arguments after this will be converted to an array and passed into
     *                the request as JSON.
     */
    executeRemoteFunction : function( path, handler, failure )
    {
        var args = [];
        var argumentCount = arguments.length;
        for ( var c = 3 ; c < argumentCount ; c++ ) {
            args[c-3] = arguments[c];
        }

        path = "/alpaca" + path;

        /* Now build the query */
        return Ext.Ajax.request({
            url : path,
            success : this.remoteFunctionSuccess.createDelegate( this, [ handler, failure ], true ),
            failure : this.remoteFunctionFailure.createDelegate( this, [ failure ], true ),
            jsonData : args
        });
    },
    
    remoteFunctionSuccess : function( response, options, handler, failure )
    {
        var json = Ext.util.JSON.decode( response.responseText );

        /* Append this in case another handler wants to reuse some other part of the JSON data. */
        response.jsonData = json;
        if ( json["status"] != "success" ) {
            return this.remoteFunctionFailure( response, options, failure );
        }
        
        handler( json["result"], response, options );
    },
    
    remoteFunctionFailure : function( response, options, handler )
    {
        if ( handler ) {
            return handler( response, options );
        }
        
        this.handleConnectionError( response, options );
    },

    handleConnectionError : function( response, options )
    {
        throw "Unable to connect";
    },

    stopLoading : function()
    {
        throw this.stopLoadingObject;
    },

    getQueryPathScript : function( queryPath )
    {
        return "/alpaca/javascripts/pages/" + queryPath["controller"] + "/" + queryPath["page"] + ".js";
    },

    /* Only update config if a value doesn't exist, extjs already has this
     * in ApplyIf. */
    updateDefaults : function( config, defaults )
    {
        for ( key in defaults ) {
            if ( config[key] == null ) {
                var value = defaults[key];
                if (( typeof value ) == "function" ) {
                    config[key] = defaults[key]();
                } else {
                    config[key] = defaults[key];
                }
            }
        }
    },
    
    implementMe : function( feature )
    {
        Ext.MessageBox.show({
            title : 'Implement Me',
            msg : feature,
            buttons : Ext.MessageBox.OK,
            icon : Ext.MessageBox.INFO
        });
    },
    hasData : function(obj) {
        var hasData = false;
        for (id in obj) {
            hasData = true;
            break;
        }
        return hasData;
    },
    
    cidrData : [
        [ "8",  "8   : 255.0.0.0"],
        [ "9",  "9   : 255.128.0.0"],
        [ "10", "10  : 255.192.0.0"],
        [ "11", "11  : 255.224.0.0"],
        [ "12", "12  : 255.240.0.0"],
        [ "13", "13  : 255.248.0.0"],
        [ "14", "14  : 255.252.0.0"],
        [ "15", "15  : 255.254.0.0"],
        [ "16", "16  : 255.255.0.0"],
        [ "17", "17  : 255.255.128.0"],
        [ "18", "18  : 255.255.192.0"],
        [ "19", "19  : 255.255.224.0"],
        [ "20", "20  : 255.255.240.0"],
        [ "21", "21  : 255.255.248.0"],
        [ "22", "22  : 255.255.252.0"],
        [ "23", "23  : 255.255.254.0"],
        [ "24", "24  : 255.255.255.0"],
        [ "25", "25  : 255.255.255.128"],
        [ "26", "26  : 255.255.255.192"],
        [ "27", "27  : 255.255.255.224"],
        [ "28", "28  : 255.255.255.240"],
        [ "29", "29  : 255.255.255.248"],
        [ "30", "30  : 255.255.255.252"],
        [ "31", "31  : 255.255.255.254"],
        [ "32", "32  : 255.255.255.255" ]
    ]
};

Ung.Alpaca.TextField = Ext.extend( Ext.form.TextField, {
    onRender : function(ct, position)
    {
        Ung.Alpaca.TextField.superclass.onRender.call(this, ct, position);
        
        var parent = this.el.parent()
        
        if( this.boxLabel ) {
            this.labelEl = parent.createChild({
                tag: 'label',
                htmlFor: this.el.id,
                cls: 'x-form-textfield-label',
                html: this.boxLabel
            });
        }
    }
});

/* override the default text field so that all of the text fields can add a box label */
Ext.reg('textfield', Ung.Alpaca.TextField);

Ung.Alpaca.ComboBox = Ext.extend( Ext.form.ComboBox, {
    onRender : function(ct, position)
    {
        Ung.Alpaca.ComboBox.superclass.onRender.call(this, ct, position);

        if( this.boxLabel ) {
            this.labelEl = this.wrap.createChild({
                tag: 'label',
                htmlFor: this.el.id,
                cls : 'x-form-combo-label',
                html : this.boxLabel
            });
        }
    }
});

/* override the default Combo box so that all of the comboboxes can add a box label */
Ext.reg('combo',  Ung.Alpaca.ComboBox);

