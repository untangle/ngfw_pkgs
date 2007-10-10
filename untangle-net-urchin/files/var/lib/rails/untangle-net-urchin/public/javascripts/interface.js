function removeListItem( id )
{
    var element = document.getElementById( id );
    
    /* Ignore anything that doesn't exists */
    if ( element == null ) return;

    /* Ignore anything that is not a list item */
    if ( element.nodeName != "LI" && element.nodeName != "li" ) return;
    
    try {
        Element.remove( id );
    } catch ( e ) {
        /* ignoring the error */
    }
}
