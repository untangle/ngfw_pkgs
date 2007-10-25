var RuleBuilder = {
    handlers : new Array(),

    /* Update the current type of a rule */
    changeType : function( rowId )
    {
        var row  = document.getElementById( rowId );
        
        /* need some error handling */
        if ( row == null ) return;
        
        /* Retrieve the first select */
        var type  = row.getElementsByTagName( "select" );

        if (( type == null ) || ( type.length == 0 )) return;

        /* Get the first elements value */
        type = type[0].value;

        /* Try to get the element */
        value = row.getElementsByTagName( "div" );

        if (( value == null ) || ( value.length == 0 )) return;
        
        var found = false;
        
        /* Iterate, looking for the first item with the class value. */
        for ( var c = 0 ; c < value.length ; c++ ) {
            if ( !this.hasClass( value[c], "value" )) continue;
            
            found = true;
            value = value[c];
            break;
        }

        if ( !found ) return;
        
        var handler = this.handlers[type];

        /* Unable to update if the handler is not known */
        if ( handler == null ) return;

        /* Remove any extensions that have been added */
        this.deleteExtensions( rowId );

        /* Replace the item at that position */
        Element.update( value, handler.content());

        /* Insert any of the extensions */
        if (( typeof handler.extensions ) == "function" ) {
            /* Insert them backways, this way they are ordered properly */
            var extensions = handler.extensions().toArray();
            
            var newExtensions = new Array();
            for ( var c = 0 ; c < extensions.length  ; c++ ) {
                var extension = extensions[c];
                extension = "<div class='first-column'>" + extension + "</div>";
                extension = "<li class='extension'>" + extension + "</li>";
                newExtensions.push( extension );
            }

            if ( newExtensions.length > 0 ) new Insertion.After( row, newExtensions.join( "\n" ));
        }
    },
    
    removeClass : function( element, className )
    {
        var classArray = element.className.split( " " );
        for ( var c = 0 ; c < classArray.length ; c++ ) {
            /* Skip the class that is to be removed */
            if ( classArray[c] == className ) continue;
            element.className = element.className + classArray[c];
        }
    },
    
    addClass : function( element, className )
    {
        /* No need to add it if it is already there */
        if ( this.hasClass( element, className )) return;

        element.className = ( element.className + " " + className ).strip();
    },

    /* Return true iff element has className as one if its CSS classes */
    hasClass : function( element, className )
    {
        /* use an iterator because otherwise could overmatch with a
         * simple string search.  eg value would also match
         * "value-special random-css-class", could use a regex? */
        var classArray = element.className.split( " " );
        for ( var c = 0 ; c < classArray.length ; c++ ) {
            if ( classArray[c] != className ) continue;
            return true;
        }

        return false;
    },

    /* Remove a parameter from the list, this will not let you remove the last one */
    removeParameter : function( rowId )
    {
        
    },
    
    registerType : function( name, handler )
    {
        /* Set the handler for this name */
        this.handlers[name] = handler;
    },

    /* Delete a parameter, this will not let you delete the last parameter. */

    /* Delete all of the extensions of a row */
    deleteExtensions : function( rowId )
    {
        var list = document.getElementById( "rule-builder" );
        if ( list == null ) return;
        
        /* True once it has found the row */
        var found = false;
        
        /* Get the children of the list */
        var children = list.childNodes;

        for ( var c = 0 ; c < children.length ; c++ ) {
            if ( children[c].nodeName != "LI" && children[c].nodeName != "li" ) continue;
                        
            if ( children[c].id == rowId ) {
                /* Something has gone wrong, if it has already found an element */
                if ( found == true ) break;

                found = true;
                continue;
            }

            /* break out once you find the first non-extension after finding the row */
            if ( !this.hasClass( children[c], "extension" ) && found ) break;

            /* Delete this item */
            if ( found == true ) Element.remove( children[c] );
        }
    }
}
