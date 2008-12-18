Ext.ns('Ung');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Hostname');

if ( Ung.Alpaca.Application.hasPageRenderer( "hostname", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Hostname.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    /* This is the URL that is used to fetch the settings, then the returned 
     * value is passed into populateForm.
     * To override this functionality, redefine loadSettings.
     */
    settingsMethod : "/hostname/get_settings",

    initComponent : function()
    {
        var record = Ext.data.Record.create([{
            name : "serviceName",
            mapping : 0
        }]);

        this.servicesReader = new Ext.data.ArrayReader({}, record );
        
        this.servicesStore = new Ext.data.SimpleStore({
            fields : [ "serviceName" ],
            data : [[]],
            reader : this.servicesReader
        });

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
                    mode : "local",
                    displayField : "serviceName",
                    name : "ddclient_settings.service",
                    editable : false,
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
        this.servicesStore.loadData( settings["ddclient_services"] )
        
        Ung.Alpaca.Pages.Hostname.Index.superclass.populateForm.apply( this, arguments );
    }
});

Ung.Alpaca.Application.registerPageRenderer( "hostname", "index", Ung.Alpaca.Pages.Hostname.Index );
