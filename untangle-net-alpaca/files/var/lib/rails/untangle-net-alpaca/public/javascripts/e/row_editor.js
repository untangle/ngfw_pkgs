Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

Ung.Alpaca.RowEditor = Ext.extend(Ext.Window, {
    // the editor grid
    modal : true,    
    grid : null,
    // function called by close action
    closeAction : 'cancelAction',
    // input lines for standard input lines (text, checkbox, textarea, ..)
    inputLines : null,
    // label width for row editor input lines
    panelLabelWidth: null,
    // the record currently edit
    record : null,
    // initial record data
    initialRecordData : null,
    initComponent : function() {
        if (!this.height) {
            this.height=400;
        }
        if (!this.width) {
            this.width=600;
        }
        if (this.title == null) {
            this.title = 'Edit';
        }
        if (this.panelLabelWidth == null) {
            this.panelLabelWidth = 150;
        }
        if(this.bbar==null) {
            this.bbar=['->',{
                name : 'Cancel',
                id: "cancel_"+this.getId(),
                iconCls : 'cancel-icon',
                text : 'Cancel',
                handler : function() {
                    this.cancelAction();
                }.createDelegate(this)
            },'-',{
                name : 'Update',
                iconCls : 'save-icon',
                text : 'Update',
                handler : function() {
                    this.updateAction();
                }.createDelegate(this)
            },'-'];
        }
        this.items = new Ext.Panel({
            anchor: "100% 100%",
            layout:"form",
            buttonAlign : 'right',
            border : false,
            bodyStyle : 'padding:10px 10px 0px 10px;',
            autoScroll: true,
            defaults : {
                xtype : "fieldset",
                autoHeight : true,                
                selectOnFocus : true,
                msgTarget : 'side',
                labelWidth : this.panelLabelWidth
            },
            items : this.panelItems
        });
        //this.inputLines=this.items.items.getRange();
        Ung.Alpaca.RowEditor.superclass.initComponent.call(this);
    },
    show : function() {
        Ung.Alpaca.RowEditor.superclass.show.call(this);
        this.center();
    },
    // populate is called whent a record is edited, tot populate the edit window
    populate : function(record) {
        this.record = record;
        this.initialRecordData = Ext.encode(record.data);
        /* Iterate the panel and line up fields with their values. */
        this.items.each( this.populateFieldValue.createDelegate( this, [ this.record ], true ));

        /* Register the event handler with every field. */
        //this.items.each( this.addEnableSaveHandler.createDelegate( this ));
    },
    
    /* Fill in the value for a field */
    populateFieldValue : function( item, index, length, record )
    {
        if ( item.getName ) {
            var value = null;
            if(item.dataIndex!=null) {
                value=record.get(item.dataIndex);
            }

            switch ( item.xtype ) {
            case "textfield":
                value = ( value == null ) ? "" : value;
                item.setValue( value );
                break;
                
            case "checkbox":
                value =  ( value == null ) ? "" : value;
                item.setValue( value );
                break;

            case "combo":
                if ( value != null ) {
                    item.setValue( value );
                }
                break;                
            }
        }

        /* Recurse to children */
        if ( item.items ) {
            item.items.each( this.populateFieldValue.createDelegate( this, [ record ], true ));
        }
    },
    
    addEnableSaveHandler : function( item, index )
    {
        if ( item.addListener && item.xtype ) {
            var event = "change";
            
            switch ( item.xtype ) {
            case "checkbox":
                event = "check"
                break;

                /* No point registering events on labels. */
            case "label":
                event = null;
            default:
            }

            if ( item.editorGridPanel == true ) {
                event = "afteredit"
            }
            
            if ( event != null ) {
                item.addListener( event, application.onFieldChange, application );
            }
        }

        if ( item.items ) {
            item.items.each( this.addEnableSaveHandler.createDelegate( this ));
        }
    },
    
    // check if the form is valid;
    // this is the default functionality which can be overwritten
    isFormValid : function() {
        /*
        for (var i = 0; i < this.inputLines.length; i++) {
            var inputLine = this.inputLines[i];
            if (!inputLine.isValid()) {
                return false;
            }
        }*/
        return true;
    },
    // updateAction is called to update the record after the edit
    updateAction : function() {
        if (this.isFormValid()) {
            if (this.record !== null) {
                //TODO
                
            }
            this.hide();
        } else {
            Ext.MessageBox.alert('Warning', "The form is not valid!");
        }
    },
    // to override if needed
    isDirty : function() {
        return false;
    },
    cancelAction : function() {
        if (this.isDirty()) {
            Ext.MessageBox.confirm('Warning', 'There are unsaved settings which will be lost. Do you want to continue?', 
                function(btn) {
                    if (btn == 'yes') {
                        this.closeWindow();
                    }
                }.createDelegate(this));
        } else {
            this.closeWindow();
        }
    },
    // the close window action
    // to override
    closeWindow : function() {
        this.hide();
    }
});
