//The location of the blank pixel image
Ext.BLANK_IMAGE_URL = '/alpaca/ext/resources/images/default/s.gif';

Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

Ung.Alpaca.Application = {
    pages : {},

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
        
        if (( page == null ) || ( page.length == 0 )) page = "index";
        if (( controller == null ) || ( controller.length == 0 )) controller = "network";

        return { "controller" : controller, "page" : page };
    },

    hasPageRenderer : function( controller, page )
    {
        return ( this.pages[this.buildPageKey( controller, page )] != null );
    },

    registerPageRenderer : function( controller, page, renderer )
    {
        this.pages[this.buildPageKey( controller, page )] = renderer;
    },

    completeLoadPage : function( response, options, newPage )
    {
        var controller = newPage["controller"];
        var page = newPage["page"];

        var panelClass = Ung.Alpaca.Application.getPageRenderer( controller, page );
        var panel = new panelClass();
        
        panel.loadSettings();
        
        /* First clear out any children. */
        var base = Ext.get( this.pageDiv );
        base.update( "" );
        panel.render( base );

        this.currentPanel = panel;
        this.currentPath = newPage;
    },

    reloadCurrentPath : function()
    {        
        this.completeLoadPage( {}, {}, this.currentPath );
    },

    getPageRenderer : function( controller, page )
    {
        return this.pages[this.buildPageKey( controller, page )];
    },

    buildPageKey : function( controller, page )
    {
        return  "/" + controller + "/" + page;
    },

    getCurrentPanel : function()
    {
        return this.currentPanel;
    },

    getCurrentPath : function()
    {
        return this.currentPath;
    }
}
 
// application main entry point
Ext.onReady(function() {
    Ext.QuickTips.init();

    var newPage = Ung.Alpaca.Application.getRequestedPage();

    Ung.Alpaca.Util.loadScript( newPage, Ung.Alpaca.Application.completeLoadPage.createDelegate(  Ung.Alpaca.Application, [newPage], true ));
});

