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
                this.dynamicPanel( config.settings )
            ]
        });

        Ext.apply( this, {
            items : [{
                autoHeight : true,
                xtype : "fieldset",
                items : {
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
                }
            }, this.switchBlade ]
        });

        Ung.Alpaca.Pages.Interface.Config.superclass.constructor.apply( this, arguments );
    },

    saveMethod : "/interface/set_settings",

    staticPanel : function( settings )
    {        
        return new Ext.Panel({
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
            }, this.buildAliasGrid( settings, "static_aliases" ) ]
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
                }]
            }, this.buildAliasGrid( settings, "dynamic_aliases" )]
        });

    },

    bridgePanel : function( settings )
    {
        
    },

    pppoePanel : function( settings )
    {

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

