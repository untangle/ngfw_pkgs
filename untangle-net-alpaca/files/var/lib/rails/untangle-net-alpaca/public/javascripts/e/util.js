Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

Ung.Alpaca.Util = {
    stopLoadingObject  : {},

    loadScript : function( queryPath, handler, failure )
    {
        var src = this.getQueryPathScript( queryPath );

        /* Now build the query */
        return Ext.Ajax.request({
            url : src,
            success : this.loadScriptSuccess.createDelegate( this, [ handler ], true ),
            failure : this.loadScriptFailure.createDelegate( this, [ failure ], true )
        });
    },

    loadScriptSuccess : function( response, options, handler )
    {
        var error = null;

        try {
            if( window.execScript) {
                window.execScript(response.responseText);
            } else {
                window.eval(response.responseText);
            }
        } catch ( e ) {
            if ( e != this.stopLoadingObject ) {
                throw e;
            }
        }
        
        handler( response, options );
    },

    loadScriptFailure : function( response, options, handler )
    {
        if ( handler != null ) {
            return handler( response, options );
        }

        throw "Unable to load script";
    },

    /**
     * @param path : The path to the request.
     * @param handler : Callback to call on success.
     * @param failure : Callback to call on failure.
     * @param *args : All arguments after this will be converted to an array and passed into
     *                the request as JSON.
     */
    executeRemoteFunction : function( path, handler, failure )
    {
        var args = [];
        var argumentCount = arguments.length;
        for ( var c = 3 ; c < argumentCount ; c++ ) {
            args[c-3] = arguments[c];
        }

        path = "/alpaca" + path;

        /* Now build the query */
        return Ext.Ajax.request({
            url : path,
            success : this.remoteFunctionSuccess.createDelegate( this, [ handler, failure ], true ),
            failure : this.remoteFunctionFailure.createDelegate( this, [ failure ], true ),
            jsonData : args
        });
    },
    
    remoteFunctionSuccess : function( response, options, handler, failure )
    {
        var json = Ext.util.JSON.decode( response.responseText );

        /* Append this in case another handler wants to reuse some other part of the JSON data. */
        response.jsonData = json;
        if ( json["status"] != "success" ) {
            return this.remoteFunctionFailure( response, options, failure );
        }
        
        handler( json["result"], response, options );
    },
    
    remoteFunctionFailure : function( response, options, handler )
    {
        if ( handler ) {
            return handler( response, options );
        }
        
        this.handleConnectionError( response, options );
    },

    handleConnectionError : function( response, options )
    {
        throw "Unable to connect";
    },

    stopLoading : function()
    {
        throw this.stopLoadingObject;
    },

    getQueryPathScript : function( queryPath )
    {
        return "/alpaca/javascripts/pages/" + queryPath["controller"] + "/" + queryPath["page"] + ".js";
    },

    /* Only update config if a value doesn't exist, extjs already has this
     * in ApplyIf. */
    updateDefaults : function( config, defaults )
    {
        for ( key in defaults ) {
            if ( config[key] == null ) {
                var value = defaults[key];
                if (( typeof value ) == "function" ) {
                    config[key] = defaults[key]();
                } else {
                    config[key] = defaults[key];
                }
            }
        }
    },
    
    implementMe : function( feature )
    {
        Ext.MessageBox.show({
            title : 'Implement Me',
            msg : feature,
            buttons : Ext.MessageBox.OK,
            icon : Ext.MessageBox.INFO
        });
    },
    hasData : function(obj) {
        var hasData = false;
        for (id in obj) {
            hasData = true;
            break;
        }
        return hasData;
    },
    
    // Add the additional 'advanced' VTypes
    initExtVTypes: function(i18n){
    	
        Ext.apply(Ext.form.VTypes, {
            ipAddress: function(val, field) {
                var ipAddrMaskRe = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
                return ipAddrMaskRe.test(val);
            },
            ipAddressText: i18n._('Invalid IP Address.'),
            
            // #{ip_address} [/#{netmask}]
            networkAddress: function(val, field) {
                var tokens = val.split('/');
                if (tokens.length < 1 && tokens.length > 2) {
            	    return false;
                }
                // validate ip_address
                if (!this.ipAddress(tokens[0], field)) {
                    return false;
                }
                //validate netmask
                if (tokens.length == 2) {
            	    var netmask = tokens[1];
            	    if (netmask.indexOf(".") < 0 ) {
            		// short format
            		var netmaskNum = parseInt(netmask);
            		return (!isNaN(netmaskNum) && netmaskNum >=0 && netmaskNum <= 32);
            	    } else {
            		// long format
            		var netmaskTokens = netmask.split('.');
            		if (netmaskTokens.length != 4) {
            		    return false;
            		} else {
            		    var validNetmaskTokens = new Array(0, 128, 192, 224, 240, 248, 252, 254, 255)
            		    for (var i=0, subnetSection = true; i<4; i++) {
            			if (subnetSection) {
                                    if (netmaskTokens[i] != 255 ) {
                                	subnetSection = false;
                                    }
                                    var isCurrentTokenValid = false;
            			    for ( var j=0; j< validNetmaskTokens.length; j++) {
            				if (netmaskTokens[i] == validNetmaskTokens[j]) {
            				    isCurrentTokenValid = true;
            				    break;
            				}
            			    }
            			    if (!isCurrentTokenValid) {
            				return false;
            			    }
            			} else {
            			    if (netmaskTokens[i] != 0) {
            				return false;
            			    }
            			}
            		    }
            		}
            	    }
                }
                return true;
            },
            networkAddressText: i18n._('Invalid Network Address.'),
            
            //From rfc1034 the PREFERRED name syntax:
            //<domain> ::= <subdomain> | " "
            //<subdomain> ::= <label> | <subdomain> "." <label>
            //<label> ::= <letter> [ [ <ldh-str> ] <let-dig> ]
            //<ldh-str> ::= <let-dig-hyp> | <let-dig-hyp> <ldh-str>
            //<let-dig-hyp> ::= <let-dig> | "-"
            //<let-dig> ::= <letter> | <digit>
            //<letter> ::= any one of the 52 alphabetic characters A through Z in
            //upper case and a through z in lower case
            //<digit> ::= any one of the ten digits 0 through 9
            hostname: function(val, field) {
                var hostnameMaskRe = /^(((([a-zA-Z](([a-zA-Z0-9\-]+)?[a-zA-Z0-9])?)+\.)*([a-zA-Z](([a-zA-Z0-9\-]+)?[a-zA-Z0-9])?)+)|\s)$/;
                return hostnameMaskRe.test(val);
            },
            hostnameText: i18n._('Invalid Hostname.'),
            
            //A list of hostnames separated by spaces. 
            hostnameList : function (val, field) {
          	var hostnames = val.split(/\s+/)
          	for (var i=0; i < hostnames.length; i++) {
          	    if (!this.hostname(hostnames[i], field)) {
          		return false;
          	    }
          	}
          	return true;
            },
            hostnameListText: i18n._('Invalid Hostname List.'),
            
            domainNameSuffix: function(val, field) {
          	return this.hostname(val, field)
            },
            domainNameSuffixText: i18n._('Invalid Domain Name Suffix.'),
            
            domainNameList: function(val, field) {
                var domains = val.split(/[\s,]+/)
                for (var i=0; i < domains.length; i++) {
                    if (!this.domainNameSuffix(domains[i], field)) {
                        return false;
                    }
                }
                return true;
            },
            domainNameListText: i18n._('Invalid Domain Name List.'),
            
            //MAC address in 00:00:00:00:00:00 or the 00-00-00-00-00-00 notation
            macAddress: function(val, field) {
                var macAddressMaskRe = /^([0-9a-f]{2}([:-]|$)){6}$/i;
                return macAddressMaskRe.test(val);
            },
            macAddressText: i18n._('Invalid MAC Address.'),
            
            port: function(val, field) {
                var minValue = 1;
                var maxValue = 65535;
                return minValue <= val && val <= maxValue;
            },
            portText: String.format(i18n._("The port must be an integer number between {0} and {1}."), 1, 65535),
            
            password: function(val, field) {
                if (field.initialPassField) {
                    var pwd = Ext.getCmp(field.initialPassField);
                    return (val == pwd.getValue());
                }
                return true;
            },
            passwordText: i18n._('Passwords do not match')
        });
    },

    tip : new Ext.Tip({
        cls : 'warning-messages',
        layout : 'form',
        closable : true
    }),

    /* Here because there are two places that need this. */
    refreshInterfaces : function( buttonId, input, callback )
    {
        Ext.MessageBox.wait( this._( "Refreshing Physical Interfaces", "Please wait" ));
        
        var handler = this.completeRefreshInterfaces.createDelegate( this, [ callback ], true );
        Ung.Alpaca.Util.executeRemoteFunction( "/interface/get_interface_list", handler );
    },

    completeRefreshInterfaces : function( result, response, options, callback )
    {
        var icon = Ext.MessageBox.INFO;
        var buttons = Ext.MessageBox.OK;

        var message = this._( "No new physical interfaces were detected." );
        var handler = null;

        var newInterfaces = result["new_interfaces"];
        var deletedInterfaces = result["deleted_interfaces"];
        
        if ( newInterfaces == null ) {
            newInterfaces = [] 
        }

        if ( deletedInterfaces == null ) {
            deletedInterfaces = [] 
        }
        
        if (( deletedInterfaces.length + newInterfaces.length ) > 0 ) {
            icon = Ext.MessageBox.INFO;
            message = [];
            var m = "";
            var l = deletedInterfaces.length;
            if ( l > 0 ) {
                m = this.i18n.pluralise( this._( "One interface was removed." ),
                                         this._( "{0} interfaces were removed." ),
                                         l );
                message.push( String.format( m, l ));
            }
            
            l = newInterfaces.length;
            if ( l > 0 ) {
                m = this.i18n.pluralise( this._( "One interface was added." ),
                                         this._( "{0} interfaces were added." ),
                                         l );
                message.push( String.format( m, l ));
            }

            message.push( this._( "Click 'Continue' to configure changes to your interfaces." ));
            message.push( this._( "Click 'Cancel' to ignore the changes." ));
            
            message = message.join( "<br/>" );

            buttons = {
                ok : this._( "Continue" ),
                cancel : this._( "Cancel" )
            };

            handler = this.configureInterfaceChanges;
        }
        
        Ext.MessageBox.show({
            title : this._( "Interface Status" ),
            msg : message,
            buttons : buttons,
            icon : icon,
            fn : handler,
            scope : this
        });
        
        if ( callback ) {
            callback( result );
        }
    },

    configureInterfaceChanges : function( buttonId )
    {
        if ( buttonId == "ok" ) {
            application.switchToQueryPath( "/alpaca/interface/refresh" );
        }
    },
    
    cidrData : [
        [ "8",  "8   : 255.0.0.0"],
        [ "9",  "9   : 255.128.0.0"],
        [ "10", "10  : 255.192.0.0"],
        [ "11", "11  : 255.224.0.0"],
        [ "12", "12  : 255.240.0.0"],
        [ "13", "13  : 255.248.0.0"],
        [ "14", "14  : 255.252.0.0"],
        [ "15", "15  : 255.254.0.0"],
        [ "16", "16  : 255.255.0.0"],
        [ "17", "17  : 255.255.128.0"],
        [ "18", "18  : 255.255.192.0"],
        [ "19", "19  : 255.255.224.0"],
        [ "20", "20  : 255.255.240.0"],
        [ "21", "21  : 255.255.248.0"],
        [ "22", "22  : 255.255.252.0"],
        [ "23", "23  : 255.255.254.0"],
        [ "24", "24  : 255.255.255.0"],
        [ "25", "25  : 255.255.255.128"],
        [ "26", "26  : 255.255.255.192"],
        [ "27", "27  : 255.255.255.224"],
        [ "28", "28  : 255.255.255.240"],
        [ "29", "29  : 255.255.255.248"],
        [ "30", "30  : 255.255.255.252"],
        [ "31", "31  : 255.255.255.254"],
        [ "32", "32  : 255.255.255.255" ]
    ]
};

Ung.Alpaca.TextField = Ext.extend( Ext.form.TextField, {
    onRender : function(ct, position)
    {
        Ung.Alpaca.TextField.superclass.onRender.call(this, ct, position);
        
        var parent = this.el.parent()
        
        if( this.boxLabel ) {
            this.labelEl = parent.createChild({
                tag: 'label',
                htmlFor: this.el.id,
                cls: 'x-form-textfield-detail',
                html: this.boxLabel
            });
        }
    }
});

/* override the default text field so that all of the text fields can add a box label */
Ext.reg('textfield', Ung.Alpaca.TextField);

Ung.Alpaca.ComboBox = Ext.extend( Ext.form.ComboBox, {
    onRender : function(ct, position)
    {
        Ung.Alpaca.ComboBox.superclass.onRender.call(this, ct, position);

        if( this.boxLabel ) {
            this.labelEl = this.wrap.createChild({
                tag: 'label',
                htmlFor: this.el.id,
                cls : 'x-form-combo-detail',
                html : this.boxLabel
            });
        }
    }
});

/* override the default Combo box so that all of the comboboxes can add a box label */
Ext.reg('combo',  Ung.Alpaca.ComboBox);

