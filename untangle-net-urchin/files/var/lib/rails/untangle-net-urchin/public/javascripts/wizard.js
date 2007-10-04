/* Go to the previous page, if possible */
function prevPage()
{
    /* Decrement the value by one */
    changeCurrent( parseInt( document.forms.nav.current.value ) - 1);
}

/* Go to the next page, if possible. */
function nextPage()
{
    /* Increment the value by one */
    changeCurrent( parseInt( document.forms.nav.current.value ) + 1);
}

function changeCurrent( current )
{
    var list = document.getElementById("step-list");
    
    var children = list.childNodes;
    var len = children.length;

    var className = "completed";

    /* All of the list ids are prefixed by sl- */
    var listId = "sl-" + current;

    /* Should this print a message ? */
    if ( current < 0 ) {
        current = 0;
    } else if ( current >= len ) {
        current = len - 1;
    }


    var j = 0;
    for( var i = 0 ; i < len; i++ ) {
        /* Ignore anything that is not a list item */
        if ( children[i].nodeName != "LI" && children[i].nodeName != "li" ) continue;
        
        var panelId = children[i].id.replace( /^sl-/, "" );

        if ( j == current ) {
            children[i].className = "current";
            className = "incomplete";
            try {
                Element.show( panelId );
            } catch ( e ) { }
        } else {
            children[i].className = className;
            try {
                Element.hide( panelId );
            } catch ( e ) { }
        }

        /* This is hte index of the actual list items */
        j++;
    }

    /* Update the value of the current item */
    document.forms.nav.current.value = current;
}
