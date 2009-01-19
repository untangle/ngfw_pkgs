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
        this.overrideGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,

            recordFields : [ "enabled", "writable", "path", "description" ],
            selectable : true,
            sortable : false,
            
            name : "file_overrides",

            recordDefaults : {
                enabled : false,
                writable : true,
                path : "",
                description : "[New Entry]"
            },

            columns : [{
                header : "On",
                width: 55,
                sortable: true,
                dataIndex : "enabled",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            },{
                header : "Writable",
                width: 55,
                sortable: true,
                dataIndex : "writable",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            },{
                header : "File Path",
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
                autoHeight : true,
                items : [{
                    xtype : "checkbox",
                    fieldLabel : "Send ICMP Redirects",
                    name : "alpaca_settings.send_icmp_redirects"
                    
                }]
            },{
                xtype : "label",
                html : "File Overrides"
            }, this.overrideGrid ]
        });
        
        Ung.Alpaca.Pages.Override.Index.superclass.initComponent.apply( this, arguments );
    },

    saveMethod : "/override/set_settings"
});

Ung.Alpaca.Pages.Override.Index.settingsMethod = "/override/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "override", "index", Ung.Alpaca.Pages.Override.Index );
