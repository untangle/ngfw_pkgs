Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Auth');

if ( Ung.Alpaca.Glue.hasPageRenderer( "auth", "logout" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Auth.Logout = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function()
    {        
        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                autoHeight : true,
                items : [{
                    xtype : "label",
                    html : this._( "Are you sure you want to logout?" )
                },{
                    xtype : "button",
                    text : this._( "Logout" ),
                    handler : this.logout,
                    scope : this
                }]
            }]
        });
        
        Ung.Alpaca.Pages.Auth.Logout.superclass.initComponent.apply( this, arguments );
    },

    logout : function( )
    {
        var settings = {};
        this.updateSettings( settings );
        
        /* Validate */
        Ext.MessageBox.wait( this._( "Logging Out" ), this._( "Please wait" ));
        
        var handler = this.completeLogout.createDelegate( this );
        var errorHandler = this.errorLogout.createDelegate( this );

        Ung.Alpaca.Util.executeRemoteFunction( "/auth/do_logout", handler, errorHandler, settings );
    },

    completeLogout : function( settings, response, options )
    {
        window.location = "/alpaca/auth/login";
    },
    
    errorLogout : function()
    {
        Ext.MessageBox.show({
            title : this._( "Error Logging out" ), 
            msg : this._( "Please try again" ),
            buttons : Ext.MessageBox.OK
        });
    }
});

Ung.Alpaca.Glue.registerPageRenderer( "auth", "logout", Ung.Alpaca.Pages.Auth.Logout );
