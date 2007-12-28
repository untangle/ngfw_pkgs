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
	//this.show(
	this.getInitialTab();//);
	this.menu.each(this.setupTab.bind(this));
    },
    setupTab : function(elm) {
	Event.observe(elm,'click',this.activate.bindAsEventListener(this),false)
    },
    activate :  function(ev) {
	var elm = Event.findElement(ev, "a");
	Event.stop(ev);
	this.show(elm);
	this.menu.without(elm).each(this.hide.bind(this));
    },
    hide : function(elm) {
	$(elm).removeClassName('active-tab');
	//$(this.tabID(elm)).removeClassName('active-tab-body');
    },
    show : function(elm) {
	$(elm).addClassName('active-tab');
	var up = new Ajax.Updater($('main-content'), $(elm).href, { evalScripts: true });
	//$(this.tabID(elm)).addClassName('active-tab-body');
    },
    //tabID : function(elm) {
    //return elm.href.match(/#(\w.+)/)[1];
    //},
    getInitialTab : function() {
    	if(document.location.href.match(/(\w.+)/)) {
    	    var loc = RegExp.$1;
    	    var elm = this.menu.find(function(value) { return value.href.match(/(\w.+)/)[1] == loc; });
    	    if (elm) {
	        $(elm).addClassName('active-tab');
		return elm
	    }
	}
	$(this.menu.first()).addClassName('active-tab');
	return this.menu.first();
    }
}

    var handleResize = function () {
	var footerTop = '800px';
	var contentHeight = '800px';
	if (window.innerHeight !== undefined) {
	    footerTop = (window.innerHeight - 86).toString() + 'px';
	    bodyHeight =  (window.innerHeight - 138).toString() + 'px';
	    contentHeight =  (window.innerHeight - 34).toString() + 'px';
	} else {
	    footerTop = (document.documentElement.clientHeight - 86).toString() + 'px';
	    bodyHeight =  (document.documentElement.clientHeight - 138).toString() + 'px';   
	    contentHeight =  (document.documentElement.clientHeight - 34).toString() + 'px';   
	}
	var emc = $('main-content');
	if (emc) {
	    emc.setStyle( { height: contentHeight } );
	}
	var emcf = $('main-content-footer');
	if (emcf) {
	    emcf.setStyle( { top: footerTop } );
	}
	var emcb = $('main-content-body');
	if (emcb) {
	    emcb.setStyle( { height: bodyHeight } );
	}
    }

Event.observe(window,'load',function(){ new Fabtabs('tabs'); },false);

Event.observe(window,'load',handleResize,false);
Event.observe(window,'resize',handleResize,false);


