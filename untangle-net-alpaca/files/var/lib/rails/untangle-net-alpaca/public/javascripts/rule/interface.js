var InterfaceHandler = new Checkbox( "interface" );

InterfaceHandler.checkList = function()
{
    return this.interfaceList;
}

RuleBuilder.registerType( "d-intf", InterfaceHandler );
RuleBuilder.registerType( "s-intf", InterfaceHandler );

