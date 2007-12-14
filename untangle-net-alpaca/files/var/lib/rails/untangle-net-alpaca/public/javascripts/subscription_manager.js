var SubscriptionManager = 
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
    
    fields : new Array( "filters", "description", "subscribe", "enabled" )
}

RuleBuilder.manager = SubscriptionManager;
