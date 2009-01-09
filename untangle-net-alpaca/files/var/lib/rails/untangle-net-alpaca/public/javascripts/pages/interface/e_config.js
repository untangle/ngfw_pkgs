Ext.ns('Ung');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Interface');

if ( Ung.Alpaca.Glue.hasPageRenderer( "interface", "e_config" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Interface.Config = Ext.extend( Ung.Alpaca.PagePanel, {
    constructor : function( config )
    {
        this.switchBlade = new Ext.Panel({
            layout : 'card',
            activeItem : 0,
            border : false,
            defaults : {
                border : false
            },
            items : [
                this.staticPanel( config.settings ),
                this.dynamicPanel( config.settings ),
                this.bridgePanel( config.settings ),
                this.pppoePanel( config.settings )
            ]
        });

        Ext.apply( this, {
            items : [{
                xtype :"label",
                html : "Design Number"
            },{
                autoHeight : true,
                xtype : "fieldset",
                items : [{
                    fieldLabel : "Config Type",
                    xtype : "combo",
                    name : "interface.config_type",
                    mode : "local",
                    triggerAction : "all",
                    editable : false,
                    store :  config.settings["config_types"],
                    listeners : {
                        "select" : {
                            fn : this.onSelectConfigType,
                            scope : this
                        }
                    }
                },{
                    xtype : "checkbox",
                    fieldLabel : "Is WAN Interface",
                    name : "interface.wan"
                }]
            }, this.switchBlade ]
        });

        Ung.Alpaca.Pages.Interface.Config.superclass.constructor.apply( this, arguments );
    },

    saveMethod : "/interface/set_settings",

    staticPanel : function( settings )
    {        
        return new Ext.Panel({
            layout : 'form',
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                autoHeight : true,
                defaults : {
                    xtype : "textfield"
                },
                items : [{
                    fieldLabel : "Primary IP Address and Netmask",
                    name : "static.primary_address"
                }]
            }, this.buildAliasGrid( settings, "static_aliases" ), {
                autoHeight : true,
                defaults : {
                    xtype : "textfield",
                },
                items : [{
                    fieldLabel : "MTU",
                    name : "static.mtu"
                }, this.buildEthernetMediaCombo( settings )]
            }]
        });
    },

    dynamicPanel : function( settings )
    {
        return new Ext.Panel({
            layout : 'form',
            autoHeight : true,
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                autoHeight : true,
                defaults : {
                    xtype : "textfield"
                },
                items : [{
                    fieldLabel : "IP Address",
                    name : "dynamic.ip"
                },{
                    fieldLabel : "Netmask",
                    name : "dynamic.netmask"
                },{
                    fieldLabel : "Default Gateway",
                    name : "dynamic.default_gateway"
                },{
                    fieldLabel : "Primary DNS Server",
                    name : "dynamic.dns_1"
                },{
                    fieldLabel : "Secondary DNS Server",
                    name : "dynamic.dns_2"
                },{
                    fieldLabel : "MTU",
                    name : "dynamic.mtu"
                }, this.buildEthernetMediaCombo( settings ), {
                    xtype : "button",
                    text : "Renew Lease",
                }]
            }, this.buildAliasGrid( settings, "dynamic_aliases" )]
        });

    },

    bridgePanel : function( settings )
    {
        return new Ext.Panel({
            layout : 'form',
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                autoHeight : true,
                defaults : {
                    xtype : "textfield"
                },
                items : [{
                    fieldLabel : "Bridge To",
                    xtype : "combo",
                    name : "bridge.bridge_interface_id",
                    mode : "local",
                    triggerAction : "all",
                    editable : false,
                    listWidth : 160,
                    store :  settings["bridgeable_interfaces"]
                }, this.buildEthernetMediaCombo( settings )]
            }]
        });                
    },

    pppoePanel : function( settings )
    {
        return new Ext.Panel({
            layout : 'form',
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                autoHeight : true,
                defaults : {
                    xtype : "textfield"
                },
                items : [{
                    fieldLabel : "Username",
                    name : "pppoe.username"
                },{
                    inputType : "password",
                    fieldLabel : "Password",
                    name : "pppoe.password"
                },{
                    xtype : "checkbox",
                    fieldLabel : "Use peer DNS",
                    name : "pppoe.use_peer_dns"
                }, this.buildEthernetMediaCombo( settings ),{
                    xtype : "button",
                    text : "Renew Lease",
                }]
            }, this.buildAliasGrid( settings, "pppoe_aliases" ), {
                autoHeight : true,
                defaults : {
                    xtype : "textfield"
                },
                items : [{
                    xtype : "textarea",
                    fieldLabel : "Secret Field",
                    name : "pppoe.secret_field"                    
                }]
            }]
        });
    },

    buildAliasGrid : function( settings, entriesField )
    {
        var aliases = new Ung.Alpaca.EditorGridPanel({
            recordFields : [ "network", "id" ],
            
            tbar : [{
                text : "Add",
                handler : this.addStaticAlias,
                scope : this
            }],
            
            entries : settings[entriesField],
            
            columns : [{
                header : "Address and Netmask",
                width: 200,
                sortable: true,
                dataIndex : "network",
                editor : new Ext.form.TextField({
                    allowBlank : false
                })
            }]
        });
        
        aliases.store.load();

        return aliases;
    },

    buildEthernetMediaCombo : function( settings )
    {
        return new Ext.form.ComboBox({
            fieldLabel : "Ethernet Media",
            name : "media",
            mode : "local",
            triggerAction : "all",
            editable : false,
            listWidth : 160,
            store :  settings["media_types"]
        });
    },
    
    onSelectConfigType : function( __, record, index )
    {
        this.switchBlade.layout.setActiveItem( index );
    },

    addStaticAlias : function()
    {
    }
});

Ung.Alpaca.Pages.Interface.Config.settingsMethod = "/interface/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "interface", "e_config", Ung.Alpaca.Pages.Interface.Config );

