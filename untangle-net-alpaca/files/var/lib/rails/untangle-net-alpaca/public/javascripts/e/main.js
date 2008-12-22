
Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

Ung.Alpaca.Main = Ext.extend( Ext.TabPanel, {
    initComponent : function()
    {
        var menuItems = [];
        for ( var c = 0 ; c < Ung.Alpaca.BasicMenuData.length ; c++ ) {
            var menuData = Ung.Alpaca.BasicMenuData[c];
            menuItems[c] = { 
                title : menuData.name,
                page : menuData.page,
                id : this.buildTabId( menuData.page )
            }
        }

        this.saveButton = new Ext.Toolbar.Button({
            text : "Save"
        });

        this.cancelButton = new Ext.Toolbar.Button({
            text : "Cancel",
            handler : this.onCancel,
            scope : this
        });
        
        Ext.apply( this, {
            bbar : [{
                text : "Help",
                name : "help"
            }, '->', this.cancelButton, this.saveButton ],
            items : menuItems
        });

        Ung.Alpaca.Main.superclass.initComponent.apply( this, arguments );

        this.addListener( 'beforetabchange', this.onBeforeTabChange, this );
        this.addListener( 'tabchange', this.onTabChange, this );
    },

    onBeforeTabChange : function( __, newTab, currentTab )
    {
        /* Clear out anything on the current tab */
        this.lastTab = currentTab;

        /* Disable the save and cancel buttons */
        this.configureActions( null );
    },

    onTabChange : function( __, currentTab )
    {
        var el = currentTab.getEl();
        var page = Ung.Alpaca.Application.convertPathToPage( currentTab.page );
        Ung.Alpaca.Util.loadScript( page, Ung.Alpaca.Application.completeLoadPage.createDelegate(  Ung.Alpaca.Application, [ page, currentTab ], true ));
    },

    clearLastTab : function()
    {
        if (( this.lastTab != null ) &&  ( this.lastTab.getEl() != null )) {
            this.lastTab.getEl().update( "" );
        }
    },

    onCancel : function()
    {
        Ung.Alpaca.Application.reloadCurrentPath();
    },

    switchToPage : function( page )
    {
        var tabId = this.buildTabId( page );
        this.setActiveTab( tabId );
    },

    buildTabId : function( page )
    {
        /* Squash multiple / in paths */
        page = page.replace( /\/+/g, "/" );
        /* Get rid of parameters */
        page = page.replace( /\?.*/, "" );
        /* Get rid of trailing slashes */
        page = page.replace( /\/$/, "" );
        
        return "tab-menu" + page.replace( /\//g, "-" );
    },

    configureActions : function( scope, saveHandler )
    {
        var toolbar = this.getBottomToolbar();

        if ( saveHandler != null ) {
            this.saveButton.setHandler( saveHandler, scope );
            this.saveButton.enable();
            this.cancelButton.enable();
        } else {
            this.saveButton.setHandler( null );
            this.saveButton.disable();
            this.cancelButton.disable();
        }
    }
});
