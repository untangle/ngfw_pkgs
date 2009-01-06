Ext.ns('Ung');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Hostname');

if ( Ung.Alpaca.Glue.hasPageRenderer( "hostname", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Hostname.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    constructor : function( config )
    {
        Ext.apply( this, {
            defaults : {
                autoHeight : true,
                xtype : "fieldset"
            },
            items : [{
                defaults : {
                    xtype : "textfield"
                },
                items : [{
                    fieldLabel : "Hostname",
                    name : "hostname_settings.hostname"
                },{
                    fieldLabel : "Domain Name Suffix",
                    name : "dns_server_settings.suffix"
                }]
            },{
                xtype : "label",
                html : "Dynamic DNS Client Configuration"
            },{
                defaults : {
                    xtype : "textfield",
                },
                items : [{
                    xtype : "checkbox",
                    name : "ddclient_settings.enabled",
                    fieldLabel : "Enabled"
                },{
                    xtype : "combo",
                    fieldLabel : "Service",
                    name : "ddclient_settings.service",
                    mode : "local",
                    triggerAction : "all",
                    editable : false,
                    store : config.settings["ddclient_services"]
                },{
                    fieldLabel : "Login",
                    name : "ddclient_settings.login"
                },{
                    xtype : "textfield",
                    fieldLabel : "Password",
                    inputType : "password",
                    name : "ddclient_settings.password"
                },{
                    fieldLabel : "Hostname(s)",
                    name : "ddclient_settings.hostname"
                }]
            }]
        });
        
        Ung.Alpaca.Pages.Hostname.Index.superclass.constructor.apply( this, arguments );
    },

    onRender : function()
    {
        Ung.Alpaca.Pages.Hostname.Index.superclass.onRender.apply( this, arguments );
    },

    saveSettings : function()
    {
        Ext.MessageBox.wait("Saving...", "Please wait");

        this.updateSettings( this.settings );

        Ung.Alpaca.Util.executeRemoteFunction( "/hostname/set_settings", 
                                               this.completeSaveSettings.createDelegate( this ), 
                                               null,
                                               this.settings );
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
        Ung.Alpaca.Glue.reloadCurrentPath();
    }    
});

Ung.Alpaca.Pages.Hostname.Index.settingsMethod = "/hostname/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "hostname", "index", Ung.Alpaca.Pages.Hostname.Index );
