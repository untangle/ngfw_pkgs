var TableManager = 
{
    styledTable : {},

    remove : function( tableId, rowId )
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

        this.updateRowStyles( tableId );
    },
    
    updateRowStyles : function( tableId )
    {
        var table = document.getElementById( tableId );

        /* Ignore anything that doesn't exist */
        if ( table == null ) return;

        /* Ignore anything that is not an unsorted list. */
        if ( table.nodeName != "UL" && table.nodeName != "ul" ) return;

        var children = table.childNodes;

        var isFirst = true;
        var isOdd = true;

        for ( var c = 0 ; c < children.length ; c++ ) {
            if ( children[c].nodeName != "LI" && children[c].nodeName != "li" ) continue;
            
            var child = children[c];

            if ( isFirst ) {
                Element.addClassName( child, "first" );
            } else {
                Element.removeClassName( child, "first" );
            }
            
            if ( isOdd ) {
                Element.addClassName( child, "odd" );
                Element.removeClassName( child, "even" );
            } else {
                Element.addClassName( child, "even" );
                Element.removeClassName( child, "odd" );
            }

            isFirst = false;
            isOdd = !isOdd;
        }
    }
};
