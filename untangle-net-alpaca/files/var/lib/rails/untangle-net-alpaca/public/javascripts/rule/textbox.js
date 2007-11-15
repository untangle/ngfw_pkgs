function Textbox()
{
    /* Function to generate the content */
    this.content = function( rowId )
    {
        return '<input id="ruleValue[]" name="ruleValue[]" type="text"/>';
    };

    this.validate = function( rowId )
    {
        
    };

    this.setValue = function( rowId, value )
    {
        var element = document.getElementById( rowId );
        if ( element == null ) return;
        
        /* Clear all of the checkboxes */
        var inputs = element.getElementsByTagName( "input" );
        
        for ( var c = 0 ; c < inputs.length ; c++ ) {
            if ( inputs[c].type == "text" ) {
                inputs[c].value = value;
                break;
            }
        }
    };

    this.parseValue = function( rowId ) {
        var element = document.getElementById( rowId );
        if ( element == null ) return "";
        
        /* Clear all of the checkboxes */
        var inputs = element.getElementsByTagName( "input" );

        for ( var c = 0 ; c < inputs.length ; c++ ) {
            if ( inputs[c].type == "text" ) {
                return inputs[c].value;
            }
        }

        return "";
    };
}
