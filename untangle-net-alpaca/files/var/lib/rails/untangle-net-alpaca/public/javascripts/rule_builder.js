var RuleBuilder =
{
    handlers : new Array(),

    /* Use this to set a type and its value */
    setType : function( rowId, parameter, newValue )
    {
        var row  = document.getElementById( rowId );
        
        /* Try to get the element */
        value = row.getElementsByTagName( "div" );

        if (( value == null ) || ( value.length == 0 )) return;
        
        var found = false;
        
        /* Iterate, looking for the first item with the class value. */
        for ( var c = 0 ; c < value.length ; c++ ) {
            if ( !this.hasClass( value[c], "value" )) continue;
            
            found = true;
            value = value[c];
            break;
        }

        if ( !found ) return;
        
        var handler = this.handlers[parameter];

        /* Unable to update if the handler is not known */
        if ( handler == null ) return;

        /* Retrieve the first select and change it to */
        var select  = row.getElementsByTagName( "select" );
        
        if (( select == null ) || ( select.length == 0 )) return;
        
        /* set the first elements value */
        select[0].value = parameter;

        /* Replace the item at that position */
        Element.update( value, handler.content( rowId ));

        if ( newValue != null ) handler.setValue( rowId, newValue );
    },

    /* Update the current type of a rule */
    selectType : function( rowId )
    {
        var row  = document.getElementById( rowId );
        
        /* need some error handling */
        if ( row == null ) return;
        
        /* Retrieve the first select */
        var parameter  = row.getElementsByTagName( "select" );
        
        if (( parameter == null ) || ( parameter.length == 0 )) return;
        
        /* Get the first elements value */
        parameter = parameter[0].value;

        this.setType( rowId, parameter, null );
    },
    
    removeClass : function( element, className )
    {
        var classArray = element.className.split( " " );
        for ( var c = 0 ; c < classArray.length ; c++ ) {
            /* Skip the class that is to be removed */
            if ( classArray[c] == className ) continue;
            element.className = element.className + classArray[c];
        }
    },
    
    addClass : function( element, className )
    {
        /* No need to add it if it is already there */
        if ( this.hasClass( element, className )) return;

        element.className = ( element.className + " " + className ).strip();
    },

    /* Return true iff element has className as one if its CSS classes */
    hasClass : function( element, className )
    {
        /* use an iterator because otherwise could overmatch with a
         * simple string search.  eg value would also match
         * "value-special random-css-class", could use a regex? */
        var classArray = element.className.split( " " );
        for ( var c = 0 ; c < classArray.length ; c++ ) {
            if ( classArray[c] != className ) continue;
            return true;
        }

        return false;
    },

    /* Remove a parameter from the list, this will not let you remove the last one */
    removeParameter : function( rowId )
    {
        /* Not allowed to delete the first item */
        if ( this.numParameters() <= 1 ) return;

        var element = document.getElementById( rowId );
        
        /* Ignore anything that doesn't exists */
        if ( element == null ) return;
        
        /* Ignore anything that is not a list item */
        if ( element.nodeName != "LI" && element.nodeName != "li" ) return;
                
        try {
            Element.remove( rowId );
			this.updateRowStyles('rule-builder');
        } catch ( e ) {
            /* ignoring the error */
        }
    },

    addParameter : function()
    {
        new Ajax.Request( this.createParameter, { asynchronous:true, evalScripts:true} );
        return false;
    },
    
    registerType : function( name, handler )
    {
        /* Set the handler for this name */
        this.handlers[name] = handler;
    },

    /* Delete a parameter, this will not let you delete the last parameter. */

    /* This updates all of the rules filter types so that no two rules
     * have the same ones available */
    updateFilterTypes : function()
    {
    },

    /* Return the number of elements in the rule builder */
    numParameters : function()
    {
        var list = document.getElementById( "rule-builder" );
        if ( list == null ) return;

        var children = list.childNodes;

        var numChildren = 0;

        for ( var c = 0 ; c < children.length ; c++ ) {
            if ( children[c].nodeName != "LI" && children[c].nodeName != "li" ) continue;
            
            if ( !this.hasClass( children[c], "rule" )) continue;
            numChildren++;
        }

        return numChildren;
    },

    edit : function( rowId, tableId, deleteOnCancel )
    {
        var fieldHash = { row_id : rowId };

	this.manager.rowId = rowId
	this.manager.tableId = tableId;

	this.manager.deleteOnCancel = deleteOnCancel; 

        for ( var c = 0 ; c < this.manager.fields.length ; c++ ) {
            var field = document.getElementById( this.manager.fields[c] + "_" + rowId );
            
            if ( field == null ) {
                alert( "Missing the field: " + this.manager.fields[c] );
                return;
            }
                        
            /* Append this value to the field array */
            if ( field.type == "checkbox" ) {
                fieldHash[this.manager.fields[c]] = field.checked;
            } else {
                fieldHash[this.manager.fields[c]] = field.value;
            }            
        }
        
        var request = new Ajax.Request( this.manager.editFilter, 
            { asynchronous:false, evalScripts:true, 
              parameters: Hash.toQueryString( fieldHash ) } );
        
        if ( !request.success() ) {
            alert( "unable to edit the filter." );
            return;
        }

        Element.show( "overlay" );
    },

    cancel : function()
    {
	if (this.manager.deleteOnCancel) {
	    TableManager.remove( this.manager.tableId, this.manager.rowId );
	}
        Element.hide( "overlay" );
    },

    /* Close the rule builder */
    close : function()
    {
        Element.hide( "overlay" );
    },

    /* Update the entry */
    update : function( rowId )
    {
        var list = document.getElementById( "rule-builder" );
        if ( list == null ) return;

        var children = list.childNodes;
        
        var filterValue = "";

        for ( var c = 0 ; c < children.length ; c++ ) {
            if ( children[c].nodeName != "LI" && children[c].nodeName != "li" ) continue;
            
            if ( !this.hasClass( children[c], "rule" )) continue;
            
            var row = children[c];
            
            /* Retrieve the select */
            var select  = row.getElementsByTagName( "select" );
            
            if (( select == null ) || ( select.length == 0 )) continue;

            var parameter = select[0].value;

            var handler = this.handlers[parameter];

            if ( handler == null ) continue;

            if ( filterValue != "" ) filterValue += "&&";
            
            /* append the filterValue */
            filterValue += parameter + "::" + handler.parseValue( row.id );
        }

        for ( var c = 0 ; c < this.manager.fields.length ; c++ ) {
            var field = document.getElementById( this.manager.fields[c] + "_" + rowId );
            
            if ( field == null ) {
                alert( "Missing the field: " + this.manager.fields[c] );
                return;
            }

            if ( this.manager.fields[c] == "filters" ) {
                field.value = filterValue;
            } else {
                var newValue = document.getElementById( this.manager.fields[c] );
                if ( newValue == null ) {
                    alert( "Missing the value: " + this.manager.fields[c] );
                    return;
                }
                
                if ( field.type == "checkbox" ) {
                    field.checked = newValue.checked;
                } else {
                    field.value = newValue.value;
                }
            }
        }

        enableSave();
    },

  	updateRowStyles : function( tableId)
    {

		var table = document.getElementById( tableId );

        /* Ignore anything that doesn't exist */
        if ( table == null ) return;

        /* Ignore anything that is not an unsorted list. */
        if ( table.nodeName != "UL" && table.nodeName != "ul" ) return;

        var children = table.childNodes;

        var isFirst = true;
        var isOdd = true;

        for ( var c = 0 ; c < children.length ; c++ ) {
            if ( children[c].nodeName != "LI" && children[c].nodeName != "li" ) continue;

            var child = children[c];

            if ( isFirst ) {
                Element.addClassName( child, "first" );
            } else {
                Element.removeClassName( child, "first" );
            }

            if ( isOdd ) {
                Element.addClassName( child, "odd" );
                Element.removeClassName( child, "even" );
            } else {
                Element.addClassName( child, "even" );
                Element.removeClassName( child, "odd" );
            }

            isFirst = false;
            isOdd = !isOdd;
        }


    },
};

function Rule( parameter, value )
{
    this.parameter = parameter;
    this.value = value;
}

function Checkbox( name )
{
    this.name = name;

    this.content = function( rowId ) {
        var newContent = "";
        
        /* Retrieve all of the items that can be checked */
        var items = this.checkList();
        
        for ( var c = 0 ;  c < items.length ; c++ ) {
            //if (( c % 3 ) == 2 ) newContent += "<br/>";
            newContent +=  this.checkbox( rowId, items[c][0], items[c][1] );
        }

        return newContent;
    };

    this.setValue = function( rowId, value ) {
        var element = document.getElementById( rowId );
        if ( element == null ) return;

        var valueArray = value.split( "," );
        
        var valueHash = new Array();

        for ( var c = 0 ; c < valueArray.length ; c++ ) {
            valueHash[valueArray[c].strip()] = true;
        }
        
        /* Clear all of the checkboxes */
        var checkboxes = element.getElementsByTagName( "input" );

        for ( var c = 0 ; c < checkboxes.length ; c++ ) {
            if ( checkboxes[c].type == "checkbox" ) {
                checkboxes[c].checked = ( valueHash[checkboxes[c].value] == true );
            }
        }
    };

    this.parseValue = function( rowId ) {
        var element = document.getElementById( rowId );
        if ( element == null ) return;
        
        /* Clear all of the checkboxes */
        var checkboxes = element.getElementsByTagName( "input" );
        
        var value = "";

        for ( var c = 0 ; c < checkboxes.length ; c++ ) {
            if ( checkboxes[c].type == "checkbox" ) {
                if ( !checkboxes[c].checked ) continue;
                if ( value != "" ) value += ",";
                value += checkboxes[c].value;
            }
        }
        
        return value;
    };

    /* Function to build a single checkbox */
    this.checkbox = function( rowId, identifier, label ) {
        var line = "<input id='" + this.checkboxId( rowId, identifier )
        + "' type='checkbox' name='" + label + "' value='" + identifier + "'/>";
        
        /* Wrap it in a div */
        return "<div class='checkbox'>" + line + "<label for='"+this.checkboxId( rowId, identifier )+"'>"+ label + "</label></div>";
    };
    
    this.checkboxId = function( rowId, identifier ) {
        return identifier + "[]";
    }
}


var DayHandler = new Checkbox( "day" );

DayHandler.checkList = function()
{
    return this.dayList;
}

RuleBuilder.registerType( "day-of-week", DayHandler );

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

var IPAddressHandler = new Textbox();

RuleBuilder.registerType( "d-addr", IPAddressHandler );
RuleBuilder.registerType( "s-addr", IPAddressHandler );

var PortHandler = new Textbox();

RuleBuilder.registerType( "d-port", PortHandler );
RuleBuilder.registerType( "s-port", PortHandler );

var ProtocolHandler = new Checkbox( "protocol" );

ProtocolHandler.checkList = function()
{
    return this.protocolList;
}

RuleBuilder.registerType( "protocol", ProtocolHandler );

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
var TimeHandler =
{
    content : function( rowId ) {
        return "<div>" + this.time( "start" ) + " to " + this.time( "end" ) + "</div>";
    },

    validate : function( rowId ) {
        
    },

    /* value must be in the format hh,mm,hh,mm
     * this may look odd, but it is really easy to parse.
     * hh is 24 hour time.
     * mm is a 0,15,30,45.
     */
    setValue : function( rowId, value )
    {
        var element = document.getElementById( rowId );
        if ( element == null ) return;
        
        /* Clear all of the checkboxes */
        var inputs = element.getElementsByTagName( "select" );
        
        var timeArray = value.split( "," );
        if ( timeArray.length != 4 ) return;
        
        for ( var c = 0 ; c < inputs.length ; c++ ) {
            switch ( inputs[c].id ) {
            case "start-time-hour": inputs[c].value = timeArray[0]; break;
            case "start-time-minute": inputs[c].value = timeArray[1]; break;
            case "end-time-hour": inputs[c].value = timeArray[2]; break;
            case "end-time-minute": inputs[c].value = timeArray[3]; break;
            }
        }
    },

    parseValue : function( rowId ) {
        var element = document.getElementById( rowId );
        if ( element == null ) return;
        
        /* Clear all of the checkboxes */
        var inputs = element.getElementsByTagName( "select" );
        
        var timeArray = new Array( 0, 0, 0, 0 );
        
        for ( var c = 0 ; c < inputs.length ; c++ ) {
            switch ( inputs[c].id ) {
            case "start-time-hour": timeArray[0] = inputs[c].value; break;
            case "start-time-minute": timeArray[1] = inputs[c].value; break;
            case "end-time-hour": timeArray[2] = inputs[c].value; break;
            case "end-time-minute": timeArray[3] = inputs[c].value; break;
            }
        }
        
        return timeArray.join( "," );
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

