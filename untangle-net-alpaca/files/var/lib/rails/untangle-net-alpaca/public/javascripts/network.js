var Network =
{
    setConfigType : function ( id ) 
    {
        var configType = document.getElementById( "config_type_" + id );

        /* Retrieve the value of the drop down */
        configType = configType.value;
        
        var element = document.getElementById( id + "_" + configType );
        
        /* Ignore anything that doesn't exists */
        if ( element == null ) return;

        /* Ignore anything that is not a DIV */
        if ( element.nodeName != "DIV" && element.nodeName != "div" ) return;

        var container = document.getElementById( id );
        
        /* Ignore anything that is not a DIV */
        if ( container == null ) return;
        
        var children = container.childNodes;
        var len = children.length;
        
        for ( var i = 0 ; i < len ; i++ ) {
            /* Ignore anything that is not a list item */
            if ( children[i].nodeName != "DIV" && children[i].nodeName != "div" ) continue;
            
            if ( children[i] == element  ) {
                Element.show( children[i] );
            } else {
                Element.hide( children[i] );
            }
        }
    },

    removeListItem : function ( id )
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
};
