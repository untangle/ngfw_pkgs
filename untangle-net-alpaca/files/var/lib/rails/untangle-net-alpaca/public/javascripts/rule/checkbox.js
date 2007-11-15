function Checkbox( name )
{
    this.name = name;

    this.content = function( rowId ) {
        var newContent = "";
        
        /* Retrieve all of the items that can be checked */
        var items = this.checkList();
        
        for ( var c = 0 ;  c < items.length ; c++ ) {
            if (( c % 3 ) == 2 ) newContent += "<br/>";
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
        return "<div class='checkbox'>" + line + label + "</div>";
    };
    
    this.checkboxId = function( rowId, identifier ) {
        return identifier + "[]";
    }
}
