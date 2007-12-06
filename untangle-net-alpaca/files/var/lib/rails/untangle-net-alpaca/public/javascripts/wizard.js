function setConfigType( parent )
{
    var container = document.getElementById(parent);
    /* Iterate all of the children and hide them */
    
    var children = container.childNodes;
    var len = children.length;
    
    var configType = document.getElementById(parent + ".type" );
    
    if ( configType == null ) return alert( "Unable to find config type" );

    configType = configType.value;

    if ( configType == null ) return alert( "Unable to find config type" );

    /* This is the convention for naming the child panels */
    var panelId = parent + "-" + configType;

    for ( var i = 0 ; i < len ; i++ ) {
        if ( children[i].nodeName != "DIV" && children[i].nodeName != "div" ) continue;

        if ( children[i].id == panelId ) Element.show( children[i].id );
        else Element.hide( children[i].id );
    }
}

function Interface( id, osName, name )
{
    this.id = id;
    this.osName = osName;
    this.name = name;
}

/* This is an array of all of the ids (in order) */
var interfaceArray = new Array();

/* This is a function for the interface management */
function updateBridges( stageId )
{
    var html = "";
    var len = interfaceArray.length;
    var select = stageId + "-bridge.bridge_interface";

    for ( var c = 0 ; c< len ; c++ ) {
        var intf = interfaceArray[c];

        /* Don't add interfaces past the current one */
        if ( intf.id == stageId ) break;

        /* This is the current configuration type for the interface */
        var configType = document.getElementById( intf.id + ".type" );
        
        if ( configType == null ) continue;

        /* Retrieve the current value */
        configType = configType.value;

        switch ( configType ) {
        case 'static':
        case 'dynamic':
            html += "<option value='" + intf.osName + "'>" + intf.name + "</option>";
            break;

        default:
            break;
        }
    }
    
    /* Time to update the comboxbox */
    if ( select != null && document.getElementById( select) != null ) Element.update( select, html );
}

var Wizard = 
{
    /* The current stage */
    currentStage : 0,

    /* Next page callbacks, called when entering this page */
    nextEnterCallback : new Array(),

    /* Next page callback, called when exiting this page */
    nextExitCallback : new Array(),

    changeCurrent : function ( current )
    {
        var list = document.getElementById("step-list");
        
        var children = list.childNodes;
        var len = children.length;
        
        var className = "completed";

        /* All of the list ids are prefixed by sl- */
        var listId = "sl-" + current;

        /* Should this print an error message ? */
        if ( current < 0 ) {
            current = 0;
        } else if ( current >= len ) {
            current = len - 1;
        }

        /* True if the current is an advancing move (callbacks are only invoked when moving to the next
         * step */
        var isNext = ( current == ( this.currentStage + 1 ))
    
        var j = 0;

        for( var i = 0 ; i < len; i++ ) {
            /* Ignore anything that is not a list item */
            if ( children[i].nodeName != "LI" && children[i].nodeName != "li" ) continue;
        
            var panelId = children[i].id.replace( /^sl-/, "" );

            if ( j == current ) {
                children[i].className = "current";
                className = "incomplete";
                try {
                    var callback = this.nextEnterCallback[panelId];
                    if ( isNext && ( callback != null )) callback();
                    Element.show( panelId );
                } catch ( e ) { }
            } else {
                children[i].className = className;
                try {
                    Element.hide( panelId );
                
                    /* If this is the panel before, and this is going to
                     * the next panel, calll the exit callback */
                    if (( j == ( current - 1)) && isNext ) {
                        var callback = this.nextExitCallback[panelId];
                        if ( callback != null ) callback();
                    }
                } catch ( e ) { 
                    alert( "Unable to do it" + e )
                        }
            }

            /* This is the index of the actual list items */
            j++;
        }

        /* Update the value of the current item */
        this.currentStage = current;
    },

    /* Go to the previous stage, if possible */
    prevStage : function()
    {
        /* Decrement the value by one */
        this.changeCurrent( this.currentStage - 1);
    },
    
    /* Go to the next stage, if possible. */
    nextStage : function()
    {
        if ( Wizard.completed ) {
            location.href = '/network';
            return;
        }

        /* Increment the value by one */
        this.changeCurrent( this.currentStage + 1)
    },

    disableNavButtons : function() {
        var prev = document.getElementById( "prev" );
        if ( prev != null ) {
            Element.hide( prev );
            prev.onclick = "";
        }
        
        var next = document.getElementById( "next" );
        if ( next != null ) {
            Element.update( next, "Continue" );
            Wizard.completed = true;
        }
    },

    completed : false
};


