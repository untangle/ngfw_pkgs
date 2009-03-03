Ext.ns('Ung');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Interface');

if ( Ung.Alpaca.Glue.hasPageRenderer( "interface", "config" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Interface.Config = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function()
    {
        var items = [ this.staticPanel( this.settings ),
                      this.dynamicPanel( this.settings ),
                      this.bridgePanel( this.settings ),
                      this.pppoePanel( this.settings )];

        var config_types = this.settings["config_types"];
        
        var index = 0;
        var config_type = this.settings["interface"]["config_type"];

        /* Select the correct panel */
        for ( c = 0 ; c < config_types.length ; c++ ) {
            if ( config_types[c] == config_type ) {
                index = c;
                break;
            }
        }

        this.isWanCheckbox = new Ext.form.Checkbox({
            xtype : "checkbox",
            fieldLabel : "Is WAN Interface",
            name : "interface.wan",
            itemCls : 'label-width-2',
            listeners : {
                "check" : {
                    fn : this.onCheckWan,
                    scope : this
                }
            }
        });
        
        this.switchBlade = new Ext.Panel({
            layout : 'card',
            activeItem : index,
            border : false,
            defaults : {
                border : false
            },
            items : items
        });

        Ext.apply( this, {
            items : [{
                    xtype : "label",
                    html : this._("Configure Interface"),
                    cls : 'page-header-text'
            },{
                autoHeight : true,
                xtype : "fieldset",
                items : [{
                    fieldLabel : this._( "Config Type" ),
                    xtype : "combo",
                    name : "interface.config_type",
                    mode : "local",
                    triggerAction : "all",
                    editable : false,
                    store :  config_types,
                    width : 80,
                    listWidth : 70,
                    itemCls : 'label-width-2',
                    listeners : {
                        "select" : {
                            fn : this.onSelectConfigType,
                            scope : this
                        }
                    }
                }, this.isWanCheckbox ]
            },{
                autoHeight : true,
                wanToggle : true,
                defaults : {
                    itemCls : 'label-width-2'
                },
                xtype : "fieldset",
                items : [{
                    xtype : "numberfield",
                    fieldLabel : this._( "Internet Download Bandwidth" ),
                    name : "interface.download_bandwidth",
                    boxLabel : this._( "kbps") 
                },{
                    xtype : "numberfield",
                    fieldLabel : this._( "Internet Upload Bandwidth" ),
                    name : "interface.upload_bandwidth",
                    boxLabel : this._( "kbps") 
                },{
                    xtype : "button",
                    text : this._( "Estimate Link Speed" ),
                    handler : this.onEstimateLinkSpeed,
                    scope : this
                }]
            }, this.switchBlade ]
        });

        this.saveMethod = "/interface/set_settings/" + this.settings["interface"]["id"];

        Ung.Alpaca.Pages.Interface.Config.superclass.initComponent.apply( this, arguments );
    },

    populateForm : function()
    {
        Ung.Alpaca.Pages.Interface.Config.superclass.populateForm.apply( this, arguments );
        
        var hasWan = this.switchBlade.layout.activeItem.hasWan;
        this.isWanCheckbox.setContainerVisible( hasWan );
        
        this.onCheckWan( this.isWanCheckox, hasWan && this.isWanCheckbox.getValue());
    },

    saveMethod : "/interface/set_settings/",

    staticPanel : function( settings )
    {
        /* Iterate the aliases and remove the first one first primary  */
        var staticAliases = settings["static_aliases"];
        var primaryAddress = staticAliases.splice( 0, 1 )[0];

        if ( primaryAddress == null ) {
            primaryAddress = "";
        } else {
            primaryAddress = primaryAddress["ip"] + " / " + primaryAddress["netmask"];
        }
        settings["static"]["primary_address"] = primaryAddress;
        
        var items = [{
                autoHeight : true,
                defaults : {
                    xtype : "textfield",
                    itemCls : 'label-width-2'
                },
                items : [{
                    fieldLabel : this._( "Primary IP Address and Netmask" ),
                    name : "static.primary_address",
                    vtype : "networkAddress"
                }]
            },{
                xtype : "label",
                cls : 'page-header-text',
                html : this._( "IP Addresses" )
            }, this.buildAliasGrid( settings, "static_aliases" ),{
                wanToggle : true,
                autoHeight : true,
                defaults : {
                    xtype : "textfield",
                    itemCls : 'label-width-2'
                },
                items : [{
                    fieldLabel : this._( "Default Gateway" ),
                    name : "static.default_gateway",
                    vtype : "ipAddress"
                },{
                    fieldLabel : this._( "Primary DNS Server" ),
                    name : "static.dns_1",
                    vtype : "ipAddress"
                },{
                    fieldLabel : this._( "Secondary DNS Server" ),
                    name : "static.dns_2",
                    vtype : "ipAddress",
                    allowBlank : true
                }]
            },{
                wanToggle : false,
                xtype : "label",
                cls : 'page-header-text',
                html : this._( "Nat Policies" )
            }, this.buildNatPolicyGrid( settings, "static_nat_policies" ), {
                autoHeight : true,
                defaults : {
                    xtype : "textfield",
                    itemCls : 'label-width-2'
                },
                items : [
                    this.currentMtu( settings, "static.mtu" ),
                    this.buildEthernetMediaCombo( settings )
                ]
            }];
    
        return new Ext.Panel({
            layout : 'form',
            autoHeight : true,
            defaults : {
                xtype : "fieldset"
            },
            hasWan : true,
            items : items
        });
    },

    dynamicPanel : function( settings )
    {
        d = settings["dhcp_status"];
        
        var items = [{
            fieldLabel : this._( "IP Address" ),
            name : "dynamic.ip",
            boxLabel : d["ip"],
            allowBlank : true,
            vtype : 'ipAddress'
        },{
            fieldLabel : this._( "Netmask" ),
            name : "dynamic.netmask",
            boxLabel : d["netmask"],
            allowBlank : true,
            vtype : 'ipAddress'
        },{
            wanToggle : true,
            fieldLabel : this._( "Default Gateway" ),
            name : "dynamic.default_gateway",
            boxLabel : d["default_gateway"],
            allowBlank : true,
            vtype : 'ipAddress'
        },{
            wanToggle : true,
            fieldLabel : this._( "Primary DNS Server" ),
            name : "dynamic.dns_1",
            boxLabel : d["dns_1"],
            allowBlank : true,
            vtype : 'ipAddress'
        },{
            wanToggle : true,
            fieldLabel : this._( "Secondary DNS Server" ),
            name : "dynamic.dns_2",
            boxLabel : d["dns_2"],
            allowBlank : true,
            vtype : 'ipAddress'
        }, this.currentMtu( settings, "dynamic.mtu" ), this.buildEthernetMediaCombo( settings ), {
            xtype : "button",
            text : this._( "Renew Lease" ),
            handler : this.onRenewLease,
            scope : this
        }];

        return new Ext.Panel({
            layout : 'form',
            hasWan : true,
            autoHeight : true,
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                autoHeight : true,
                defaults : {
                    xtype : "textfield",
                    itemCls : 'label-width-2'
                },
                items : items
            },{
                xtype : 'label',
                cls : 'label-section-heading',
                html : this._( "IP Address Aliases" )
            }, this.buildAliasGrid( settings, "dynamic_aliases" )]
                     
        });

    },

    bridgePanel : function( settings )
    {
        return new Ext.Panel({
            layout : 'form',
            hasWan : false,
            autoHeight : true,
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                autoHeight : true,
                defaults : {
                    xtype : "textfield",
                    itemCls : 'label-width-2'
                },
                items : [{
                    fieldLabel : this._( "Bridge To" ),
                    xtype : "combo",
                    name : "bridge.bridge_interface_id",
                    mode : "local",
                    triggerAction : "all",
                    editable : false,
                    width : 160,
                    listWidth : 150,
                    store :  settings["bridgeable_interfaces"]
                }, this.buildEthernetMediaCombo( settings )]
            }]
        });                
    },

    pppoePanel : function( settings )
    {
        items = [{
            fieldLabel : this._( "Username" ),
            name : "pppoe.username"
        },{
            inputType : "password",
            fieldLabel : this._( "Password" ),
            name : "pppoe.password"
        },{
            wanToggle : true,
            xtype : "checkbox",
            fieldLabel : "Use peer DNS",
            name : "pppoe.use_peer_dns"
        },{
            wanToggle : true,
            fieldLabel : this._( "Primary DNS Server" ),
            name : "pppoe.dns_1",
            allowBlank : true,
            vtype : 'ipAddress'
        },{
            wanToggle : true,
            fieldLabel : this._( "Secondary DNS Server" ),
            name : "pppoe.dns_2",
            allowBlank : true,
            vtype : 'ipAddress'
        }, this.buildEthernetMediaCombo( settings ),{
            xtype : "button",
            text : this._( "Renew Lease"),
            handler : this.onRenewLease,
            scope : this
        }];
        
        return new Ext.Panel({
            layout : 'form',
            hasWan : true,
            autoHeight : true,
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                autoHeight : true,
                defaults : {
                    xtype : "textfield",
                    itemCls : 'label-width-2'
                },
                items : items
            },{
                xtype : "label",
                cls : 'page-header-text',
                html : this._( "IP Addresses" )
            }, this.buildAliasGrid( settings, "pppoe_aliases" ), {
                autoHeight : true,
                defaults : {
                    xtype : "textfield",
                    itemCls : 'label-width-2'
                },
                items : [{
                    xtype : "textarea",
                    fieldLabel : this._( "Secret Field" ),
                    name : "pppoe.secret_field",
                    width : 397,
                    height : 140
                }]
            }]
        });
    },

    buildAliasGrid : function( settings, entriesField )
    {
        this.fixAliases( settings, entriesField );

        var aliases = new Ung.Alpaca.EditorGridPanel({
            recordFields : [ "network_string" ],
            selectable : true,
            settings : settings,
            name : entriesField,
            recordDefaults : {
                network_string : "1.2.3.4 / 24"
            },
            
            columns : [{
                header : this._( "Address and Netmask" ),
                width: 200,
                sortable: true,
                dataIndex : "network_string",
                editor : new Ext.form.TextField({
                    allowBlank : false,
                    vtype : 'networkAddress'
                })
            }]
        });
        
        aliases.store.load();

        return aliases;
    },

    buildNatPolicyGrid : function( settings, entriesField )
    {
        this.fixAliases( settings, entriesField );

        var aliases = new Ung.Alpaca.EditorGridPanel({
            recordFields : [ "network_string", "new_source" ],
            wanToggle : false,
            selectable : true,
            settings : settings,
            name : entriesField,
            recordDefaults : {
                network_string : "0.0.0.0 / 0",
                new_source : "auto"
            },
            
            columns : [{
                header : this._( "Address and Netmask" ),
                width: 200,
                sortable: true,
                dataIndex : "network_string",
                editor : new Ext.form.TextField({
                    allowBlank : false
                })
            },{
                header : this._( "Source Address" ),
                width: 100,
                sortable: true,
                dataIndex : "new_source",
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
            fieldLabel : this._( "Ethernet Media" ),
            name : "media",
            mode : "local",
            triggerAction : "all",
            editable : false,
            listWidth : 150,
            width : 160,
            itemCls : 'label-width-2',
            store :  settings["media_types"]
        });
    },
    
    onSelectConfigType : function( __, record, index )
    {
        var layout = this.switchBlade.layout;
        layout.setActiveItem( index );

        /* Hide the WAN checkbox if necessary. */
        var hasWan = layout.activeItem.hasWan;
        this.isWanCheckbox.setContainerVisible( hasWan );

        this.onCheckWan( this.isWanCheckox, hasWan && this.isWanCheckbox.getValue());
    },

    onCheckWan : function( component, isWanChecked )
    {
        Ext.each( this.find( "wanToggle", isWanChecked ), function( item ) { 
            Ung.Alpaca.Util.setIsVisible( item, true ) 
        });

        Ext.each( this.find( "wanToggle", !isWanChecked ), function( item ) {
            Ung.Alpaca.Util.setIsVisible( item, false );
        });
    },
    
    fixAliases : function( settings, name )
    {
        var aliases = settings[name];
        
        for ( var c = 0; c < aliases.length ; c++ ){
            var a = aliases[c];
            aliases[c].network_string = a["ip"] + " / " + a["netmask"];
        }
    },

    currentMtu : function( settings, field )
    {
        var mtu = settings["current_mtu"];
        
        if ( mtu == null ) {
            mtu = this._( "unknown" );
        }
        
        return {
            xtype : 'numberfield',
            width : 60,
            fieldLabel : this._( "MTU" ),
            boxLabel : String.format( this._( "(current : {0})" ), mtu ),
            itemCls : 'label-width-2',
            name : field
        };
    },

    /* Override update settings to properly serialize nat policies and aliases. */
    updateSettings : function( settings )
    {
        Ung.Alpaca.Pages.Interface.Config.superclass.updateSettings.apply( this, arguments );

        /* Append the primary address to the top of the static aliases. */
        pa = settings["static"]["primary_address"];
        if ( pa == null ) {
            pa = "";
        }

        pa = pa.trim();
        if ( pa.length > 0 ) {
            settings["static_aliases"].splice( 0, 0, { 
                network_string : settings["static"]["primary_address"] 
            });
        }

        delete( settings["static"]["primary_address"]  );
        this.updateNetworks( settings, "static_aliases" );
        this.updateNetworks( settings, "static_nat_policies" );
        this.updateNetworks( settings, "dynamic_aliases" );
        this.updateNetworks( settings, "pppoe_aliases" );

        settings["media"] = this.switchBlade.layout.activeItem.find( "name", "media" )[0].getValue()
    },

    updateNetworks : function( settings, entryName )
    {
        var aliases = settings[entryName];

        if ( aliases == null ) {
            return;
        }

        for ( var c = 0; c < aliases.length ; c++ ){
            var a = aliases[c];
            var network_string = a["network_string"];
            if ( network_string == null ) {
                network_string = "";
            }
            network_string = network_string.split( / *\/ */ )
            a["ip"] = network_string[0];
            a["netmask"] = "32";
            if ( network_string.length > 1 ) {
                a["netmask"] = network_string[1];
            }
        }

    },

    onRenewLease : function()
    {
        /* Refresh just saves settings, does not warn the user though, because that looks bad */
        this.confirmMessage = null;
        
        /* Update all of the save messages so it looks normal. */
        this.saveConfig = {
            waitTitle : this._( "Please Wait" ),
            waitMessage : this._( "Renewing Lease" ),
            successTitle : this._( "Lease Updated" ),
            successMessage : this._( "Attempt to update lease has been completed." ),
            errorTitle : this._( "Internal Error" ),
            errorMessage : this._( "Unable to renew lease" )
        };

        /* Don't go to the interface list when renewing the lease */
        this.nextPage = null;

        application.onSave();
    },

    /* This is the page that it should return to on cancel or after saving settings. */
    nextPage : "/alpaca/interface/list"
});

Ung.Alpaca.Pages.Interface.Config.settingsMethod = "/interface/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "interface", "config", Ung.Alpaca.Pages.Interface.Config );

