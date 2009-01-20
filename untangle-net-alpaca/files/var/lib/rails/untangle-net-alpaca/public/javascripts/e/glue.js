Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

Ung.Alpaca.Glue = {
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
        /* Confirm settings save, if necessary */

        /* Validate */

        Ext.MessageBox.wait( "Saving...", "Please wait" );
        
        var handler = this.completeSaveSettings.createDelegate( this );
        var errorHandler = this.errorSaveSettings.createDelegate( this );

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

    completeSaveSettings : function()
    {
        Ext.MessageBox.show({  
            title : 'Saved Settings',
            msg : 'Settings have been saved successfuly',
            buttons : Ext.MessageBox.OK,
            icon : Ext.MessageBox.INFO
        });

        /* Reload the page in the background */
        application.reloadCurrentQueryPath();
    },

    errorSaveSettings : function()
    {
        Ext.MessageBox.show({  
            title : 'Internal Error',
            msg : 'Unable to save settings',
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

    // private : Get the key used to uniquely identify a controller, page combination
    buildPageKey : function( controller, page )
    {
        return  "/" + controller + "/" + page;
    }
}
