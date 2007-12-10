var RedirectManager = 
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

    editFilter : function()
    {
        return "/redirect/edit";
    },
    
    fields : new Array( "filters", "description", "new_ip", "new_enc_id", "enabled" )
}

RuleBuilder.manager = RedirectManager;
