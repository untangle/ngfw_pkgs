var TimeHandler =
{
    content : function( rowId ) {
        return "<div>" + this.time( "start" ) + " to " + this.time( "end" ) + "</div>";
    },

    validate : function( rowId ) {
        
    },

    /* value must be in the format hh,mm,hh,mm
     * this may look odd, but it is really easy to parse.
     * hh is 24 hour time.
     * mm is a 0,15,30,45.
     */
    setValue : function( rowId, value )
    {
        var element = document.getElementById( rowId );
        if ( element == null ) return;
        
        /* Clear all of the checkboxes */
        var inputs = element.getElementsByTagName( "select" );
        
        var timeArray = value.split( "," );
        if ( timeArray.length != 4 ) return;
        
        for ( var c = 0 ; c < inputs.length ; c++ ) {
            switch ( inputs[c].id ) {
            case "start-time-hour": inputs[c].value = timeArray[0]; break;
            case "start-time-minute": inputs[c].value = timeArray[1]; break;
            case "end-time-hour": inputs[c].value = timeArray[2]; break;
            case "end-time-minute": inputs[c].value = timeArray[3]; break;
            }
        }
    },

    parseValue : function( rowId ) {
        var element = document.getElementById( rowId );
        if ( element == null ) return;
        
        /* Clear all of the checkboxes */
        var inputs = element.getElementsByTagName( "select" );
        
        var timeArray = new Array( 0, 0, 0, 0 );
        
        for ( var c = 0 ; c < inputs.length ; c++ ) {
            switch ( inputs[c].id ) {
            case "start-time-hour": timeArray[0] = inputs[c].value; break;
            case "start-time-minute": timeArray[1] = inputs[c].value; break;
            case "end-time-hour": timeArray[2] = inputs[c].value; break;
            case "end-time-minute": timeArray[3] = inputs[c].value; break;
            }
        }
        
        return timeArray.join( "," );
    },

    time : function( prefix ) {
        var s = "<select id='" + prefix + "-time-hour'>";
        for ( var c = 0 ; c <= 23 ; c++ ) {
            s += "<option value='" + c + "'>" + c + "</option>";
        }
        s += "</select> :";
        
        s += "<select id='" + prefix + "-time-minute'>";
        for ( var c = 0 ; c < 4 ; c++ ) {
            s += "<option value='" + ( c * 15 ) + "'>" + ( c * 15 ) + "</option>";
        }

        s += "</select>";

        return s;
    }
}

RuleBuilder.registerType( "time", TimeHandler );

