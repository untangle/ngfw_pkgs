var IPAddressHandler =
{
    /* Function to generate the content */
    content : function() {
        return '<input id="ruleValue[]" name="ruleValue[]" type="text"/>';
    },

    /* Validation function */
    validate : function( rowId ) {
        
    }
}

RuleBuilder.registerType( "d-addr", IPAddressHandler );
RuleBuilder.registerType( "s-addr", IPAddressHandler );

