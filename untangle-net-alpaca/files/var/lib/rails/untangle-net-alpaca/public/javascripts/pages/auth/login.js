Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Auth');

if ( Ung.Alpaca.Glue.hasPageRenderer( "auth", "login" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Auth.Login = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function()
    {        
        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                autoHeight : true,
                items : [{
                    xtype : "textfield",
                    name : "username",
                    fieldLabel : this._( "Username" )
                },{
                    xtype : "textfield",
                    name : "password",
                    inputType : "password",
                    fieldLabel : this._( "Password" )
                },{
                    xtype : "button",
                    text : this._( "Login" ),
                    handler : this.login,
                    scope : this
                }]
            }]
        });
        
        Ung.Alpaca.Pages.Auth.Login.superclass.initComponent.apply( this, arguments );
    },

    login : function( )
    {
        var settings = {};
        this.updateSettings( settings );
        
        /* Validate */
        Ext.MessageBox.wait( this._( "Logging In" ), this._( "Please wait" ));
        
        var handler = this.completeLogin.createDelegate( this );
        var errorHandler = this.errorLogin.createDelegate( this );

        Ung.Alpaca.Util.executeRemoteFunction( "/auth/do_login", handler, errorHandler, settings );
    },

    completeLogin : function( settings, response, options )
    {
        var path = settings["path"];
        if ( path == null ) {
            path = "/alpaca/network";
        }

        window.location = path;
    },
    
    errorLogin : function()
    {
        Ext.MessageBox.show({
            title : this._( "Error Logging in" ), 
            msg : this._( "Please try again" ),
            buttons : Ext.MessageBox.OK
        });
    }
});

Ung.Alpaca.Glue.registerPageRenderer( "auth", "login", Ung.Alpaca.Pages.Auth.Login );
