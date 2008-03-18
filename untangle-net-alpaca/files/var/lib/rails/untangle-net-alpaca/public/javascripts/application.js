// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults


var Network =
{
    setConfigType : function ( id ) 
    {
        var configType = document.getElementById( "config_type_" + id );

        /* Retrieve the value of the drop down */
        configType = configType.value;
        
        var element = document.getElementById( id + "_" + configType );
        
        /* Ignore anything that doesn't exists */
        if ( element == null ) return;

        /* Ignore anything that is not a DIV */
        if ( element.nodeName != "DIV" && element.nodeName != "div" ) return;

        var container = document.getElementById( id );
        
        /* Ignore anything that is not a DIV */
        if ( container == null ) return;
        
        var children = container.childNodes;
        var len = children.length;
        
        for ( var i = 0 ; i < len ; i++ ) {
            /* Ignore anything that is not a list item */
            if ( children[i].nodeName != "DIV" && children[i].nodeName != "div" ) continue;
            
            if ( children[i] == element  ) {
                Element.show( children[i] );
            } else {
                Element.hide( children[i] );
            }
        }
    },

    removeListItem : function ( id )
    {
        var element = document.getElementById( id );
        
        /* Ignore anything that doesn't exists */
        if ( element == null ) return;
        
        /* Ignore anything that is not a list item */
        if ( element.nodeName != "LI" && element.nodeName != "li" ) return;
        
        try {
            Element.remove( id );
        } catch ( e ) {
            /* ignoring the error */
        }
    }
};

var Interface = 
{
    setConfigType : function ()
    {
	var configType = document.getElementById( "config_type" );
    
	if ( configType == null ) return;

	/* Retrieve the value of the drop down */
	configType = configType.value;

	var element = document.getElementById( configType );
    
	/* Ignore anything that doesn't exists */
	if ( element == null ) return;
    
	/* Ignore anything that is not a DIV */
	if ( element.nodeName != "DIV" && element.nodeName != "div" ) return;

	var container = document.getElementById( "config-panels" );
    
	/* Ignore anything that is not a DIV */
	if ( container == null ) return;
    
	var children = container.childNodes;
	var len = children.length;

	for ( var i = 0 ; i < len ; i++ ) {
	    /* Ignore anything that is not a list item */
	    if ( children[i].nodeName != "DIV" && children[i].nodeName != "div" ) continue;
        
	    if ( children[i].id == configType ) {
		Element.show( children[i] );
		var d = children[i].descendants();
		for (var j = 0; j < d.length; j++ ) {
		    if (d[j].tagName.toUpperCase() == "INPUT" || d[j].tagName.toUpperCase() == "SELECT") {
			d[j].disabled = false;
		    }
		}
	    } else {
		Element.hide( children[i] );
var d = children[i].descendants();
		for (var j = 0; j < d.length; j++ ) {
		    if (d[j].tagName.toUpperCase() == "INPUT" || d[j].tagName.toUpperCase() == "SELECT") {
			d[j].disabled = true;
		    }
		}
	    }
	}
    }
};

var RedirectManager = 
{
    removeListItem : function( rowId )
    {
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
    
    fields : new Array( "filters", "description", "new_ip", "new_enc_id", "enabled" )
}

var SubscriptionManager = 
{
    removeListItem : function( rowId )
    {
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
    
    fields : new Array( "filters", "description", "subscribe", "enabled" )
}

var TableManager = 
{
    styledTable : {},

    remove : function( tableId, rowId )
    {
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

        this.updateRowStyles( tableId );

        enableSave();
    },
    
    updateRowStyles : function( tableId )
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
    }
};

var FirewallManager = 
{
    removeListItem : function( rowId )
    {
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

    getAction : function( value )
    {
        
    },
    
    fields : new Array( "filters", "description", "target", "enabled" )
}

//Fabtabulous!
//http://www.tetlaw.id.au/view/blog/fabtabulous-simple-tabs-using-prototype/
// CC share and share alike
//http://creativecommons.org/licenses/by-sa/2.5/

var Fabtabs = Class.create();
Fabtabs.prototype = {
    initialize : function(element) {
	this.element = $(element);
	if ( this.element ) {
	    var options = Object.extend({}, arguments[1] || {});
	    this.menu = $A(this.element.getElementsByTagName('a'));
	    //this.menu = $A(this.element.getElementsByTagName('li'));
	    
	    this.getInitialTab();
	    this.activate.bind(this);
	    this.menu.each(this.setupTab.bind(this));
	    this.warn = false;
	    if ( $('advanced-menu') ) {
		this.advancedMenu = $A($('advanced-menu').getElementsByTagName('a'));
		//this.activateAdvanced.bind(this);
		this.advancedMenu.each(this.setupTab.bind(this));
	    }
	}
    },
    activate :  function(ev) {
	var elm = Event.findElement(ev, "a");
	Event.stop(ev);
	if (this.warn) {
            this.tabWarn();
            this.ok = function(ev) { this.warn = false; this.show(elm); this.menu.without(elm).each(this.hide.bind(this)); Element.hide( "overlay" ); Element.hide( "ie-overlay" ); }
	    return false;
	}
	this.show(elm);
	this.menu.without(elm).each(this.hide.bind(this));
    },
    ok : function(ev) {
        this.warn = false;
        Element.hide( "ie-overlay" );
        Element.hide( "overlay" );

    },
    cancel : function(ev) {
        this.warn = true;
        Element.hide( "overlay" );
        Element.hide( "ie-overlay" );

    },
    tabWarn : function(elm) {
        var request = new Ajax.Request( "/alpaca/alpaca/tab",
            { asynchronous:false, evalScripts:true } );

        if ( !request.success() ) {
            alert( "unable to warn on page change." );
            return;
        }

        Element.show( "overlay" );
        Element.show( "ie-overlay" );

    },
    setWarn : function(value) {
	this.warn = value;
    },
    setupTab : function(elm) {
	Event.observe(elm,'click',this.activate.bindAsEventListener(this),false)
    },
    hide : function(elm) {
	$(elm).removeClassName('active-tab');
	var ancestors = $(elm).ancestors();
	ancestors[0].removeClassName('active-tab');
    },
    show : function(elm) {
	var up = new Ajax.Updater($('main-content'), $(elm).href, { evalScripts: true });
        this.highlight(elm);
    },
    highlight : function(elm) {
	$(elm).addClassName('active-tab');
	var ancestors = $(elm).ancestors();
	ancestors[0].addClassName('active-tab');
    },
    //tabID : function(elm) {
    //return elm.href.match(/#(\w.+)/)[1];
    //},
    getInitialTab : function() {
    	if(document.location.href.match(/(\w.+)/)) {
    	    var loc = RegExp.$1;
	    loc = loc.replace(/\?.*/,"")
    	    var elm = this.menu.find(function(value) {
		    var href = value.href.match(/(\w.+)/)[1];
		    href = href.replace(/\/list/,"")
		    href = href.replace(/\/manage/,"")
		    return loc.substring(0, href.length) == href;
		});
            if (! elm) {
                var elm = this.menu.find(function(value) { var href = value.href.match(/(\w.+)/)[1];
                    href = href.replace(/\/list/,"")
                    href = href.replace(/\/manage/,"")
                    return (loc.substring(0, href.length) + "network")  == href } );
            }
            if (! elm) {
                var elm = this.menu.find(function(value) { var href = value.href.match(/(\w.+)/)[1];
                    href = href.replace(/\/list/,"")
                    href = href.replace(/\/manage/,"")
                    return (loc.substring(0, href.length) + "interface")  == href } );
            }
    	    if (elm) {
	        this.highlight(elm);
		return elm;
	    }
	}
	return this.menu.first();
    }
}

var handleResize = function () {
	//only kept here for legacy reasons
}
var replaceSelectBoxes = function () {
//alert('here');
}
var focusTableField = function(event) {
    var element = Event.element(event);
	if (element) {
    	element.addClassName('focus');
	}
}

var blurTableField = function(event) {
    var element = Event.element(event);
	if (element) {
    	element.removeClassName('focus');
	}
}

var focusBlurTextFields = function() {
    var textfields = $$('input.textfield');
    for(var i=0; i<textfields.length; i++) {
	textfields[i].observe('focus', focusTableField);
	textfields[i].observe('blur', blurTableField); 
    }
}

var showSpinner = function() {
    if ( $('spinner') ) {
        $('spinner').show();
    }
}

var hideSpinner = function() {
    if ( $('spinner') ) {
        $('spinner').hide();
    }
}

var spinnerOnSubmit = function() {
    var forms = $$('form');
    for(var i=0; i<forms.length; i++) {
	forms[i].observe('submit', showSpinner);
    }
    //var links = $$('a');
    //for(var i=0; i<links.length; i++) {
        //links[i].observe('click', showSpinner);
    //}
    var buttons = $$('input.submit');
    for(var i=0; i<buttons.length; i++) {
	buttons[i].observe('click', showSpinner);
    }
    var buttons = $$('input.test-connectivity');
    for(var i=0; i<buttons.length; i++) {
	buttons[i].observe('click', showSpinner);
    }
    var buttons = $$('input.refresh-button');
    for(var i=0; i<buttons.length; i++) {
	buttons[i].observe('click', showSpinner);
    }
    var buttons = $$('div.refresh-button');
    for(var i=0; i<buttons.length; i++) {
	buttons[i].observe('click', showSpinner);
    }
    if ($('Save')) {
        $('Save').observe('click', showSpinner);
    }
}


var myFabTabs;

var enableSave = function() {
    if (! $('Save')) { return false; }
    if ($('Save').disabled) {
	myFabTabs.setWarn(true);
    }
    $('Save').disabled = false;
    $('Save').removeClassName('disabled');
}

var initTableRow = function(thisId) {

	var newRows = $(thisId).getElementsByClassName('new');

	//only take the first one
	if (newRows.length > 0) {
		var thisRow = newRows[0];
		if (thisRow.id) {
			
				//handle initial row flicker
				thisRow.setStyle({visibility: 'hidden'});
				setTimeout( function() {thisRow.setStyle({visibility: 'visible'})}, 100);
				
		}
	}
	
}

var enableSaveObservers = function() {
    var inputs = $$('input');
    var selects = $$('select');
    for (var i=0; i<inputs.length; i++) {
	inputs[i].observe('change', enableSave);
	inputs[i].observe('keypress', enableSave);
	if (inputs[i].type == 'checkbox') {
  	    inputs[i].observe('click', enableSave);
        }
    }
    for (var i=0; i<selects.length; i++) {
	selects[i].observe('change', enableSave);
	selects[i].observe('keypress', enableSave);
    }
}


var enableSaveOnChange = function() {
    myFabTabs.setWarn(false);
    if (! $('Save')) { return false; }
    $('Save').disabled = true;
    $('Save').addClassName('disabled');
    enableSaveObservers();
}

var clickingEnabled = true;
var clickTimeout = 3000;

function isClickingEnabled() {
    return clickingEnabled;
}

function enableClicking() {
    clickingEnabled = true;
}

function disableClickingFor(time) {
    clickingEnabled = false;
    window.setTimeout(enableClicking, time);
}

var init = function() {
    myFabTabs = new Fabtabs('tabs');

    focusBlurTextFields();
    enableSaveOnChange();
    spinnerOnSubmit();
    hideSpinner();
}

Event.observe(window,'load', init, false);
