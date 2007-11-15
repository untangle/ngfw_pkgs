var ProtocolHandler = new Checkbox( "protocol" );

ProtocolHandler.checkList = function()
{
    return this.protocolList;
}

RuleBuilder.registerType( "protocol", ProtocolHandler );
