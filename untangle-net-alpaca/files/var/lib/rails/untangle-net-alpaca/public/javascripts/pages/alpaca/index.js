Ext.ns('Ung');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Alpaca');

if ( Ung.Alpaca.Glue.hasPageRenderer( "alpaca", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Alpaca.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function()
    {        
        var items = [];

        items.push({
            xtype : 'label',
            html : String.format( this._( "{0}Currently in {1} mode.{2}" ),
                                  "<p>", this.settings.config_level.name, "</p>" )
        });

        if ( Ung.Alpaca.isAdvanced ) {
            items.push({
                xtype : 'label',
                html : String.format( this._( "You are currently in Advanced mode, in order to return to Basic mode, you must rerun the wizard which will reset your settings." ),
                                      "<p>", "</p>" )
            },{
                xtype : 'button',
                text : this._( 'Run Wizard.' ),
                handler : this.toBasic,
                scope : this
            });
        } else {
            items.push({
                xtype : 'label',
                html : String.format( this._( "{0}Click the following button to switch into advanced mode.  Since Advanced mode contains settings that are unavailable in basic mode, you must rerun the wizard and reset all of your settings in order to return to basic mode.{1}" ),
                                      "<p>", "</p>" )
            },{
                xtype : 'button',
                text : this._( 'Switch to Advanced Mode.' ),
                handler : this.toAdvanced,
                scope : this
            });    
        }

        
        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            items : items
        });
        
        Ung.Alpaca.Pages.Alpaca.Index.superclass.initComponent.apply( this, arguments );
    },

    toAdvanced : function()
    {
        var handler = this.completeToAdvanced.createDelegate( this );
        Ung.Alpaca.Util.executeRemoteFunction( "/alpaca/set_to_advanced", handler );
    },

    completeToAdvanced : function()
    {
        window.location = "/alpaca/alpaca/";
    },
    
    toBasic : function()
    {
        /* Go to the wizard. */
        window.location = "/alpaca/wizard/";
    }
});

Ung.Alpaca.Pages.Alpaca.Index.settingsMethod = "/alpaca/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "alpaca", "index", Ung.Alpaca.Pages.Alpaca.Index );
