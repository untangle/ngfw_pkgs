var TimeHandler =
{
    content : function( rowId ) {
        return "<div>" + this.time( "start" ) + " to " + this.time( "end" ) + "</div>";
    },

    validate : function( rowId ) {
        
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

