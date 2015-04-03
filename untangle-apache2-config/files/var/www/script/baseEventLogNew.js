//Event Log class
Ext.define("Ung.grid.BaseEventLog", {
    extend: "Ext.grid.Panel",
    hasSelectors: null,
    hasAutoRefresh: null,
    reserveScrollbar: true,
    // refresh on activate Tab (each time the tab is clicked)
    refreshOnActivate: true,
    // for internal use
    rpc: null,
    helpSource: 'event_log',
    loadMask: true,
    stateful: true,
    constructor: function(config) {
        this.subCmps = [];
        var modelName='Ung.EventLog.Model-' + Ext.id();
        Ext.define(modelName, {
            extend: 'Ext.data.Model',
            fields: config.fields
        });
        config.modelName = modelName;
        this.callParent(arguments);
    },
    beforeDestroy: function() {
        Ext.destroy(this.subCmps);
        this.callParent(arguments);
    },
    initComponent: function() {
        var me = this;
        this.rpc = {
            repository: {}
        };
        if(!this.title) {
            this.title = i18n._('Event Log');
        }
        Ext.applyIf(this, {
            name: 'EventLog',
            plugins: [],
            features: [],
            viewConfig: {}
        });
        this.stateId = 'eventLog-' +
            ( this.initialConfig.selectedApplication ?
              this.initialConfig.selectedApplication + '-' + this.initialConfig.sectionName :
              this.initialConfig.helpSource );
        this.viewConfig.enableTextSelection = true;
        this.store=Ext.create('Ext.data.Store', {
            model: this.modelName,
            data: [],
            statefulFilters: false,
            proxy: {
                type: 'memory',
                reader: {
                    type: 'json',
                    rootProperty: 'list'
                }
            }
        });
        this.dockedItems = [{
            xtype: 'toolbar',
            dock: 'top',
            items: [i18n._('Filter:'), {
                xtype: 'textfield',
                name: 'searchField',
                hideLabel: true,
                width: 130,
                listeners: {
                    change: {
                        fn: function() {
                            this.filterFeature.updateGlobalFilter(this.searchField.getValue(), this.caseSensitive.getValue());
                        },
                        scope: this,
                        buffer: 600
                    }
                }
            }, {
                xtype: 'checkbox',
                name: 'caseSensitive',
                hideLabel: true,
                margin: '0 4px 0 4px',
                boxLabel: i18n._('Case sensitive'),
                handler: function() {
                    this.filterFeature.updateGlobalFilter(this.searchField.getValue(),this.caseSensitive.getValue());
                },
                scope: this
            }, {
                xtype: 'button',
                iconCls: 'icon-clear-filter',
                text: i18n._('Clear Filters'),
                tooltip: i18n._('Filters can be added by clicking on column headers arrow down menu and using Filters menu'),
                handler: Ext.bind(function () {
                    this.clearFilters();
                    this.searchField.setValue("");
                }, this)
            }, {
                text: i18n._('Reset View'),
                tooltip: i18n._('Restore default columns positions, widths and visibility'),
                handler: Ext.bind(function () {
                    Ext.state.Manager.clear(this.stateId);
                    this.reconfigure(null, this.getInitialConfig("columns"));
                }, this)
            },'->',{
                xtype: 'button',
                text: i18n._('Export'),
                name: "Export",
                tooltip: i18n._('Export Events to File'),
                iconCls: 'icon-export',
                handler: Ext.bind(this.exportHandler, this)
            }]
        }, {
            xtype: 'toolbar',
            dock: 'bottom',
            items: [{
                xtype: 'tbtext',
                hidden: !this.hasSelectors,
                name: 'querySelector',
                text: ''
            }, {
                xtype: 'tbtext',
                hidden: !this.hasSelectors,
                name: 'rackSelector',
                text: ''
            }, {
                xtype: 'tbtext',
                hidden: !this.hasSelectors,
                name: 'limitSelector',
                text: ''
            }, {
                xtype: 'button',
                text: i18n._('From'),
                initialLabel:  i18n._('From'),
                hidden: !this.hasTimestampFilter,
                width: 132,
                tooltip: i18n._('Select Start date and time'),
                handler: function(button) {
                    me.startDateWindow.buttonObj=button;
                    me.startDateWindow.show();
                },
                scope: this
            },{
                xtype: 'tbtext',
                hidden: !this.hasTimestampFilter,
                text: '-'
            }, {
                xtype: 'button',
                text: i18n._('To'),
                initialLabel:  i18n._('To'),
                hidden: !this.hasTimestampFilter,
                width: 132,
                tooltip: i18n._('Select End date and time'),
                handler: function(button) {
                    me.endDateWindow.buttonObj=button;
                    me.endDateWindow.show();
                },
                scope: this
            },
            {
                xtype: 'button',
                text: i18n._('Refresh'),
                name: "refresh",
                tooltip: i18n._('Flush Events from Memory to Database and then Refresh'),
                iconCls: 'icon-refresh',
                handler:function () {
                    this.refreshHandler(true);
                },
                scope: this
            }, {
                xtype: 'button',
                hidden: !this.hasAutoRefresh,
                name: 'auto_refresh',
                text: i18n._('Auto Refresh'),
                enableToggle: true,
                pressed: false,
                tooltip: i18n._('Auto Refresh every 5 seconds'),
                iconCls: 'icon-autorefresh',
                handler: Ext.bind(function(button) {
                    if(button.pressed) {
                        this.startAutoRefresh();
                    } else {
                        this.stopAutoRefresh();
                    }
                }, this)
            }]
        }];

        for (var i in this.columns) {
            var col=this.columns[i];
            if (col.sortable === undefined) {
                col.sortable = true;
            }
            col.initialSortable = col.sortable;
            if (col.dataIndex !== undefined && col.filter === undefined) {
                if (col.dataIndex != 'time_stamp') {
                    col.filter = { type: 'string' };
                } else {
                    col.filter = { type: 'string' };
                    /* TODO: ext5
                    col.filter = {
                        type: 'datetime',
                        dataIndex: 'time_stamp',
                        date: {
                            format: 'Y-m-d'
                        },
                        time: {
                            format: 'H:i:s A',
                            increment: 30
                        },
                        validateRecord : function (record) {
                            var me = this,
                            key,
                            pickerValue,
                            val1 = record.get(me.dataIndex);
                            var val = new Date(val1.time);
                            if(!Ext.isDate(val)){
                                return false;
                            }
                            val = val.getTime();
                            for (key in me.fields) {
                                if (me.fields[key].checked) {
                                    pickerValue = me.getFieldValue(key).getTime()-i18n.timeoffset;
                                    if (key == 'before' && pickerValue <= val) {
                                        return false;
                                    }
                                    if (key == 'after' && pickerValue >= val) {
                                        return false;
                                    }
                                    if (key == 'on' && (pickerValue-43200000 > val || val > pickerValue+43200000)) { //on piker value for day (selected time -/+12horus)
                                        return false;
                                    }
                                }
                            }
                            return true;
                        }
                    };*/
                }
            }
            if( col.stateId === undefined ){
                col.stateId = col.dataIndex;
            }
        }
        
        this.plugins.push('gridfilters');
        this.filterFeature=Ext.create('Ung.grid.feature.GlobalFilter', {});
        this.features.push(this.filterFeature);

        this.callParent(arguments);
        this.searchField=this.down('textfield[name=searchField]');
        this.caseSensitive = this.down('checkbox[name=caseSensitive]');
    },
    autoRefreshEnabled: false,
    startAutoRefresh: function(setButton) {
        this.autoRefreshEnabled=true;
        var columnModel=this.columns;
        this.getStore().sort(columnModel[0].dataIndex, "DESC");
        for (var i in columnModel) {
            columnModel[i].sortable = false;
            }
        if(setButton) {
            this.down('button[name=auto_refresh]').toggle(true);
        }
        this.down('button[name=refresh]').disable();
        this.autoRefreshList();
    },
    stopAutoRefresh: function(setButton) {
        this.autoRefreshEnabled=false;
        var columnModel=this.columns;
        for (var i in columnModel) {
            columnModel[i].sortable = columnModel[i].initialSortable;
        }
        if(setButton) {
            this.down('button[name=auto_refresh]').toggle(false);
        }
        this.down('button[name=refresh]').enable();
    },
    // return the list of columns in the event long as a comma separated list
    getColumnList: function() {
        var columnList = "";
        for (var i=0; i<this.fields.length ; i++) {
            if (i !== 0) {
                columnList += ",";
            }
            if (this.fields[i].mapping != null) {
                columnList += this.fields[i].mapping;
            } else if (this.fields[i].name != null) {
                columnList += this.fields[i].name;
            }
        }
        return columnList;
    },
    //Used to get dummy records in testing
    getTestRecord:function(index, fields) {
        var rec= {};
        var property;
        for (var i=0; i<fields.length ; i++) {
            property = (fields[i].mapping != null)?fields[i].mapping:fields[i].name;
            rec[property]=
                (property=='id')?index+1:
                (property=='time_stamp')?{javaClass:"java.util.Date", time: (new Date(Math.floor((Math.random()*index*12345678)))).getTime()}:
                (property.indexOf('_addr') != -1)?Math.floor((Math.random()*255))+"."+Math.floor((Math.random()*255))+"."+Math.floor((Math.random()*255))+"."+Math.floor((Math.random()*255))+"/"+Math.floor((Math.random()*32)):
                (property.indexOf('_port') != -1)?Math.floor((Math.random()*65000)):
            property+"_"+(i*index)+"_"+Math.floor((Math.random()*10));
        }
        return rec;
    },
    refreshNextChunkCallback: function(result, exception) {
        if(Ung.Util.handleException(exception)) return;
        var newEventEntries = result;
        // If we got results append them to the current events list, and make another call for more
        if ( newEventEntries != null && newEventEntries.list != null && newEventEntries.list.length != 0 ) {
            this.eventEntries.push.apply( this.eventEntries, newEventEntries.list );
            this.setLoading(i18n._('Fetching Events...') + ' (' + this.eventEntries.length + ')');
            this.reader.getNextChunk(Ext.bind(this.refreshNextChunkCallback, this), 1000);
            return;
        }
        // If we got here, then we either reached the end of the resultSet or ran out of room display the results
        if (this.settingsCmp !== null) {
            this.getStore().getProxy().setData(this.eventEntries);
            this.getStore().load();
        }
        this.setLoading(false);
    },
    // Refresh the events list
    refreshCallback: function(result, exception) {
        if(Ung.Util.handleException(exception)) return;
        this.eventEntries = [];

        if( testMode ) {
            var emptyRec={};
            var length = Math.floor((Math.random()*5000));
            for(var i=0; i<length; i++) {
                this.eventEntries.push(this.getTestRecord(i, this.fields));
            }
            this.refreshNextChunkCallback(null);
        }

        this.reader = result;
        if(this.reader) {
            this.setLoading(i18n._('Fetching Events...'));
            this.reader.getNextChunk(Ext.bind(this.refreshNextChunkCallback, this), 1000);
        } else {
            this.refreshNextChunkCallback(null);
        }
    },
    listeners: {
        "activate": {
            fn: function() {
                if( this.refreshOnActivate ) {
                    Ext.Function.defer(this.refreshHandler,1, this, [false]);
                }
            }
        },
        "deactivate": {
            fn: function() {
                if(this.autoRefreshEnabled) {
                    this.stopAutoRefresh(true);
                }
            }
        }
    },
    isDirty: function() {
        return false;
    },
    afterRender: function() {
        this.getStore().setStatefulFilters(false);
        this.callParent(arguments);
    }
});

Ext.define("Ung.grid.feature.GlobalFilter", {
    extend: "Ext.grid.feature.Feature",
    init: function (grid) {
        this.grid=grid;

        this.globalFilter = Ext.create('Ext.util.Filter', {
            regExpProtect: /\\|\/|\+|\\|\.|\[|\]|\{|\}|\?|\$|\*|\^|\|/gm,
            disabled: true,
            regExpMode: false,
            caseSensitive: false,
            regExp: null,
            stateId: 'globalFilter',
            visibleColumns: {},
            filterFn: function(record) {
                if(!this.regExp) {
                    return true;
                }
                var datas = record.getData(), key, val;
                for(key in this.visibleColumns) {
                    if(datas[key] !== undefined){
                        val = datas[key];
                        if(val == null) {
                            continue;
                        }
                        if(typeof val == 'boolean' || typeof val == 'number') {
                            val=val.toString();
                        } else if(typeof val == 'object') {
                            if(val.time != null) {
                                val = i18n.timestampFormat(val);
                            }
                        }
                        if(typeof val == 'string') {
                            if(this.regExp.test(val)) {
                                return true;
                            }
                        }
                    }
                }
                return false;
            },
            getSearchValue: function(value) {
                if (value === '' || value === '^' || value === '$') {
                    return null;
                }
                if (!this.regExpMode) {
                    value = value.replace(this.regExpProtect, function(m) {
                        return '\\' + m;
                    });
                } else {
                    try {
                        new RegExp(value);
                    } catch (error) {
                        return null;
                    }
                }
                return value;
            },
            buildSearch: function(value, caseSensitive, visibleColumns) {
                this.visibleColumns = visibleColumns;
                this.setCaseSensitive(caseSensitive);
                var searchValue = this.getSearchValue(value);
                this.regExp = searchValue==null? null:new RegExp(searchValue, 'g' + (caseSensitive ? '' : 'i'));
                this.setDisabled(this.regExp==null);
            }
        });
        
        this.grid.on("afterrender", Ext.bind(function() {
            this.grid.getStore().addFilter(this.globalFilter);
        }, this));
        this.grid.on("beforedestroy", Ext.bind(function() {
            this.grid.getStore().removeFilter(this.globalFilter);
            Ext.destroy(this.globalFilter);
        }, this));
        this.callParent(arguments);
    },
    updateGlobalFilter: function(value, caseSensitive) {
        var visibleColumns = {}, i, col;
        for(i=0; i<this.grid.columns.length; i++) {
            col = this.grid.columns[i];
            if(!col.isHidden() && col.dataIndex) {
                visibleColumns[col.dataIndex] = true;
            }
        }
        this.globalFilter.buildSearch(value, caseSensitive, visibleColumns);
        // this.grid.getStore().reload();
        this.grid.getStore().getFilters().notify('endupdate');
    }
});