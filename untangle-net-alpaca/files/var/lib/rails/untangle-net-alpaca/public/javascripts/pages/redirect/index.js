Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Redirect');

if ( Ung.Alpaca.Glue.hasPageRenderer( "redirect", "index" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Redirect.Index = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function()
    {
        var enabledColumn = new Ung.Alpaca.grid.CheckColumn({
            //invert: true,
            header : "On",
            dataIndex : 'enabled',
            sortable: false,
            fixed : true
        });
        this.userRulesGrid = new Ung.Alpaca.EditorGridPanel({
            settings : this.settings,

            recordFields : ["id", "enabled", "system_id", "new_ip", "new_enc_id", "filter", "description", "is_custom" ],
            selectable : true,
            sortable : false,
            hasEdit:true,
            hasReorder: true,
            
            rowEditor : new Ung.Alpaca.RowEditor({
                panelItems: [{
                    xtype : "fieldset",
                    autoHeight : true,
                    items:[{
                        xtype: "checkbox",
                        fieldLabel: "Enabled",
                        dataIndex: "enabled"
                    }, {
                        xtype: "textfield",
                        fieldLabel: "Description",
                        dataIndex: "description",
                        width: 360
                    }]
                }, {
                    xtype : "fieldset",
                    autoHeight : true,
                    title: "If all of the following conditions are met:"
                }, {
                    xtype : "fieldset",
                    autoHeight : true,
                    title: "Forward traffic to the following location",
                    items:[{
                        xtype: "textfield",
                        fieldLabel: "New Destination",
                        dataIndex: "new_ip",
                        width: 150
                    }, {
                        xtype: "textfield",
                        fieldLabel: "New Port (optional)",
                        dataIndex: "new_enc_id",
                        width: 150
                        
                    }]
                }]
            }),
            name : "user_redirects",

            tbar : [ Ung.Alpaca.EditorGridPanel.AddButtonMarker,
                     Ung.Alpaca.EditorGridPanel.DeleteButtonMarker],

            recordDefaults : {
                enabled : true,
                system_id : null,
                new_ip : "1.2.3.4",
                new_enc_id : 0,
                filter : "",
                description : "[New Entry]",
                is_custom : false
            },
            plugins: [enabledColumn],
            columns : [enabledColumn, {
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
        
        Ung.Alpaca.Pages.Redirect.Index.superclass.initComponent.apply( this, arguments );
    },

    saveMethod : "/redirect/set_settings"
});

Ung.Alpaca.Pages.Redirect.Index.settingsMethod = "/redirect/get_settings";
Ung.Alpaca.Glue.registerPageRenderer( "redirect", "index", Ung.Alpaca.Pages.Redirect.Index );
