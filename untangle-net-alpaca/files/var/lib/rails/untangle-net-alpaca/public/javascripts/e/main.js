
Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

Ung.Alpaca.Main = Ext.extend( Ext.TabPanel, {
    initComponent : function()
    {
        Ext.apply( this, {
            bbar : [{
                text : "Help"
            }, '->', {
                text : "Save"
            },{
                text : "Cancel"
            }],
            
            items : [{
                title : "Interfaces",
                page : { controller : "interface", page : "index" }
            },{
                title : "Port Forwards",
                page : { controller : "redirect", page : "index" }
            },{
                title : "Hostname",
                page : { controller : "hostname", page : "index" }
            },{
                title : "DHCP Server",
                page : { controller : "dhcp", page : "index" }
            },{
                title : "DNS Server",
                page : { controller : "dns", page : "index" }
            },{
                title : "QoS",
                page : { controller : "qos", page : "index" }
            }]
        });

        Ung.Alpaca.Main.superclass.initComponent.apply( this, arguments );

        this.addListener( 'beforetabchange', this.onBeforeTabChange, this );
        this.addListener( 'tabchange', this.onTabChange, this );
    },

    onBeforeTabChange : function( __, newTab, currentTab )
    {
        /* Clear out anything on the current tab */
        if ( currentTab != null ) {
            currentTab.getEl().update( "" );
        }        
    },

    onTabChange : function( __, currentTab )
    {
        var el = currentTab.getEl();
        
        Ung.Alpaca.Util.loadScript( currentTab.page, Ung.Alpaca.Application.completeLoadPage.createDelegate(  Ung.Alpaca.Application, [ currentTab.page, currentTab ], true ));                   
    }
});
