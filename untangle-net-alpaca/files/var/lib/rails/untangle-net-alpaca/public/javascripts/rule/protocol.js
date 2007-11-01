var ProtocolHandler =
{
    /* Function to generate the content */
    content : function( rowId )
    {
        var newContent = new Array();

        for ( var c = 0 ; ( c < 2 ) && ( c < this.protocolList.length ) ; c++ ) {
            newContent.push( this.checkbox( rowId, this.protocolList[c][0], this.protocolList[c][1] ));
        }
        return newContent.join( "\n" );
    },

    /* Put any more than the first two interfaces on their own line */
    extensions : function( rowId )
    {
        var a = new Array();
        var newContent = null;
        for ( var c = 2 ; c < this.protocolList.length ; c++ ) {
            if (( c % 3 ) == 2 ) {
                if ( newContent != null ) a.push( newContent.join( "\n" ));
                newContent = new Array();
            }
            newContent.push( this.checkbox( rowId, this.protocolList[c][0], this.protocolList[c][1] ));
        }

        if (( newContent != null ) && ( newContent.length > 0 )) a.push( newContent.join( "\n" ));
        return a;
    },

    /* Validation function */
    validate : function( rowId )
    {
        
    },

    /* Function to build a single checkbox */
    checkbox : function( rowId, identifier, name ) {
        var line = "<input id='" + this.checkboxId( rowId, identifier )
        + "' type='checkbox' name='protocol' value='" + identifier + "'/>";

        /* Wrap it in a div */
        return "<div class='checkbox'>" + line + name + "</div>";
    },

    /* This is getting hairy */
    setValue : function( rowId, value )
    {
        var element = document.getElementById( rowId );
        if ( element == null ) return;

        value = value;

        /* Clear all of the checkboxes */
        var checkboxes = element.getElementsByTagName( "input" );

        for ( var c = 0 ; c < checkboxes.length ; c++ ) {
            if ( checkboxes[c].type == "checkbox" ) {
                checkboxes[c].checked = ( value[checkboxes[c].value] == true );
            }
        }

        /* The extensions are a mess */
    },

    checkboxId : function( rowId, identifier )
    {
        return identifier + "[]";
    }
}

RuleBuilder.registerType( "protocol", ProtocolHandler );

