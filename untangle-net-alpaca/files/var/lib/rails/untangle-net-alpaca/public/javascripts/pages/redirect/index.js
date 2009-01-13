Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Redirect');

if ( Ung.Alpaca.Glue.hasPageRenderer( "redirect", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Redirect.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    constructor : function( config )
    {
        this.userRulesGrid = new Ung.Alpaca.EditorGridPanel({
            settings : config.settings,

            recordFields : [ "enabled", "system_id", "new_ip", "new_enc_id", "filter", "description", "is_custom" ],
            selectable : true,
            sortable : false,
            
            name : "user_redirects",

            tbar : [ Ung.Alpaca.EditorGridPanel.AddButtonMarker,
                     Ung.Alpaca.EditorGridPanel.DeleteButtonMarker, {
                         text : "Edit",
                         handler : this.editEntry,
                         scope : this
                     }],

            recordDefaults : {
                enabled : true,
                system_id : null,
                new_ip : "1.2.3.4",
                new_enc_id : 0,
                filter : "",
                description : "[New Entry]",
                is_custom : false
            },

            columns : [{
                header : "On",
                width: 55,
                sortable: false,
                dataIndex : "enabled"
            },{
                header : "Description",
                width: 200,
                sortable: false,
                dataIndex : "description",
                editor : new Ext.form.TextField({
                    allowBlank : false 
                })
            }]
        });

        this.userRulesGrid.store.load();

        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                xtype : "label",
                html : "Port Forwards"
            }, this.userRulesGrid ]
        });
        
        Ung.Alpaca.Pages.Redirect.Index.superclass.constructor.apply( this, arguments );
    },

    saveMethod : "/redirect/set_settings",
});

Ung.Alpaca.Pages.Redirect.Index.settingsMethod = "/redirect/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "redirect", "index", Ung.Alpaca.Pages.Redirect.Index );
