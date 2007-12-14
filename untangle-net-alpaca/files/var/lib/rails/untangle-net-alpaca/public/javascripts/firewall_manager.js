var FirewallManager = 
{
    removeListItem : function( rowId )
    {
        var element = document.getElementById( rowId );
        
        /* Ignore anything that doesn't exists */
        if ( element == null ) return;
        
        /* Ignore anything that is not a list item */
        if ( element.nodeName != "LI" && element.nodeName != "li" ) return;
                
        try {
            Element.remove( rowId );
        } catch ( e ) {
            /* ignoring the error */
        }
    },

    getAction : function( value )
    {
        
    },
    
    fields : new Array( "filters", "description", "target", "enabled" )
}

RuleBuilder.manager = FirewallManager;
