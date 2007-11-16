var InterfaceHandler = new Checkbox( "interface" );

InterfaceHandler.checkList = function()
{
    return this.interfaceList;
}

RuleBuilder.registerType( "d-intf", InterfaceHandler );
RuleBuilder.registerType( "s-intf", InterfaceHandler );

var LocalInterfaceHandler =
{
    content : function( rowId )
    {
        /* These don't require anything */
        return "";
    },

    validate : function( rowId )
    {
    },

    /* Value is ignored */
    setValue : function( rowId, value )
    {
    },

    /* value is ignored */
    parseValue : function( rowId ) {
        return true;
    }
}

RuleBuilder.registerType( "s-local", LocalInterfaceHandler );
RuleBuilder.registerType( "d-local", LocalInterfaceHandler );

