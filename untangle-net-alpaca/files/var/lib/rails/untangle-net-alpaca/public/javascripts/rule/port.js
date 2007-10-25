var PortHandler =
{
    /* Function to generate the content */
    content : function() {
        return '<input id="ruleValue[]" name="ruleValue[]" type="text"/>';
    },

    /* Validation function */
    validate : function( rowId ) {
        
    }
}

RuleBuilder.registerType( "d-port", PortHandler );
RuleBuilder.registerType( "s-port", PortHandler );

