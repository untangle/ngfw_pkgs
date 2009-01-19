Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.grid');


/**
 * @class Ung.Alpaca.EditorGridPanel
 * @extends Ext.grid.EditorGridPanel
 * Build out an editable grid panel while specifying as few fields as possible.
 * @param {Object} config Configuration options
 */
Ung.Alpaca.EditorGridPanel = Ext.extend( Ext.grid.EditorGridPanel, {
    /* Set this to false for grids that do not need to saved */
    saveData : true,
    enableHdMenu : false,
    enableColumnMove: false,
    changedData : null,
    addedId : 0,

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
        this.changedData = {};
        Ung.Alpaca.Util.updateDefaults( config, {
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

        /* Append the selection model to the table */
        if ( config.selectable == true ) {
            var sm = new Ext.grid.CheckboxSelectionModel();
            config.columns = [sm].concat( config.columns );
            config.sm = sm;
        }

        this.buildToolbar( config );

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
            if ( !config.entries ) {
                config.entries = config.settings[config.name];
            }
            config.store = new Ext.data.Store({
                proxy : new Ext.data.MemoryProxy( config.entries ),
                reader : new Ext.data.ArrayReader( {}, this.record ),
                listeners : {
                    "update" : {
                        fn : function(store, record, operation) {
                            this.updateChangedData(record, "modified");
                        }.createDelegate(this)
                    }
                }                
            });
        }

        Ung.Alpaca.EditorGridPanel.superclass.constructor.apply( this, arguments );

        /* Untangle Alapca Grid type. */
        this.editorGridPanel = true;
    },
    afterRender : function() {
        Ung.Alpaca.EditorGridPanel.superclass.afterRender.call(this);
        this.getView().getRowClass = function(record, index, rowParams, store) {
            var id = record.get("id");
            if (id == null || id < 0) {
                return "grid-row-added";
            } else {
                var d = this.grid.changedData[id];
                if (d) {
                    if (d.op == "deleted") {
                        return "grid-row-deleted";
                    } else {
                        return "grid-row-modified";
                    }
                }
            }
            return "";
        }
    },

    buildToolbar : function( config )
    {
        if ( config.tbar ) {
            for ( var c = 0; c < config.tbar.length ; c++ ) {
                if ( config.tbar[c] == Ung.Alpaca.EditorGridPanel.AddButtonMarker ) {
                    config.tbar[c] = this.addButton();
                } else if ( config.tbar[c] == Ung.Alpaca.EditorGridPanel.DeleteButtonMarker ) {
                    config.tbar[c] = this.deleteButton();
                }
            }
        } else  {
            config.tbar = [ this.addButton(), this.deleteButton() ];
        }

        if ( config.tbar.length == 0 ) {
            config.tbar = null;
        }
    },
    
    addButton : function( config )
    {
        return {
            text : "Add",
            handler : this.addEntry,
            scope : this
        };
    },
    
    deleteButton : function( config )
    {
        return {
            text : "Delete",
            handler : this.deleteSelectedEntries,
            scope : this
        };
    },
    
    addEntry : function()
    {
        var entry = new this.record( Ext.decode(Ext.encode(this.recordDefaults)) );
        entry.set("id", this.genAddedId());
        this.stopEditing();
        this.store.insert( 0, entry );
        this.startEditing( 0, 0 );
        application.onFieldChange();
        this.updateChangedData(entry, "added");
    },
    genAddedId : function() {
        this.addedId--;
        return this.addedId;
    },

    updateFieldValue : function( settings )
    {
        if ( this.name == null || this.saveData == false ) {
            return;
        }

        var data = [];
        var entries = this.store.getRange();
        
        for ( var c = 0 ; c < entries.length ; c++ ) {
            data[c] = entries[c].data;
        }

        settings[this.name] = data;
    },
    
    deleteSelectedEntries : function()
    {
        this.stopEditing();
        application.onFieldChange();
        var sm=this.getSelectionModel();
        var selRecs=sm.getSelections();
        for(var i=selRecs.length-1;i>=0;i--) {
            //this.store.remove(selRecs[i]);
            this.updateChangedData(selRecs[i], "deleted");
        }
        sm.clearSelections();
        if ( Ext.fly(this.getView().getHeaderCell(0)).first().hasClass('x-grid3-hd-checker-on')){
            Ext.fly(this.getView().getHeaderCell(0)).first().removeClass('x-grid3-hd-checker-on');
        }         
    },
    isDirty : function() {
        // Test if there are changed data
        return Ung.Alpaca.Util.hasData(this.changedData);
    },
    // Update Changed data after an operation (modifyed, deleted, added)
    updateChangedData : function(record, currentOp) {
        if (!this.isDirty()) {
            var cmConfig = this.getColumnModel().config;
            for (i in cmConfig) {
                cmConfig[i].sortable = false;
            }
        }
        var id = record.get("id");
        var cd = this.changedData[id];
        if (cd == null) {
            this.changedData[id] = {
                op : currentOp,
                recData : record.data
            };
            if ("deleted" == currentOp) {
                var index = this.store.indexOf(record);
                this.getView().refreshRow(record);
            }
        } else {
            if ("deleted" == currentOp) {
                if ("added" == cd.op) {
                    this.store.remove(record);
                    this.changedData[id] = null;
                    delete this.changedData[id];
                } else {
                    this.changedData[id] = {
                        op : currentOp,
                        recData : record.data
                    };
                    this.getView().refreshRow(record);
                }
            } else {
                if ("added" == cd.op) {
                    this.changedData[id].recData = record.data;
                } else {
                    this.changedData[id] = {
                        op : currentOp,
                        recData : record.data
                    };
                }
            }
        }

    }
});

Ung.Alpaca.EditorGridPanel.AddButtonMarker = {};
Ung.Alpaca.EditorGridPanel.DeleteButtonMarker = {};

// Grid check column
Ung.Alpaca.grid.CheckColumn = Ext.extend(Object, {
    invert: false,
    constructor : function(config) {
        Ext.apply(this, config);
        if (!this.id) {
            this.id = Ext.id();
        }
        if (!this.width) {
            this.width = 55;
        }
        this.renderer = this.renderer.createDelegate(this);
    },
    init : function(grid) {
        this.grid = grid;
        this.grid.on('render', function() {
            var view = this.grid.getView();
            view.mainBody.on('mousedown', this.onMouseDown, this);
        }, this);
    },
    changeRecord : function(record) {
        record.set(this.dataIndex, !record.data[this.dataIndex]);
    },
    onMouseDown : function(e, t) {
        if (t.className && t.className.indexOf('x-grid3-cc-' + this.id) != -1) {
            e.stopEvent();
            var index = this.grid.getView().findRowIndex(t);
            var record = this.grid.store.getAt(index);
            this.changeRecord(record);
        }
    },

    renderer : function(value, metadata, record) {
        metadata.css += ' x-grid3-check-col-td';
        return '<div class="x-grid3-check-col' + ((this.invert?!value:value) ? '-on' : '') + ' x-grid3-cc-' + this.id + '">&#160;</div>';
    }
});
