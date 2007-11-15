var DayHandler = new Checkbox( "day" );

DayHandler.checkList = function()
{
    return this.dayList;
}

RuleBuilder.registerType( "day-of-week", DayHandler );

