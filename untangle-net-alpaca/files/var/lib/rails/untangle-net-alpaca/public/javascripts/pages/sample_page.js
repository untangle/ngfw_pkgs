Ext.ns('Ung');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Sample');

if ( Ung.Alpaca.Application.hasPageRenderer( "sample", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Sample.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    /* This is the URL that is used to fetch the settings, then the returned 
     * value is passed into populateForm.
     * To override this functionality, redefine loadSettings.
     */
    settingsMethod : "/sample/get_settings",

    initComponent : function()
    {
        Ext.apply( this, {
            defaults : {
                autoHeight : true,
                xtype : "fieldset"
            },
            items : [{
                defaults : {
                    xtype : "textfield",
                },
                items : [{
                    fieldLabel : "Setting",
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
                    displayField : "serviceName",
                    name : "ddclient_settings.service",
                    selectable : false,
                    store : this.servicesStore
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
            },{
                xtype : "button",
                text : "Save Settings",
                handler : this.saveSettings.createDelegate( this )
            }]
        });
        
        Ung.Alpaca.Pages.Hostname.Index.superclass.initComponent.apply( this, arguments );
    },

    onRender : function()
    {
        Ung.Alpaca.Pages.Hostname.Index.superclass.onRender.apply( this, arguments );
    },

    populateForm : function( settings )
    {
        /* Create the store for the ddclient services */
        this.servicesData.splice( 0 );
        
        var ddclientServices = settings["ddclient_services"];
        for ( var c = 0 ; c < ddclientServices.length ; c++ ) {
            this.servicesData.push( ddclientServices[c] );
        }
        this.servicesStore.load();
        
        Ung.Alpaca.Pages.Hostname.Index.superclass.populateForm.apply( this, arguments );
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
        Ung.Alpaca.Application.reloadCurrentPath();
    }
});

/* Set the settingsMethod in order call this method before loading the panel. */
Ung.Alpaca.Pages.Sample.Index.settingsMethod = "/sample/get_settings";

/* For more sophisticated settings, you can define your own loadsettings method. */
Ung.Alpaca.Pages.Sample.Index.loadSettings = function( newPage, handler )
{
    
}

Ung.Alpaca.Application.registerPageRenderer( "sample", "index", Ung.Alpaca.Pages.Sample.Index );
