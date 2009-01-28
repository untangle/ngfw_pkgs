Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.grid');

Ung.Alpaca.RuleBuilder = Ext.extend(Ext.grid.GridPanel, {
    enableHdMenu : false,
    enableColumnMove: false,
    clicksToEdit:1,
    initComponent: function() {
        if (!this.height) {
            this.height=320;
        }
        if (!this.width) {
            this.width=600;
        }
        this.xtype="rulebuilder";
        this.tbar = [{
            iconCls : 'icon-add-row',
            text : Ung.Alpaca.Util._("Add"),
            handler : this.addHandler,
            scope : this
        }]
        this.store = new Ext.data.SimpleStore({
            fields: [
               {name: 'name'},
               {name: 'value'}
            ]
        });
        
        this.recordDefaults={name:this.rules[0].name, value:""};
        var deleteColumn = new Ung.Alpaca.grid.DeleteColumn({});
        this.autoExpandColumn = 'displayName',
        this.plugins=[deleteColumn];
        this.columns=[{
            align: "center", 
            header: "",
            width:45,
            fixed: true,
            dataIndex: null,
            renderer: function(value, metadata, record) {
                return Ung.Alpaca.Util._("and");
            }
        },{
            header : Ung.Alpaca.Util._("Type"),
            width: 170,
            fixed: true,
            dataIndex : "name",
            renderer: function(value, metadata, record, rowIndex, colIndex, store) {
                var out=[];
                out.push('<select style="font-family:tahoma;font-size:12px;" onchange="Ext.getCmp(\''+this.getId()+'\').changeRowType(\''+record.id+'\',this)">');
                for (var i = 0; i < this.rules.length; i++) {
                    var seleStr=(this.rules[i].name == value)?"selected":"";
                    out.push('<option value="' + this.rules[i].name + '" ' + seleStr + '>' + this.rules[i].displayName + '</option>');
                }
                out.push("</select>")
                return out.join("");
            }.createDelegate(this)
        },{
            id:'displayName',
            header : Ung.Alpaca.Util._("Value"),
            width: 315,
            fixed: true,
            dataIndex : "value",
            renderer: function(value, metadata, record, rowIndex, colIndex, store) {
                var name=record.get("name");
                value=record.data.value;
                var rule=null;
                for (var i = 0; i < this.rules.length; i++) {
                    if (this.rules[i].name == name) {
                        rule=this.rules[i]
                        break;
                    }
                }
                var res="";
                switch(rule.type) {
                    case "text":
                        res='<input type="text" size="20" class="x-form-text x-form-field" style="width: 95%;height:16px;padding-top:1px;" onchange="Ext.getCmp(\''+this.getId()+'\').changeRowValue(\''+record.id+'\',this)" value="'+value+'"/>';
                        break;
                    case "boolean":
                        res="<div>&nbsp;</div>";
                        break;
                    case "checkgroup":
                        var values_arr=(value!=null && value.length>0)?value.split(","):[];
                        var out=[];
                        for(var i=0; i<rule.values.length; i++) {
                            var rule_value=rule.values[i][0];
                            var rule_label=rule.values[i][1];
                            var checked_str="";
                            for(var j=0;j<values_arr.length; j++) {
                                if(values_arr[j]==rule_value) {
                                    checked_str="checked";
                                    break;
                                }
                            }
                            out.push('<div class="checkbox" style="width:100px; float: left; padding:3px 0;">');
                            out.push('<input id="'+rule_value+'[]" class="checkbox" '+checked_str+' onchange="Ext.getCmp(\''+this.getId()+'\').changeRowValue(\''+record.id+'\',this)" style="display:inline; float:left;margin:0;" name="'+rule_label+'" value="'+rule_value+'" type="checkbox">');
                            out.push('<label for="'+rule_value+'[]" style="display:inline;float:left;margin:0 0 0 0.6em;padding:0;text-align:left;width:50%;">'+rule_label+'</label>')
                            out.push('</div>')
                        }
                        res=out.join("");
                        break;
                        
                }
                return res;
            }.createDelegate(this)
        },deleteColumn];
        Ext.grid.EditorGridPanel.superclass.initComponent.apply( this, arguments );
        
    },
    changeRowType: function(recordId,selObj) {
        var record=this.store.getById(recordId);
        var newName=selObj.options[selObj.selectedIndex].value;
        var rule=null;
        for (var i = 0; i < this.rules.length; i++) {
            if (this.rules[i].name == newName) {
                rule=this.rules[i]
                break;
            }
        }
        var newValue="";
        if(rule.type=="boolean") {
            newValue="true";
        }
        record.data.value=newValue;
        record.set("name",newName);
    },
    changeRowValue: function(recordId,valObj) {
        var record=this.store.getById(recordId);
        switch(valObj.type) {
            case "checkbox":
                var record_value=record.get("value");
                var values_arr=(record_value!=null && record_value.length>0)?record_value.split(","):[];
                if(valObj.checked) {
                    values_arr.push(valObj.value);
                } else {
                    for(var i=0;i<values_arr.length;i++) {
                        if(values_arr[i]==valObj.value) {
                            values_arr.splice(i,1);
                            break;
                        }
                    }
                }
                record.data.value=values_arr.join(",");
                break;
            case "text":
                var new_value=valObj.value;
                if(new_value!=null) {
                    new_value.replace("::","");
                    new_value.replace("&&","");
                }
                record.data.value=new_value;
                break;
        }
    },
    addHandler: function() {
        var record=new Ext.data.Record(Ext.decode(Ext.encode(this.recordDefaults)));
        this.getStore().insert(0, [record]);
    },
    deleteHandler: function (record) {
        this.store.remove(record);
    },
    setValue: function(value) {
        var arr=(value!=null && value.length>0)?value.split("&&"):[];
        var entries=[];
        for(var i=0; i<arr.length; i++) {
            entries.push(arr[i].split("::"));
        }
        this.store.loadData(entries);
    },
    getValue: function() {
        var list=[];
        var records=this.store.getRange();
        for(var i=0; i<records.length;i++) {
            list.push(records[i].get("name")+"::"+records[i].get("value"))
        }
        return list.join("&&");
    },
    getName: function() {
        return "rulebuilder";
    }

    
});
Ext.reg('rulebuilder', Ung.Alpaca.RuleBuilder);
/*
Ung.Alpaca.grid.RuleBuilderValueColumn = Ext.extend(Object, {
    constructor : function(config) {
        Ext.apply(this, config);
        if (!this.id) {
            this.id = Ext.id();
        }
        if (!this.header) {
            this.header = Ung.Alpaca.Util._("Reorder");
        }
        if (!this.width) {
            this.width = 55;
        }
        if (this.fixed == null) {
            this.fixed = true;
        }
        if (this.sortable == null) {
            this.sortable = false;
        }
        if (!this.dataIndex) {
            this.dataIndex = null;
        }
        this.renderer = this.renderer.createDelegate(this);
    },
    init : function(grid) {
        this.grid = grid;
    },

    renderer : function(value, metadata, record) {
        return '<div class="icon-drag">&nbsp;</div>';
    }
});
*/