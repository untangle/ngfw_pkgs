// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

var Alpaca =
{
    removeStaticEntry : function ( rowId )
    {
        try {
            Element.remove( rowId );
        } catch ( e ) {
        }
    }
};

//Fabtabulous!
//http://www.tetlaw.id.au/view/blog/fabtabulous-simple-tabs-using-prototype/
// CC share and share alike
//http://creativecommons.org/licenses/by-sa/2.5/

var Fabtabs = Class.create();
Fabtabs.prototype = {
    initialize : function(element) {
	this.element = $(element);
	var options = Object.extend({}, arguments[1] || {});
	this.menu = $A(this.element.getElementsByTagName('a'));
	//this.menu = $A(this.element.getElementsByTagName('li'));

	this.getInitialTab();
	this.menu.each(this.setupTab.bind(this));
	this.warn = false;
    },
    setWarn : function(value) {
	this.warn = value;
    },
    setupTab : function(elm) {
	Event.observe(elm,'click',this.activate.bindAsEventListener(this),false)
    },
    activate :  function(ev) {
	var elm = Event.findElement(ev, "a");
	Event.stop(ev);
	if (this.warn) {
	    if ( ! confirm("Warning: leaving this page will lose unsaved changes!") ) {
		return false;
	    }
	}
	this.show(elm);
	this.menu.without(elm).each(this.hide.bind(this));
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
    	    var elm = this.menu.find(function(value) {
		    var href = value.href.match(/(\w.+)/)[1];
		    href = href.replace(/\/list/,"")
		    href = href.replace(/\/manage/,"")
		    return loc.substring(href.length, 0) == href;
		    //return value.href.match(/(\w.+)/)[1] == loc; 
		});
    	    if (elm) {
	        this.highlight(elm);
		return elm
	    }
	}
	//$(this.menu.first()).addClassName('active-tab');
	//var ancestors = $(this.menu.first()).ancestors();
	//ancestors[1].addClassName('active-tab');
	return this.menu.first();
    }
}

var handleResize = function () {
	var footerTop = '800px';
	var contentHeight = '800px';
	var bodyWidth = '100%';
	/*
	if (window.innerHeight !== undefined) {
	    footerTop = (window.innerHeight - 80).toString() + 'px';
	    bodyHeight = (window.innerHeight - 154).toString() + 'px';
	    bodyWidth = (window.innerWidth - 35).toString() + 'px';
	    contentHeight = (window.innerHeight - 29).toString() + 'px';
	} else {
	    footerTop = (document.documentElement.clientHeight - 80).toString() + 'px';
	    bodyHeight =  (document.documentElement.clientHeight - 154).toString() + 'px';
	    bodyWidth = (document.documentElement.clientWidth - 35).toString() + 'px';
	    contentHeight =  (document.documentElement.clientHeight - 29).toString() + 'px';
	}
	*/
	if (window.innerHeight !== undefined) {
	    bodyHeight = $('main-content-body').getHeight();
	    windowHeight = (window.innerHeight - $('main-menu').getHeight() - 126).toString() + 'px';
	    if (windowHeight > bodyHeight) {
		bodyHeight = windowHeight;
	    }

	    contentHeight = bodyHeight;
	    bodyWidth = (window.innerWidth - 50).toString() + 'px';
	    //	    contentHeight = (window.innerHeight - $('main-menu').getHeight() - 1).toString() + 'px';
		//footerTop = (window.innerHeight - 50).toString() + 'px';
	} else {
	    //footerTop = (document.documentElement.clientHeight - 120).toString() + 'px';
	    bodyHeight =  (document.documentElement.clientHeight - $('main-menu').getHeight() - 127).toString() + 'px';
	    bodyWidth = (document.documentElement.clientWidth - 50).toString() + 'px';
	    contentHeight =  (document.documentElement.clientHeight - $('main-menu').getHeight()).toString() + 'px';
	    
	}
	
	/*
	var emc = $('main-content');
	if (emc) {
	   emc.setStyle( { height: contentHeight } );
	   emc.setStyle( { width: bodyWidth } );
	}
	var emcf = $('main-content-footer');
	if (emcf) {
	//   emcf.setStyle( { top: footerTop } );
	}
	var emcb = $('main-content-body');
	if (emcb) {
	//	alert(bodyHeight)
	   emcb.setStyle( { height: bodyHeight } );
	   emcb.setStyle( { width: bodyWidth } );
	}
	*/
	
    }
	function showAdvancedMenu(event) {
	    //var element = Event.element(event);
	    if ($('advanced-dropdown')){
		$('advanced-dropdown').addClassName('shown');
	    }
	}
	function hideAdvancedMenu(event) {
	    //var element = Event.element(event);
	    if ($('advanced-dropdown')){
		$('advanced-dropdown').removeClassName('shown');
	    }
	}
	function highlightMenuItem(event) {
		var element = Event.element(event);
		
		while (element != document.body && element.nodeName.toLowerCase() != 'li') {
			element = element.parentNode;
		}
		if (element.nodeName.toLowerCase() != 'li') {
			return null;
		}
		
		element.addClassName('highlight');
	}
	function unhighlightMenuItem(event) {
		
		var element = Event.element(event);
		while (element != document.body && element.nodeName.toLowerCase() != 'li') {
			element = element.parentNode;
		}
		if (element.nodeName.toLowerCase() != 'li') {
			return null;
		}
		element.removeClassName('highlight');	
		
	}

function focusTableField(event) {
    var element = Event.element(event);
    element.addClassName('focus');
}

function blurTableField(event) {
    var element = Event.element(event);
    element.removeClassName('focus');
}

function focusBlurTextFields() {
    var textfields = $$('input.textfield');
    for(var i=0; i<textfields.length; i++) {
	textfields[i].observe('focus', focusTableField);
	textfields[i].observe('blur', blurTableField); 
    }
}

function enableSave() {
    if (! $('Save')) { return false; }
    if ($('Save').disabled) {
	myFabTabs.setWarn(true);
    }
    $('Save').disabled = false;
    $('Save').removeClassName('disabled');
}

function enableSaveOnChange() {
    myFabTabs.setWarn(false);
    if (! $('Save')) { return false; }
    $('Save').disabled = true;
    $('Save').addClassName('disabled');
    var inputs = $$('input');
    var selects = $$('select');
    for (var i=0; i<inputs.length; i++) {
	inputs[i].observe('change', enableSave);
	inputs[i].observe('keypress', enableSave);
    }
    for (var i=0; i<selects.length; i++) {
	selects[i].observe('change', enableSave);
	selects[i].observe('keypress', enableSave);
    }
}


function init() {

    //	Event.observe(window,'click', toggleGuide, false);
    
    
    //run resize on font-size change
    if( window.getComputedStyle ) {
	lastSize = window.getComputedStyle(document.documentElement,null).fontSize;
	setInterval(function () {
		var sz = window.getComputedStyle(document.documentElement,null).fontSize;
		if( sz != lastSize ) {
		    //do whatever fixes you wanted
		   // handleResize();
		    lastSize = sz;
		}
	    },1000);
    } else {
	//do the IE hackaround
    }



    if ($('advanced-menu')) {
	$('advanced-menu').observe('mouseover', showAdvancedMenu);
	$('advanced-menu').observe('mouseout', hideAdvancedMenu);
	
	var menuChildren = $('advanced-menu').getElementsByTagName('li');
	for(var i=0; i<menuChildren.length; i++) {
	    var thisMenuItem = menuChildren[i];
	    if (thisMenuItem.nodeName.toLowerCase() == "li") {
		Element.extend(thisMenuItem);
		thisMenuItem.observe('mouseover', highlightMenuItem);
		thisMenuItem.observe('mouseout', unhighlightMenuItem);
	    }
	}
    }
    focusBlurTextFields();
    enableSaveOnChange();
}
	
	function toggleGuide() {

	if ($('guide').getStyle('display') == 'block')	{
		$('guide').setStyle({
		  display: 'none'
		});
	} else {
		$('guide').setStyle({
		  display: 'block'
		});
	}
		//alert('here')
	}

var myFabTabs;
	
Event.observe(window,'load',function(){ myFabTabs = new Fabtabs('tabs'); },false);

Event.observe(window,'load', init, false);
//Event.observe(window,'load',handleResize,false);
//Event.observe(window,'resize',handleResize,false);
//Event.observe(window,'scroll',handleResize,false);


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
	    } else {
		Element.hide( children[i] );
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

var DhcpServerManager = {
    removeStaticEntry : function( rowId )
    {
        try {
            Element.remove( rowId );
        } catch ( e ) {
            /* ignore exceptions */
        }
    }
};

var DnsServerManager =
{
    removeStaticEntry : function( rowId )
    {
        try {
            Element.remove( rowId );
        } catch ( e ) {
            /* ignore exceptions */
        }
    }
};

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
