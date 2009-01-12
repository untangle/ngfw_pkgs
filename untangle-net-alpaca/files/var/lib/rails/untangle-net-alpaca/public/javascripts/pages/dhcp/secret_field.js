Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Dhcp');

if ( Ung.Alpaca.Glue.hasPageRenderer( "dhcp", "secret_field" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Dhcp.SecretField = Ext.extend( Ung.Alpaca.PagePanel, {
    constructor : function( config )
    {
        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                /* Not in the default in order to accomodate grids. */
                autoHeight : true,
                defaults : {
                    xtype : "textfield",
                },
                items : [{
                    xtype : "checkbox",
                    fieldLabel : "Enabled",
                    name : "dhcp_server_settings.is_custom_field_enabled"
                },{
                    fieldLabel : "Custom Field",
                    xtype : "textarea",
                    name : "dhcp_server_settings.custom_field"
                }]
            }]
        });
        
        Ung.Alpaca.Pages.Dhcp.SecretField.superclass.constructor.apply( this, arguments );
    },

    saveMethod : "/dhcp/set_settings"
});

Ung.Alpaca.Pages.Dhcp.SecretField.settingsMethod = "/dhcp/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "dhcp", "secret_field", Ung.Alpaca.Pages.Dhcp.SecretField );

