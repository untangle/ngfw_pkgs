Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

/**
 * @class Ung.Alpaca.PagePanel
 * @extends Ext.Panel
 * A PagePanel is the base for rendering a page on the alpaca.
 * 
 */
Ung.Alpaca.PagePanel = Ext.extend( Ext.Panel, {
    border : false,

    layout : "form",

    autoScroll : true,

    constructor : function( config ) {
        this.settings = config.settings;
        Ung.Alpaca.PagePanel.superclass.constructor.apply( this, arguments );
    },
    
    // Populate the fields with the 
    // values from the settings objects.  This uses the name
    // to automatically determine which values belong in the fields.
    populateForm : function()
    {
        /* Iterate the panel and line up fields with their values. */
        this.items.each( this.populateFieldValue.createDelegate( this, [ this.settings ], true ));
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
    },

    updateSettings : function( settings )
    {
        /* Iterate the panel and line up fields with their values. */
        this.items.each( this.updateFieldValue.createDelegate( this, [ settings ], true ));
    },
    
    /* Update the settings with the values from the fields. */
    updateFieldValue : function( item, index, length, settings )
    {
        if ( item.getName ) {
            var value = null;

            switch ( item.xtype ) {
            case "textfield":
            case "checkbox":
            case "combo":
                value = item.getValue();
                break;                
            }
            
            if ( value != null ) {
                this.setSettingsValue( settings, item.getName(), value );
            }
        }

        /* Recurse to children */
        if ( item.items ) {
            item.items.each( this.updateFieldValue.createDelegate( this, [ settings ], true ));
        }
    },

    setSettingsValue : function( settings, name, value )
    {
        if ( /^[a-zA-Z_][-a-zA-Z0-9_\.]+$/( name ) == null ) {
            return null;
        }

        var path = name.split( "." );
        
        var end = path.length - 1;

        var c = 0;
        var hash = settings;
        
        for ( c = 0 ; c < end ; c++ ) {
            hash = hash[path[c]];
            if ( value == null ) {
                return;
            }
        }

        hash[path[c]] = value;
    }
});
