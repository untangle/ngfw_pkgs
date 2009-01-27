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
                description : this._( "[New Entry]" )
            },

            columns : [{
                header : this._( "On" ),
                width: 55,
                sortable: true,
                dataIndex : "enabled",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            },{
                header : this._( "Writable" ),
                width: 55,
                sortable: true,
                dataIndex : "writable",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            },{
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
            items : [
            {
                autoHeight : true,
                title: this._('Overrides'),
                items : [{
                    xtype : "checkbox",
                    fieldLabel : this._( "Send ICMP Redirects" ),
                    name : "alpaca_settings.send_icmp_redirects",
                    itemCls:'label-width-2'
                    
                }]
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
