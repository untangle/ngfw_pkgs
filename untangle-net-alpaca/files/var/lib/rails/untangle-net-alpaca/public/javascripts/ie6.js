//alpaca ie6-specific javascripts
//alert("ie6");



var handleResize_ie6 = function () {
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
	    footerTop = (document.documentElement.clientHeight - 120).toString() + 'px';
	    bodyHeight =  (document.documentElement.clientHeight - $('main-menu').getHeight() - 127).toString() + 'px';
	    bodyWidth = (document.documentElement.clientWidth).toString() + 'px';
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
	   emcf.setStyle( { top: footerTop } );
	}
	var emcb = $('main-content-body');
	if (emcb) {
	//	alert(bodyHeight)
	   emcb.setStyle( { height: bodyHeight } );
	   emcb.setStyle( { width: bodyWidth } );
	}
	*/
	
}

var showAdvancedMenu = function(event) {
    //var element = Event.element(event);
    if ($('advanced-dropdown')){
	$('advanced-dropdown').addClassName('shown');
    }
}
var hideAdvancedMenu = function(event) {
    //var element = Event.element(event);
    if ($('advanced-dropdown')){
	$('advanced-dropdown').removeClassName('shown');
    }
}
var highlightMenuItem = function(event) {
	var element = Event.element(event);
	
	while (element != document.body && element.nodeName.toLowerCase() != 'li') {
		element = element.parentNode;
	}
	if (element.nodeName.toLowerCase() != 'li') {
		return null;
	}
	
	element.addClassName('highlight');
}
var unhighlightMenuItem = function(event) {
	
	var element = Event.element(event);
	while (element != document.body && element.nodeName.toLowerCase() != 'li') {
		element = element.parentNode;
	}
	if (element.nodeName.toLowerCase() != 'li') {
		return null;
	}
	element.removeClassName('highlight');	
	
}

var init_ie6 = function() {
	   
	    //run resize on font-size change
	/*
	    if( window.getComputedStyle ) {
		alert('here');
		lastSize = window.getComputedStyle(document.documentElement,null).fontSize;
		setInterval(function () {
			var sz = window.getComputedStyle(document.documentElement,null).fontSize;
			if( sz != lastSize ) {
			    //do whatever fixes you wanted
			    handleResize_ie6();
			    lastSize = sz;
			}
		    },1000);
	    } else {
		//do the IE hackaround
	    }
	*/

		//<select>s show through overlayed elements in IE6
		//this replaces selects with Ext JS selects, which are actually text inputs
		replaceSelectBoxes(); 

		//handles background image rollover flicker in IE6
		try {
		  document.execCommand('BackgroundImageCache', false, true);
		} catch(e) {}


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
	
	  
}


configChange = function (e, target, options) {
	Interface.setConfigType();
}
replaceSelectBoxes = function () {
	
	//scrollbar needs to be reset in IE6. putting this here b/c it gets called on every page
	document.documentElement.scrollTop = 0;

	//replace select boxes
	var selects = $('main-content').getElementsByTagName('select');
	
	if (selects) {
			var selectIDs = new Array();
			if (selects.length > 0) {
				for ( var i = 0; i< selects.length; i++) {
					selectIDs.push(selects[i].id);
				}		
				for (var i = 0; i < selectIDs.length; i++) {
					
					var thisChild = $(selectIDs[i]);
					var thisWidth = thisChild.getWidth() + 10;
					if (thisWidth <= 10) {
						thisWidth = 150;
					}
					 	var converted = new Ext.form.ComboBox({
							    triggerAction: 'all',
							    transform: selectIDs[i],
							    width:thisWidth,
								height: 14,
							    forceSelection:true, 
								editable: false
							});
							
						//add change event listener for converted config_type elect
						if (selectIDs[i] == "config_type") {
							converted.on('select', configChange);
						}
				}	
			}
	}

}
	
Event.observe(window,'load', init_ie6, false);
//Event.observe(window,'load',handleResize_ie6,false);
//Event.observe(window,'resize',handleResize_ie6,false);
//Event.observe(window,'scroll',handleResize_ie6,false);	
//Event.observe(window,'scroll', test, false);
