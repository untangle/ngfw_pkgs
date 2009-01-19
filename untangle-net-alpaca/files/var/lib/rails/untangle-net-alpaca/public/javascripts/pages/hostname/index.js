Ext.ns('Ung');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Hostname');

if ( Ung.Alpaca.Glue.hasPageRenderer( "hostname", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Hostname.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function(  )
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
                    fieldLabel : this._("Hostname"),
                    name : "hostname_settings.hostname",
                    boxLabel : "(eg: gateway.example.com)"
                },{
                    fieldLabel : "Domain Name Suffix",
                    name : "dns_server_settings.suffix",
                    boxLabel : "(eg: example.com)"
                }]
            },{
                xtype : "label",
                html : "Dynamic DNS Client Configuration"
            },{
                defaults : {
                    xtype : "textfield"
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
                    store : this.settings["ddclient_services"]
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
        
        Ung.Alpaca.Pages.Hostname.Index.superclass.initComponent.apply( this, arguments );
    },

    saveMethod : "/hostname/set_settings"
});

Ung.Alpaca.Pages.Hostname.Index.settingsMethod = "/hostname/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "hostname", "index", Ung.Alpaca.Pages.Hostname.Index );
