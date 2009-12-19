//The location of the blank pixel image
Ext.BLANK_IMAGE_URL = '/ext/resources/images/default/s.gif';

Ext.ns('Ung');
Ext.ns('Ung.Alpaca');    

Ung.Alpaca.Application = Ext.extend( Ext.Panel, {
    constructor : function()
    {
        this.i18n = new Ung.I18N({ map : Ung.Alpaca.i18n });
        this._ = this.i18n._.createDelegate( this.i18n );

        Ung.Alpaca.Util._ = this._;
        Ung.Alpaca.Glue._ = this._;

        Ext.MessageBox.buttonText = {
            ok : this._( "OK" ),
            yes : this._( "Yes" ),
            no : this._( "No" ),
            cancel : this._( "Cancel" )
        };

        this.hasSaveHandler = false;
        
        this.saveButton = new Ext.Toolbar.Button({
            text : this._( "Save" ),
            disabled : true,
            handler : this.onSave,
            iconCls : 'save-icon',
            scope : this
        });

        this.cancelButton = new Ext.Toolbar.Button({
            text : this._( "Cancel" ),
            handler : this.onCancel,
            iconCls : 'cancel-icon',            
            scope : this
        });

        this.helpButton = new Ext.Toolbar.Button({
            text : this._( "Help" ),
            handler : this.onHelp,
            iconCls : 'icon-help',
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

    initComponent : function()
    {
        Ung.Alpaca.Application.superclass.initComponent.apply( this, arguments );
        
        this.addEvents( "fieldchanged" );
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
        /* Clear all of the listeners for fieldChange events (this event should be reregistered on
         * each page. */
        var fieldchanged = this.events["fieldchanged"];
        if (( fieldchanged != null ) && ( typeof( fieldchange ) == "object" ) &&
            fieldchanged.clearListeners) {
            this.events["fieldchanged"].clearListeners();
        }

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
            handler( {}, { jsonData : {}}, null );
        }
    },

    // private : This is a handler that is called after the settings have been loaded.
    // param targetPanel The panel that the new page is going to be rendered into.  If this is null,
    // this will use the current active panel in the menu.
    completeLoadSettings : function( settings, response, options, queryPath, panelClass  )
    {
        var i18nMap = response.jsonData["i18n_map"];
        if ( i18nMap == null ) {
            i18nMap = {};
        }

        var panel = new panelClass({ settings : settings, i18nMap : i18nMap });

        this.configureActions( panel.saveSettings || panel.saveMethod );

        /* An override if the panel doesn't require a change for the save button be enabled */
        if ( panel.enableSave ) {
            this.enableSaveButton();
        }

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
        var handler = this.completeSwitchToQueryPath.createDelegate( this, [ queryPath ], true );

        if ( this.hasSaveHandler && !this.saveButton.disabled ) {
            var m = String.format( this._( "{0}Leaving this page will lose unsaved changes.{1}{0}Click 'Continue' to proceed and lose changes,{1}{0}or 'Cancel' to stay on this page.{1}" ), "<p>", "</p>" );
            Ext.MessageBox.show({
                title: this._( "Warning" ),
                msg: m,
                width : 400,
                buttons : {
                    ok : "Continue",
                    cancel : "Cancel"
                },
                fn : handler,
                icon : Ext.MessageBox.WARNING
            });
        } else {
            handler( "ok", "" );
        }
    },
    
    completeSwitchToQueryPath : function( buttonId, __unused__, queryPath )
    {
        if ( buttonId == "ok" ) {
            queryPath = Ung.Alpaca.Glue.buildQueryPath( queryPath );
            var delegate = this.completeLoadPage.createDelegate( this, [ queryPath ], true );
            Ung.Alpaca.Util.loadScript( queryPath, delegate );
        }
    },

    configureActions : function( hasSaveHandler )
    {
        var toolbar = this.getBottomToolbar();

        this.hasSaveHandler = ( hasSaveHandler != null );
        if ( hasSaveHandler != null ) {
            this.saveButton.setHandler( this.onSave, this );
            this.saveButton.disable();
            this.cancelButton.enable();
        } else {
            this.saveButton.setHandler( null );
            this.saveButton.disable();
            this.cancelButton.disable();
        }
    },

    enableSaveButton : function()
    {
        if ( this.hasSaveHandler ) {
            this.saveButton.enable();
        }
    },

    onHelp : function()
    {
        var url = Ung.Alpaca.Glue.buildHelpUrl( this.currentQueryPath );
        var w = window.open( url, "_blank", "height=600,width=775,scrollbars=1,toolbar=1,status=1,location=1,menubar=1,resizeable=1" );

        if ( w == null ) {
            var m = String.format( this._( "{0}Unable to open a new window, click {1}here{2} to try again.{3}" ), "<p>", "<a href=\"" + url + "\" target=\"_blank\">", "</a>", "</p>" );
            Ext.MessageBox.show({
                title: this._( "Popup Blocker" ),
                msg: m,
                buttons : Ext.MessageBox.OK,
                icon : Ext.MessageBox.INFO,
                width : 300
            });
        }
    },

    onSave : function()
    {
        Ung.Alpaca.Glue.saveSettings( this.layout.activeItem );
    },

    onCancel : function()
    {
        Ung.Alpaca.Glue.cancel();
    },

    onFieldChange : function()
    {
        this.enableSaveButton();

        this.fieldChanged();
    },

    fieldChanged : function()
    {
        this.fireEvent( "fieldchanged", this );
    }
});

var main = null;

var application = null;

var viewport = null;

// application main entry point
function alpacaOnReady() {
    Ext.QuickTips.init( false );

    application = new Ung.Alpaca.Application();
    
    Ung.Alpaca.Util.initExtVTypes(application.i18n);

    viewport = new Ext.Viewport({
        layout : 'border',
        items : application
    });

    path = Ung.Alpaca.queryPath;

    if( path == null ) {
        path = document.location.pathname;
        var search = document.location.search;
        if ( search != null && search.length > 0 ) {
            path += "?" + search;
        }
    }

    application.switchToQueryPath( path );
};

