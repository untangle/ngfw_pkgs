//The location of the blank pixel image
Ext.BLANK_IMAGE_URL = '/ext/resources/images/default/s.gif';

Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

Ung.Alpaca.Application = Ext.extend( Ext.Panel, {
    constructor : function()
    {
        this.i18n = new Ung.I18N({ map : Ung.Alpaca.i18n });
        this._ = this.i18n._.createDelegate( this.i18n );

        this.saveButton = new Ext.Toolbar.Button({
            text : this._( "Save" ),
            handler : this.onSave,
            scope : this
        });

        this.cancelButton = new Ext.Toolbar.Button({
            text : this._( "Cancel" ),
            handler : this.onCancel,
            scope : this
        });

        this.helpButton = new Ext.Toolbar.Button({
            text : this._( "Help" ),
            handler : this.onHelp,
            scope : this
        });
        
        this.toolbar = new Ung.Alpaca.Toolbar();
        
        Ext.apply( this, {
            layout : 'card',
            region : 'center',
            tbar : this.toolbar,
            bbar : [
                this.helpButton,
                '->',
                this.cancelButton,
                this.saveButton
            ]
        });

        Ung.Alpaca.Application.superclass.constructor.apply( this, arguments );
    },

    // Recreate the current panel, and reload its settings.
    reloadCurrentQueryPath : function()
    {        
        this.completeLoadPage( {}, {}, this.currentQueryPath );
    },

    // private : This is a handler called after a page has been loaded.
    // param targetPanel The panel that the new page is going to be rendered into.  If this is null,
    // this will use the current active panel in the menu.
    completeLoadPage : function( response, options, queryPath )
    {
        queryPath = Ung.Alpaca.Glue.buildQueryPath( queryPath );

        var controller = queryPath["controller"];
        var page = queryPath["page"];
        var pageID = queryPath["pageID"];
        var panelClass = Ung.Alpaca.Glue.getPageRenderer( controller, page );
        
        var handler = this.completeLoadSettings.createDelegate( this, [ queryPath, panelClass ], true );

        if ( panelClass.loadSettings != null ) {
            panelClass.loadSettings( queryPath, handler );
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
    // param targetPanel The panel that the new page is going to be rendered into.  If this is null,
    // this will use the current active panel in the menu.
    completeLoadSettings : function( settings, response, options, queryPath, panelClass  )
    {
        var panel = new panelClass({ settings : settings });

        this.configureActions( panel.saveSettings || panel.saveMethod );

        var currentPanel = this.layout.activeItem;
        
        /* Keep only the current panel and the new panel that is going to be added. */
        var c = this.items.length;
        var z = 0;
        for ( ; --c > 0 ; ) {
            if ( currentPanel == this.items[z] ) {
                z++;
            }
            this.remove( z );
        }
        
        this.add( panel );
        this.layout.setActiveItem( panel );
        viewport.render();
        
        /* Have to call this after rendering */
        panel.populateForm();

        this.currentQueryPath = queryPath;        
    },

    switchToQueryPath : function( queryPath )
    {
        queryPath = Ung.Alpaca.Glue.buildQueryPath( queryPath );

        var delegate = this.completeLoadPage.createDelegate( this, [ queryPath ], true );
        Ung.Alpaca.Util.loadScript( queryPath, delegate );
    },

    configureActions : function( hasSaveHandler )
    {
        var toolbar = this.getBottomToolbar();

        if ( hasSaveHandler != null ) {
            this.saveButton.setHandler( this.onSave, this );
            this.saveButton.enable();
            this.cancelButton.enable();
        } else {
            this.saveButton.setHandler( null );
            this.saveButton.disable();
            this.cancelButton.disable();
        }
    },

    onSave : function()
    {
        Ung.Alpaca.Glue.saveSettings( this.layout.activeItem );
    },

    onCancel : function()
    {
        Ung.Alpaca.Glue.cancel();
    }
});

var main = null;

var application = null;

var viewport = null;

// application main entry point
Ext.onReady(function() {
    Ext.QuickTips.init();

    application = new Ung.Alpaca.Application();

    viewport = new Ext.Viewport({
        layout : 'border',
        items : application
    });

    var path = document.location.pathname;
    var search = document.location.search;
    if ( search != null && search.length > 0 ) {
        path += "?" + search;
    }

    application.switchToQueryPath( path );
});

