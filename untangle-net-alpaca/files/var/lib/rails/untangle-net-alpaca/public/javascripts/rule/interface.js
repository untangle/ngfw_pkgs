var InterfaceHandler =
{
    /* Function to generate the content */
    content : function() {
        
        var newContent = new Array();
        for ( var c = 0 ; ( c < 2 ) && ( c < this.interfaceList.length ) ; c++ ) {
            newContent.push( this.checkbox( this.interfaceList[c][0], this.interfaceList[c][1] ));
        }
        return newContent.join( "\n" );
    },

    /* Put any more than the first two interfaces on their own line */
    extensions : function() {
        var a = new Array();
        var newContent = null;
        for ( var c = 2 ; c < this.interfaceList.length ; c++ ) {
            if (( c % 3 ) == 2 ) {
                if ( newContent != null ) a.push( newContent.join( "\n" ));
                newContent = new Array();
            }
            newContent.push( this.checkbox( this.interfaceList[c][0], this.interfaceList[c][1] ));
        }

        if (( newContent != null ) && ( newContent.length > 0 )) a.push( newContent.join( "\n" ));
        return a;
    },

    /* Validation function */
    validate : function( rowId ) {
        
    },

    /* Function to build a single checkbox */
    checkbox : function( identifier, name ) {
        var line = "<input type='checkbox' name='interface' value='" + identifier + "'/> " + name;
        /* Wrap it in a div */
        return "<div class='checkbox'>" + line + "</div>";
    }
}

RuleBuilder.registerType( "d-intf", InterfaceHandler );
RuleBuilder.registerType( "s-intf", InterfaceHandler );

