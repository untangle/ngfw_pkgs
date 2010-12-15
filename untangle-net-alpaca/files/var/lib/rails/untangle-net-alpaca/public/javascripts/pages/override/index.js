Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Override');

if ( Ung.Alpaca.Glue.hasPageRenderer( "override", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Override.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function( )
    {
        var enabledColumn = new Ung.Alpaca.grid.CheckColumn({
            header : this._( "On" ),
            dataIndex : 'enabled',
            sortable: false,
            fixed : true
        });

        var writableColumn = new Ung.Alpaca.grid.CheckColumn({
            header : this._( "Writable" ),
            dataIndex : 'writable',
            sortable: false,
            fixed : true
        });

        this.overrideGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,

            recordFields : [ "id", "enabled", "writable", "path", "description" ],
            sortable : false,
            hasReorder : true,
            hasDelete : true,
            
            name : "file_overrides",

            recordDefaults : {
                enabled : false,
                writable : true,
                path : "",
                description : this._( "[New Entry]" )
            },

            plugins : [ enabledColumn, writableColumn ],

            columns : [enabledColumn, writableColumn, {
                header : this._( "File Path" ),
                width: 200,
                sortable: true,
                dataIndex : "path",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            }]
        });

        this.overrideGrid.store.load();
        
        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                xtype : "label",
                cls: 'page-header-text',
                html : this._( "Overrides" )
            },{
                xtype : "label",
                cls: 'label-section-heading-2',
                html : this._( "File Overrides" )
            }, this.overrideGrid ]
        });
        
        Ung.Alpaca.Pages.Override.Index.superclass.initComponent.apply( this, arguments );
    },

    saveMethod : "/override/set_settings"
});

Ung.Alpaca.Pages.Override.Index.settingsMethod = "/override/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "override", "index", Ung.Alpaca.Pages.Override.Index );
