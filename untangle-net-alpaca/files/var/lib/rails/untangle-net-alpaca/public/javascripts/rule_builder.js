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

    edit : function( rowId )
    {
        var fieldHash = { row_id : rowId };

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
    }
};

function Rule( parameter, value )
{
    this.parameter = parameter;
    this.value = value;
}

