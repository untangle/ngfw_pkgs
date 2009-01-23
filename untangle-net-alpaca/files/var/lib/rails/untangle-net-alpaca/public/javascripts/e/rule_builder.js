Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

Ung.Alpaca.RuleBuilder = Ext.extend(Ext.Component, {
    rules:null,
    setValue : function (value) {
        
    },
    getValue: function () {
        
    },
    getName: function () {
        return "rulebuilder";
    }
});
Ung.Alpaca.Rule = Ext.extend(Ext.Component, {
    name:null,
    displayName: null,
    type: null,
    //To Override for each type of rule
    getItems: function() {
    },
    getValue: function() {
        
    },
    setValue: function() {
        
    }
});