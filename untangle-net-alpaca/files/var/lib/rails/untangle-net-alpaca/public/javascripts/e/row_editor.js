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
    layout : 'anchor',
    draggable : false,
    resizable : false,
    defaults: {
        anchor: '100% 100%',
        autoScroll: true,
        autoWidth : true
    },    
    initComponent : function() {
        if (!this.height) {
            this.height=500;
        }
        if (!this.width) {
            this.width=700;
        }
        if (this.title == null) {
            this.title = 'Edit';
        }
        if (this.panelLabelWidth == null) {
            this.panelLabelWidth = 150;
        }
        if(this.bbar==null) {
            this.bbar=[{
                iconCls : 'icon-help',
                text : Ung.Alpaca.Util._('Help'),
                handler : function() {
                    this.onHelp();
                }.createDelegate(this)
            },'->',{
                name : Ung.Alpaca.Util._('Cancel'),
                id: "cancel_"+this.getId(),
                iconCls : 'cancel-icon',
                text : Ung.Alpaca.Util._('Cancel'),
                handler : function() {
                    this.cancelAction();
                }.createDelegate(this)
            },'-',{
                id: "update_"+this.getId(),
                disabled : true,
                iconCls : 'save-icon',
                text : Ung.Alpaca.Util._('Update'),
                handler : function() {
                    this.updateAction();
                }.createDelegate(this)
            },'-'];
        }
        this.items = new Ext.Panel({
            anchor: "100% 100%",
            autoScroll: true,                
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
    onRender : function(container, position) {
        Ung.Alpaca.RowEditor.superclass.onRender.call(this, container, position);

        /* Register the event handler with every field. */
        this.items.each( this.addEnableUpdateHandler.createDelegate( this ));
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

        var updateButton=Ext.getCmp("update_"+this.getId());
        if(updateButton) {
            updateButton.disable();
        }
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
            case "rulebuilder":
                value = ( value == null ) ? "" : value;
                item.setValue( value );
                break;
            case "checkbox":
                value =  ( value == null ) ? false : value;
                if ( item.invert == true ) value = !value;
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
    
    addEnableUpdateHandler : function( item, index )
    {
        if ( item.addListener && item.xtype ) {
            var event = "change";
            
            switch ( item.xtype ) {
            case "checkbox":
                event = "check"
                break;
            case "rulebuilder" :
                event = "afteredit"
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
                item.addListener( event, this.onFieldChange, this );
            }
        }

        if ( item.items ) {
            item.items.each( this.addEnableUpdateHandler.createDelegate( this ));
        }
    },
    onHelp : function () {
        Ung.Alpaca.Util.implementMe("Help on Row Editor");
    },
    onFieldChange : function()
    {
        this.enableUpdateButton();
    },
    enableUpdateButton : function()
    {
        var updateButton=Ext.getCmp("update_"+this.getId());
        if(updateButton) {
            updateButton.enable();
        }
    },
    
    // check if the form is valid;
    // this is the default functionality which can be overwritten
    isFormValid : function() {
        return true;
    },
    // updateAction is called to update the record after the edit
    updateAction : function() {
        if (this.isFormValid()) {
            if (this.record !== null) {
                this.items.each( this.updateFieldValue.createDelegate( this, [ this.record ], true ))
            }
            this.hide();
            application.onFieldChange();
        } else {
            Ext.MessageBox.alert('Warning', "The form is not valid!");
        }
    },
    
    /* Update the settings with the values from the fields. */
    updateFieldValue : function( item, index, length, record )
    {
        if ( item.updateFieldValue ) {
            item.updateFieldValue( record );
        } else if ( item.getName ) {
            var value = null;

            switch ( item.xtype ) {
            case "textfield":
            case "combo":
            case "rulebuilder":
                value = item.getValue();
                break;                

            case "checkbox":
                value = item.getValue();
                if ( item.invert ) {
                    value = !value;
                }
            }
            if ( value != null && item.dataIndex!=null) {
                record.set(item.dataIndex, value);
            }
        }

        /* Recurse to children */
        if ( item.items ) {
            item.items.each( this.updateFieldValue.createDelegate( this, [ record ], true ));
        }
    },
    
    cancelAction : function() {
        var updateButton=Ext.getCmp("update_"+this.getId());
        if (updateButton && !updateButton.disabled ) {
            var m = String.format( Ung.Alpaca.Util._( "{0}Leaving this page will lose unsaved changes.{1}{0}Click 'Continue' to proceed and lose changes,{1}{0}or 'Cancel' to stay on this page.{1}" ), "<p>", "</p>" );
            Ext.MessageBox.show({
                title: Ung.Alpaca.Util._( "Warning" ),
                msg: m,
                width : 300,
                buttons : {
                    ok : Ung.Alpaca.Util._("Continue"),
                    cancel : Ung.Alpaca.Util._("Cancel")
                },
                fn : function(buttonId) {
                    if ( buttonId == "ok" ) {
                        this.closeWindow();
                    }
                }.createDelegate(this),
                icon : Ext.MessageBox.WARNING
            });
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
Ext.reg('roweditor', Ung.Alpaca.RowEditor);