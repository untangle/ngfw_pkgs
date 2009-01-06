Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

/**
 * @class Ung.Alpaca.Toolbar
 * @extends Ext.Toolbar
 * The toolbar that appears at the top of the application.
 * @constructor
 * Create a new toolbar
 * @param {Object} config Configuration options
 */
Ung.Alpaca.Toolbar = Ext.extend( Ext.Toolbar, {
    constructor : function( config )
    {
        var menu = this.buildMenu();
        Ext.apply( this, {
            buttons : this.buildMenu()
        });

        Ung.Alpaca.Toolbar.superclass.constructor.apply( this, arguments );
    },

    buildMenu : function()
    {
        var buttons = [];

        for ( var c = 0 ; c < Ung.Alpaca.BasicMenuData.length ; c++ ) {
            buttons.push( this.buildButton( Ung.Alpaca.BasicMenuData[c], {
                xtype : "tbbutton"
            }));
        }
        
        buttons.push( "->" );
        
        if ( Ung.Alpaca.AdvancedMenuData.length == 1 ) {
            var menuData = Ung.Alpaca.AdvancedMenuData[0];

            buttons.push( this.buildButton( Ung.Alpaca.AdvancedMenuData[0], {
                xtype : "tbbutton"
            }));
        } else {
            var menuItems = [];
            for ( var c = 0 ; c < Ung.Alpaca.AdvancedMenuData.length ; c++ ) {
                menuItems[c] = this.buildButton( Ung.Alpaca.AdvancedMenuData[c] );
            }
            
            buttons.push( new Ext.Toolbar.MenuButton({
                text : "Advanced",
                menu : { items : menuItems }
            }));
        }

        return buttons;
    },

    onChangeQueryPath : function( button, event )
    {
        application.switchToQueryPath( button.queryPath );
    },

    buildButton : function( menuData, config )
    {
        if ( config == null ) {
            config = {};
        }

        return Ext.apply( config, {
            text : menuData.name,
            queryPath : menuData.queryPath,
            handler : this.onChangeQueryPath,
            scope : this
        });
    }
});
