Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

Ung.Alpaca.PagePanel = Ext.extend( Ext.Panel, {
    border : false,

    layout : "form",
    
    loadSettings : function()
    {
        /* First check to see if settings method is defined. */
        if ( this.settingsMethod != null ) {
            Ung.Alpaca.Util.executeRemoteFunction( this.settingsMethod, 
                                                   this.completeLoadSettings.createDelegate( this ));
        } else {
            this.completeLoadSettings( [] );
        }
    },

    completeLoadSettings : function( settings, response, options )
    {
        this.populateForm( settings );
    },

    populateForm : function( settings )
    {
        /* Iterate the panel and line up fields with their values. */
        this.items.each( this.populateFieldValue.createDelegate( this, [ settings ], true ));
        
    },
    
    /* Fill in the value for a field */
    populateFieldValue : function( item, index, length, settings )
    {
        if ( item.getName ) {
            var value = this.getSettingsValue( settings, item.getName());

            if ( value == null ) {
                value = item.defaultValue;
            }

            switch ( item.xtype ) {
            case "textfield":
                value = ( value == null ) ? "" : value;
                item.setValue( value );
                break;
                
            case "checkbox":
                value =  ( value == null ) ? "" : value;
                item.setValue( value );
                break;

            case "combo":
                if ( value != null ) {
                    item.setValue( value );
                }
                break;                
            }
        }

        /* Recurse to children */
        if ( item.items ) {
            item.items.each( this.populateFieldValue.createDelegate( this, [ settings ], true ));
        }
    },

    /**
     * All of the fields should have a name like "<key1>.<key2>.<key3>"
     * this way if the settings = { "key1" : { "key2" : { "key3" : "value" }}} 
     * it is easy to compute the field value is settings["key1"]["key2"]["key3"]
     */
    getSettingsValue : function( settings, name )
    {
        if ( /^[a-zA-Z_][-a-zA-Z0-9_\.]+$/( name ) == null ) {
            return null;
        }

        var path = name.split( "." );
        
        var value = settings;
        
        for ( var c = 0 ; c < path.length ; c++ ) {
            value = value[path[c]];
            if ( value == null ) {
                return null;
            }
        }

        return value;
    }
});
