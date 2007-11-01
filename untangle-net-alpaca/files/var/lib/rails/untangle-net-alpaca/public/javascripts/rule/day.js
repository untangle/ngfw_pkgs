var DayHandler =
{
    /* Function to generate the content */
    content : function( rowId ) {
        var newContent = new Array();

        for ( var c = 0 ; ( c < 2 ) && ( c < this.dayList.length ) ; c++ ) {
            newContent.push( this.checkbox( this.dayList[c][0], this.dayList[c][1] ));
        }
        return newContent.join( "\n" );
    },

    /* Put any more than the first two interfaces on their own line */
    extensions : function( rowId ) {
        var a = new Array();
        var newContent = null;
        for ( var c = 2 ; c < this.dayList.length ; c++ ) {
            if (( c % 3 ) == 2 ) {
                if ( newContent != null ) a.push( newContent.join( "\n" ));
                newContent = new Array();
            }
            newContent.push( this.checkbox( this.dayList[c][0], this.dayList[c][1] ));
        }

        if (( newContent != null ) && ( newContent.length > 0 )) a.push( newContent.join( "\n" ));
        return a;
    },

    /* Validation function */
    validate : function( rowId ) {
        
    },

    /* Function to build a single checkbox */
    checkbox : function( identifier, name ) {
        var line = "<input type='checkbox' name='day-of-week' value='" + identifier + "'/> " + name;
        /* Wrap it in a div */
        return "<div class='checkbox'>" + line + "</div>";
    }
}

RuleBuilder.registerType( "day-of-week", DayHandler );

