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
                xtype:"fieldset",
                title : this.i18n._('Hostname'),                                            
                defaults : {
                    xtype : "textfield",
                    itemCls : 'label-width-1'                                            
                },
                items : [{
                    fieldLabel : this._("Hostname"),
                    name : "hostname_settings.hostname",
                    boxLabel : this._("(eg: gateway.example.com)"),
                    vtype: 'hostname'
                },{
                    fieldLabel : this._("Domain Name Suffix"),
                    name : "dns_server_settings.suffix",
                    boxLabel : this._("(eg: example.com)")
                }]
            },{
                xtype:"fieldset",
                title : this.i18n._('Dynamic DNS Client Configuration'),                                                
               
                defaults : {
                    xtype : "textfield",
                    itemCls : 'label-width-1'                        
                },
                items : [{
                    xtype : "checkbox",
                    name : "ddclient_settings.enabled",
                    fieldLabel : this._("Enabled")
                },{
                    xtype : "combo",
                    fieldLabel : this._("Service"),
                    name : "ddclient_settings.service",
                    mode : "local",
                    triggerAction : "all",
                    editable : false,
                    store : this.settings["ddclient_services"]
                },{
                    fieldLabel : this._("Login"),
                    name : "ddclient_settings.login"
                },{
                    xtype : "textfield",
                    fieldLabel : this._("Password"),
                    inputType : "password",
                    name : "ddclient_settings.password"
                },{
                    fieldLabel : this._("Hostname(s)"),
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
