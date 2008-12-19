Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

Ung.Alpaca.Util = {
    stopLoadingObject  : {},

    loadScript : function( page, handler, failure )
    {
        var src = this.getPageSrc( page );

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

    getPageSrc : function( page )
    {
        return "/alpaca/javascripts/pages/" + page["controller"] + "/" + page["page"] + ".js";
    },

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
    }
};
