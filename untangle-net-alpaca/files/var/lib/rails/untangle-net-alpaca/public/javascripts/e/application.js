//The location of the blank pixel image
Ext.BLANK_IMAGE_URL = '/alpaca/ext/resources/images/default/s.gif';

Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

Ung.Alpaca.Application = {
    // Map of all of the currently loaded pages.  Indexed with
    // buildPageKey( controller, page ) -> page renderer.
    pages : {},

    // The DIV where the main page should be rendered.
    pageDiv : "base",
    
    /* This parses the path of the URL to determine the current page.
     * The URL looks like "/alpaca/<controller>/<page>"
     * If <page> is not set, then it defaults to index.
     * If <controller> is not sett, the it defaults to network.
     */
    getRequestedPage : function()
    {
        var path = document.location.pathname;
        path = path.replace( /\/+/g, "/" )
        var a = path.split( "/" );
        var controller = a[2];
        var page = a[3];
        var pageID = parseInt( a[4] );
        
        if (( page == null ) || ( page.length == 0 )) page = "index";
        if (( controller == null ) || ( controller.length == 0 )) controller = "network";

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

    // Recreate the current panel, and reload its settings.
    reloadCurrentPath : function()
    {        
        this.completeLoadPage( {}, {}, this.currentPath );
    },

    // Get the currently rendered panel.
    getCurrentPanel : function()
    {
        return this.currentPanel;
    },

    /*
     *  Get the current path, eg /hostname/index/1
     */
    getCurrentPath : function()
    {
        return this.currentPath;
    },

    // private : This is a handler called after a page has been loaded.
    completeLoadPage : function( response, options, newPage )
    {
        var controller = newPage["controller"];
        var page = newPage["page"];
        var pageID = newPage["pageID"];

        var panelClass = Ung.Alpaca.Application.getPageRenderer( controller, page );
        
        var handler = this.completeLoadSettings.createDelegate( this, [ newPage, panelClass ], true );

        if ( panelClass.loadSettings != null ) {
            panelClass.loadSettings( newPage, handler );
        } else if ( panelClass.settingsMethod != null ) {
            var m = panelClass.settingsMethod;
            if ( pageID ) {
                m += "/" + pageID;
            }
            Ung.Alpaca.Util.executeRemoteFunction( m, handler );
        } else {
            handler( null, null, null );
        }        
    },

    // private : This is a handler that is called after the settings have been loaded.
    completeLoadSettings : function( settings, response, options, newPage, panelClass )
    {
        var panel = new panelClass({ settings : settings });
                
        /* First clear out any children. */
        var base = Ext.get( this.pageDiv );
        base.update( "" );
        panel.render( base );

        /* Have to call this after rendering */
        panel.populateForm();

        this.currentPanel = panel;
        this.currentPath = newPage;        
    },

    // private : Get the key used to uniquely identify a controller, page combination
    buildPageKey : function( controller, page )
    {
        return  "/" + controller + "/" + page;
    }
}
 
// application main entry point
Ext.onReady(function() {
    Ext.QuickTips.init();

    var newPage = Ung.Alpaca.Application.getRequestedPage();

    Ung.Alpaca.Util.loadScript( newPage, Ung.Alpaca.Application.completeLoadPage.createDelegate(  Ung.Alpaca.Application, [newPage], true ));
});

