Ext.ns('Ung');
Ext.ns('Ung.Alpaca.Pages');
Ext.ns('Ung.Alpaca.Pages.Interface');

if ( Ung.Alpaca.Glue.hasPageRenderer( "interface", "e_list" )) {
    Ung.Alpaca.Util.stopLoading();
}

Ung.Alpaca.Pages.Interface.List = Ext.extend( Ung.Alpaca.PagePanel, {
    isDragAndDropInitialized : false,

    constructor : function( config )
    {
        var columns = [];
        if ( Ung.Alpaca.isAdvanced ) {
            columns.push({
                header : "Edit",
                width : 50,
                fixed : true,
                sortable : false,
                dataIndex : "id",
                align : "center",
                renderer : function( value, metadata, record )
                {
                    var url = "<a href='/alpaca/interface/e_config/" + value + "'>";
                    return String.format( "{0}edit{1}", url, "</a>" );
                }
            });
        }

        columns.push({
            header : "Name",
            width: 80,
            sortable: false,
            fixed : true,
            align : "center",
            dataIndex : "name"
        });

        columns.push({
            header : "Config Type",
            width: 80,
            fixed : true,
            align : "center",
            sortable: false,
            dataIndex : "config_type"
        });

        columns.push({
            header : "",
            width : 40,
            sortable : false,
            fixed : true,
            renderer : function( value, metadata, record )
            {
                return "<div class='ua-cell-draggable'/>";
            }
        });
        columns.push({
            header : "Physical Interface",
            width: 200,
            sortable: false,
            dataIndex : "interface_status_v2",
            renderer : this.renderInterfaceStatus.createDelegate( this )
        });

        columns.push({
            header : "MAC Address",
            width: 120,
            sortable: false,
            fixed : true,
            align : "center",
            renderer : this.renderMacAddress.createDelegate( this )
        });


        this.interfaceGrid = new Ung.Alpaca.EditorGridPanel({
            settings : config.settings,

            recordFields : [ "name", "duplex", "config_type", "os_name", "mac_address", "speed", 
                             "duplex", "index", "id", "interface_status_v2" ],
            selectable : false,
            selModel : new Ext.grid.RowSelectionModel({
                singleSelect : true
            }),
            enableDragDrop : true,
            ddGroup : 'interfaceDND',
            ddText : '',
            
            name : "interfaces",

            tbar : [{
                text : "Test Connectivity",
                handler : this.testConnectivity,
                scope : this
            },{
                text : "Refresh",
                handler : this.refreshInterfaceList,
                scope : this
            }],

            columns : columns
        });

        this.interfaceGrid.store.load();

        Ext.apply( this, {
            defaults : {
                xtype : "fieldset"
            },
            items : [{
                xtype : "label",
                html : "Interface List"
            }, this.interfaceGrid ]
        });
                
        Ung.Alpaca.Pages.Interface.List.superclass.constructor.apply( this, arguments );
    },

    /* Overload populate form */
    populateForm : function()
    {
        Ung.Alpaca.Pages.Interface.List.superclass.populateForm.apply( this, arguments );
        this.initializeDragAndDrop();
    },

    renderInterfaceStatus : function( value, metadata, record )
    {
        var divClass = "ua-cell-disabled-interface";
        var status = "unknown";
        
        if ( value.connected == "connected" ) {
            status = "connected";
            divClass = "ua-cell-enabled-interface";
        } else if ( value.connected == "disconnected" ) {
            status = "disconnected";
        }
        

        status += " " + value.speed +  " " + value.duplex;
        
        return "<div class='" + divClass + "'>" + record.data.os_name + " : " + status + "</div>";
    },

    renderMacAddress : function( value, metadata, record )
    {
        var ma = record.data.mac_address;
        
        /* Emacs was not happy when this was inline. */
        var matcher = /:/g;
        var text = ""
        if ( ma && ma.length > 0 ) {
            /* Build the link for the mac address */
            text = '<a target="_blank" href="http://standards.ieee.org/cgi-bin/ouisearch?' + 
                ma.substring( 0, 8 ).replace( matcher, "" ) + '">' + ma + '</a>';
         } else {
            text = "&nbsp;";
        }
        
        return text;
    },

    initializeDragAndDrop : function()
    {
        if ( this.isDragAndDropInitialized == false ) {
            new Ext.dd.DropTarget(this.interfaceGrid.getView().mainBody, {
                ddGroup : 'interfaceDND',
                copy : false,
                notifyDrop : this.onNotifyDrop.createDelegate( this )
            });
        }
        
        this.isDragAndDropInitialized = true;
    },

    onNotifyDrop : function(dd, e, data)
    {
        var sm = this.interfaceGrid.getSelectionModel();
        var rows=sm.getSelections();
        var cindex=dd.getDragData(e).rowIndex;
        
        if ( typeof cindex == "undefined" ) return false;
        if ( rows.length != 1 ) return false;
        
        var store = this.interfaceGrid.store;

        var row = store.getById(rows[0].id);
        var status = [ row.get( "os_name" ), 
                       row.get( "mac_address" ),
                       row.get( "vendor" ),
                       row.get( "bus" ),
                       row.get( "interface_status_v2" )]

        var c = 0;
        var data = [];
        var index = -1;

        store.each( function( currentRow ) {
            if ( currentRow == row ) index = c;
            data.push( [ currentRow.get( "os_name" ), 
                         currentRow.get( "mac_address" ),
                         currentRow.get( "vendor" ),
                         currentRow.get( "bus" ),
                         currentRow.get( "interface_status_v2" )]);
            c++;
        });

        if ( index == cindex ) return true;

        data.splice( index, 1 );
        data.splice( cindex, 0, status );

        store.each( function( currentRow ) {
            var d = data.shift();
            /* Need to set it to null, because extjs uses String(value) */
            /* to determine if the value has changed and that always    */
            /* equals [Object object] for a hash. */
            currentRow.set( "interface_status_v2", "");
            currentRow.set( "os_name", d.shift());
            currentRow.set( "mac_address", d.shift());
            currentRow.set( "vendor", d.shift());
            currentRow.set( "bus", d.shift());
            currentRow.set( "interface_status_v2", d.shift());
        });

        sm.clearSelections();

        application.enableSaveButton();

        return true;
    },


    saveMethod : "/interface/set_interface_list"
});

Ung.Alpaca.Pages.Interface.List.settingsMethod = "/interface/get_interface_list";
Ung.Alpaca.Glue.registerPageRenderer( "interface", "e_list", Ung.Alpaca.Pages.Interface.List );
