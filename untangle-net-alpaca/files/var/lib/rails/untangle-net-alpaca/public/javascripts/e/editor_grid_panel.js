Ext.ns('Ung');
Ext.ns('Ung.Alpaca');


/**
 * @class Ung.Alpaca.EditorGridPanel
 * @extends Ext.grid.EditorGridPanel
 * Build out an editable grid panel while specifying as few fields as possible.
 * @param {Object} config Configuration options
 */
Ung.Alpaca.EditorGridPanel = Ext.extend( Ext.grid.EditorGridPanel, {
    /**
     * @cfg {Array} recordFields An array of strings containing the fields to create the default 
     * record.  Otherwise, you can define your own record.
     * @cfg {Ext.data.Record} record The record to use for each row.  
     *   This will be created using {@link #recordFields} if one is not specified.
     * @cfg {Ext.data.Store} store to use the read out the data.  This
     *   will be created automatically, if one is not specified.
     * @cfg {Array} entries Data to place into the automatically created {@link #store}.
     */
    constructor : function( config )
    {
        Ung.Alpaca.Util.updateDefaults( config, {
            sm : function() { return new Ext.grid.RowSelectionModel({singleSelect:true}) },
            width : 620,
            height : 220,
            frame : false,
            iconCls : "icon-grid",
            clicksToEdit : 1,
            stripeRows : true,
            viewConfig : { 
                forceFit : true
            }
        });

        /* Build a record. */
        if ( config.record == null && Ext.isArray( config.recordFields )) {
            var fields = [];
            for ( var c = 0 ; c < config.recordFields.length ; c++ ) {
                var field = config.recordFields[c];
                fields[c] = { name : field, mapping : field };
            }

            this.record = Ext.data.Record.create( fields );
        } else {
            this.record = config.record;
        }

        /* Now build a store */
        if (( config.store == null ) && ( this.record != null )) {
            config.store = new Ext.data.Store({
                proxy : new Ext.data.MemoryProxy( config.entries ),
                reader : new Ext.data.ArrayReader( {}, this.record )
            });
        }

        Ung.Alpaca.EditorGridPanel.superclass.constructor.apply( this, arguments );
    }
    
});
