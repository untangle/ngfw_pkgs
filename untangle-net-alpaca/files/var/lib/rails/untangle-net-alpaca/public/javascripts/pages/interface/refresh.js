Ext.ns('Ung');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Interface');

if ( Ung.Alpaca.Glue.hasPageRenderer( "interface", "refresh" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Interface.Refresh = Ext.extend( Ung.Alpaca.PagePanel, {
    initComponent : function()
    {
        var items = [];
        
        if ( this.settings["new_interfaces"].length > 0 ) {
            var grid = new Ung.Alpaca.EditorGridPanel({
                settings : this.settings,
                recordFields : [ "os_name", "vendor", "mac_address" ],
                
                /* Name must set in order to get and set the settings */
                name : "new_interfaces",

                tbar : [],
                
                columns : [{
                    header : this._( "Name" ),
                    width: 80,
                    sortable: true,
                    dataIndex : "os_name"
                },{
                    header : this._( "Vendor" ),
                    width: 200,
                    sortable: true,
                    dataIndex : "vendor"
                },{
                    header : this._( "MAC Address" ),
                    width: 100,
                    sortable: true,
                    dataIndex : "mac_address"
                }]
            });

            grid.store.load();

            items.push({
                xtype : 'label',
                cls : 'label-section-heading',
                html : String.format( this._( "{0}The following interfaces have been added.{1}" ),
                                      "<p>", "</p>" )
            });

            items.push( grid );
        }

        if ( this.settings["deleted_interfaces"].length > 0 ) {
            var grid = new Ung.Alpaca.EditorGridPanel({
                settings : this.settings,
                recordFields : [ "os_name", "vendor", "mac_address" ],
                
                /* Name must set in order to get and set the settings */
                name : "deleted_interfaces",

                tbar : [],
                
                columns : [{
                    header : this._( "Name" ),
                    width: 80,
                    sortable: true,
                    dataIndex : "os_name"
                },{
                    header : this._( "Vendor" ),
                    width: 200,
                    sortable: true,
                    dataIndex : "vendor"
                },{
                    header : this._( "MAC Address" ),
                    width: 100,
                    sortable: true,
                    dataIndex : "mac_address"
                }]
            });

            grid.store.load();

            items.push({
                xtype : 'label',
                cls : 'label-section-heading',
                html : String.format( this._( "{0}The following interfaces have been removed.{1}" ),
                                      "<p>", "</p>" )
            });

            items.push( grid );
        }

        if ( items.length == 0 ) {
            items.push({
                xtype : "label",
                cls : 'label-section-heading',                    
                html : this._( "Unable to detect any removed or installed network interfaces." )
            });
        } else {
            items = [{
                xtype : "label",
                cls : 'ua-message-warning',                    
                html : String.format( this._( "{0}A change in your physical interfaces has been detected, Click {1}Save{2} to commit the changes.{3}" ), "<p>","<b>","</b>","</p>" )
            }].concat( items );

            this.enableSave = true;
        }

        Ext.apply( this, {
            items : items
        });

        Ung.Alpaca.Pages.Interface.Refresh.superclass.initComponent.apply( this, arguments );
    },
        
    saveMethod : "/interface/set_interface_list"
});

Ung.Alpaca.Pages.Interface.Refresh.settingsMethod = "/interface/get_interface_list";
Ung.Alpaca.Glue.registerPageRenderer( "interface", "refresh", Ung.Alpaca.Pages.Interface.Refresh );
