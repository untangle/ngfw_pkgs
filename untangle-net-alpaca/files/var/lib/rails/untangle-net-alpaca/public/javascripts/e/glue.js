Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

Ung.Alpaca.Glue = {
    HELP_URL : "http://www.untangle.com/docs/get.php",
    
    HELP_NAMESPACE : "alpaca",
    
    // Map of all of the currently loaded pages.  Indexed with
    // buildPageKey( controller, page ) -> Ung.Alpaca.PagePanel child class.
    pages : {},
    
    /* This parses the path of the URL to determine the current page.
     * The URL looks like "/alpaca/#{controller}/#{page}?#{params}"
     * If <page> is not set, then it defaults to index.
     * If <controller> is not set, the it defaults to network.
     */
    buildQueryPath : function( base )
    {
        if (typeof( base ) != "string" ) {
            return base;
        }

        var a = base.split( "?" );
        var params = a[1];
        var path = a[0];

        path = path.replace( /\/+/g, "/" )
         a = path.split( "/" );
        var controller = a[2];
        var page = a[3];
        var pageID = parseInt( a[4] );
        
        if (( page == null ) || ( page.length == 0 )) page = "index";
        if (( controller == null ) || ( controller.length == 0 )) controller = "interface";

        var requestedPage = { "controller" : controller, "page" : page };
        if ( pageID ) {
            requestedPage["pageID"] = pageID;
        }
        
        return requestedPage;
    },

    // Return true if this page already has a registered renderer.
    hasPageRenderer : function( controller, page )
    {
        return ( this.pages[this.buildPageKey( controller, page )] != null );
    },

    // Register a page renderer for a page.
    registerPageRenderer : function( controller, page, renderer )
    {
        this.pages[this.buildPageKey( controller, page )] = renderer;
    },

    // Get the page renderer for a page.
    getPageRenderer : function( controller, page )
    {
        return this.pages[this.buildPageKey( controller, page )];
    },

    saveSettings : function( panel )
    {
        var handler = this.confirmedSaveSettings.createDelegate( this, [panel], true );

        /* Confirm settings save, if necessary */
        if ( panel.confirmMessage )
        {
            message = [];
            message.push( panel.confirmMessage );
            message.push( this._( "Would you like to proceed?" ));

            Ext.MessageBox.show({
                title : this._( "Save Confirmation" ),
                msg : message.join( "\n" ),
                buttons : Ext.MessageBox.YESNO,
                icon : Ext.MessageBox.INFO,
                fn : handler
            });
        } else {
            handler( "yes", "" );
        }
    },

    confirmedSaveSettings : function( buttonId, text, panel )
    {
        if ( buttonId != "yes" ) {
            return;
        }
        
        var saveConfig = null;
        if ( panel != null ) {
            saveConfig = panel.saveConfig;
        }

        var title;
        var message;

        if ( saveConfig != null ) {
            title = saveConfig.waitTitle;
            message = saveConfig.waitMessage;
        }
        if ( title == null ) title = this._( "Saving..." );
        if ( message == null ) message = this._( "Please wait" );

        /* Validate */
        Ext.MessageBox.wait( title, message );
        
        var handler = this.completeSaveSettings.createDelegate( this, [ panel ], true );
        var errorHandler = this.errorSaveSettings.createDelegate( this, [ panel ], true );

        if ( panel.saveSettings != null ) {
            panel.saveSettings( handler, errorHandler );
        } else if ( panel.saveMethod != null ) {
            panel.updateSettings( panel.settings );
            Ung.Alpaca.Util.executeRemoteFunction( panel.saveMethod,
                                                   handler,
                                                   errorHandler,
                                                   panel.settings );
        } else {
            this.errorSaveSettings();
        }
    },

    completeSaveSettings : function( result, response, options, panel )
    {
        var title;
        var message;
        var saveConfig = null;
        if ( panel != null ) {
            saveConfig = panel.saveConfig;
        }
        if ( saveConfig != null ) {
            title = saveConfig.successTitle;
            message = saveConfig.successMessage;
        }
        if ( title == null ) title = this._( 'Saved Settings' );
        if ( message == null ) message = this._( 'Settings have been saved successfuly' );

        Ext.MessageBox.show({  
            title : title,
            msg : message,
            buttons : Ext.MessageBox.OK,
            icon : Ext.MessageBox.INFO
        });

        /* Reload the page in the background */
        application.reloadCurrentQueryPath();
    },

    errorSaveSettings : function( result, options, panel )
    {
        var title;
        var message;
        var saveConfig = null;
        if ( panel != null ) {
            panel.saveConfig;
        }

        if ( saveConfig != null ) {
            title = saveConfig.errorTitle;
            message = saveConfig.errorMessage;
        }
        if ( title == null ) title = this._( 'Internal Error' );
        if ( message == null ) message = this._( 'Unable to save settings.  Please try again.' );

        Ext.MessageBox.show({  
            title : title,
            msg : message,
            buttons : Ext.MessageBox.OK,
            icon : Ext.MessageBox.ERROR
        });
    },

    cancel : function()
    {
        /* Confirm settings save, if necessary */
        /* Reload the page in the background */
        application.reloadCurrentQueryPath();
    },

    // Build a help url
    buildHelpUrl : function( queryPath )
    {
        queryPath = this.buildQueryPath( queryPath );
        var controller = queryPath["controller"];
        var page = queryPath["page"];

        return this.HELP_URL + "?version=" + Ung.Alpaca.version + "&source=" + this.HELP_NAMESPACE + "_" + controller + "_" + page;
    },

    // private : Get the key used to uniquely identify a controller, page combination
    buildPageKey : function( controller, page )
    {
        return  "/" + controller + "/" + page;
    },

    isUvmSessionExpired : function( response )
    {
        if ( response.getResponseHeader["Content-Type"] != "text/html; charset=utf-8" ) {
            return false;
        }
        
        var match = new RegExp( "method=\"post\" action=\"\/auth\/login" ); 
       
        if ( response.responseText.search( match ) > 0 ) {
            return true;
        }
        
        return false;
    }
}
