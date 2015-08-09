Ext.define('Ung.panel.Reports', {
    extend: 'Ext.panel.Panel',

    name: 'panelReports',
    autoRefreshInterval: 10, //In Seconds
    layout: { type: 'border'},
    extraConditions: null,
    reportingManager: null,
    webuiMode: true,
    hasEntriesSection: true,
    entry: null,
    beforeDestroy: function() {
        Ext.destroy(this.subCmps);
        this.callParent(arguments);
    },
    initComponent: function() {
        this.subCmps = [];
        if(this.webuiMode) {
            if(this.category) {
                this.helpSource = this.category.toLowerCase().replace(" ","_") + "_reports";
                if(!this.title) {
                    this.title = i18n._('Reports');
                }
                if (!Ung.Main.isReportsAppInstalled()) {
                    this.items = [{
                        region: 'center',
                        xtype: 'panel',
                        bodyPadding: 10,
                        html: i18n._("Reports application is required for this feature. Please install and enable the Reports application.")
                    }];
                    this.callParent(arguments);
                    return;
                }
            }
            rpc.reportingManagerNew = Ung.Main.getReportingManagerNew();
        }
        
        this.filterFeature = Ext.create('Ung.grid.feature.GlobalFilter', {});
        this.items = [{
            region: 'east',
            title: i18n._("Current Data"),
            width: 330,
            split: true,
            collapsible: true,
            collapsed: false,
            floatable: false,
            name: 'reportDataGrid',
            xtype: 'grid',
            store:  Ext.create('Ext.data.Store', {
                fields: [],
                data: []
            }),
            columns: [{
                flex: 1
            }],
            tbar: ['->', {
                xtype: 'button',
                text: i18n._('Export'),
                name: "Export",
                tooltip: i18n._('Export Data to File'),
                iconCls: 'icon-export',
                handler: Ext.bind(this.exportReportDataHandler, this)
            }]
        }, {
            region: 'center',
            layout: {type: 'border'},
            items: [{
                region: 'center',
                xtype: "panel",
                name: 'cardsContainer',
                layout: 'card',
                items: [{
                    xtype: 'container',
                    itemId: 'chartContainer',
                    name: 'chartContainer',
                    layout: 'fit',
                    html: ""
                }, {
                    region: 'center',
                    xtype: 'grid',
                    itemId: 'gridEvents',
                    name:'gridEvents',
                    reserveScrollbar: true,
                    title: ".",
                    viewConfig: {
                        enableTextSelection: true
                    },
                    store:  Ext.create('Ext.data.Store', {
                        fields: [],
                        data: [],
                        proxy: {
                            type: 'memory',
                            reader: {
                                type: 'json'
                            }
                        }
                    }),
                    columns: [{
                        flex: 1
                    }],
                    plugins: ['gridfilters'],
                    features: [this.filterFeature],
                    dockedItems: [{
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
                                this.gridEvents.clearFilters();
                                this.searchField.setValue("");
                            }, this)
                        }, '->',{
                            xtype: 'button',
                            text: i18n._('Export'),
                            name: "Export",
                            tooltip: i18n._('Export Events to File'),
                            iconCls: 'icon-export',
                            handler: Ext.bind(this.exportEventsHandler, this)
                        }]
                    }] 
                }],
                dockedItems: [{
                    xtype: 'toolbar',
                    dock: 'bottom',
                    items: [{
                        xtype: 'combo',
                        width: 100,
                        name: "limitSelector",
                        editable: false,
                        valueField: "value",
                        displayField: "name",
                        queryMode: 'local',
                        value: 1000,
                        store: Ext.create('Ext.data.Store', {
                            fields: ["value", "name"],
                            data: [{value: 1000, name: "1000 " + i18n._('Events')}, {value: 10000, name: "10000 " + i18n._('Events')}, {value: 50000, name: "50000 " + i18n._('Events')}]
                        })
                    }, {
                        xtype: 'button',
                        name: 'startDateButton',
                        text: i18n._('One day ago'),
                        initialLabel:  i18n._('One day ago'),
                        width: 132,
                        tooltip: i18n._('Select Start date and time'),
                        handler: Ext.bind(function(button) {
                            this.startDateWindow.show();
                        }, this)
                    },{
                        xtype: 'tbtext',
                        text: '-'
                    }, {
                        xtype: 'button',
                        name: 'endDateButton',
                        text: i18n._('Present'),
                        initialLabel:  i18n._('Present'),
                        width: 132,
                        tooltip: i18n._('Select End date and time'),
                        handler: Ext.bind(function(button) {
                            this.endDateWindow.show();
                        }, this)
                    }, {
                        xtype: 'button',
                        text: i18n._('Refresh'),
                        name: "refresh",
                        tooltip: i18n._('Flush Events from Memory to Database and then Refresh'),
                        iconCls: 'icon-refresh',
                        handler:function () {
                            this.refreshHandler();
                        },
                        scope: this
                    }, {
                        xtype: 'button',
                        name: 'auto_refresh',
                        text: i18n._('Auto Refresh'),
                        enableToggle: true,
                        pressed: false,
                        tooltip: Ext.String.format(i18n._('Auto Refresh every {0} seconds'),this.autoRefreshInterval),
                        iconCls: 'icon-autorefresh',
                        handler: Ext.bind(function(button) {
                            if(button.pressed) {
                                this.startAutoRefresh();
                            } else {
                                this.stopAutoRefresh();
                            }
                        }, this)
                    }]
                }] 
            }, this.extraConditionsPanel = Ext.create("Ung.panel.ExtraConditions", {
                region: 'south',
                parentPanel: this
            })]
        }];

        if(this.hasEntriesSection) {
            this.items.push(this.buildEntriesSection());
        }

        this.callParent(arguments);
        
        this.cardsContainer = this.down("container[name=cardsContainer]");
        
        this.chartContainer = this.down("container[name=chartContainer]");
        this.reportDataGrid = this.down("grid[name=reportDataGrid]");

        this.gridEvents = this.down("grid[name=gridEvents]");
        this.searchField=this.down('textfield[name=searchField]');
        this.caseSensitive = this.down('checkbox[name=caseSensitive]');
        this.limitSelector = this.down("combo[name=limitSelector]");
        
        this.startDateWindow = Ext.create('Ung.window.SelectDateTime', {
            title: i18n._('Start date and time'),
            dateTimeEmptyText: i18n._('start date and time'),
            buttonObj: this.down("button[name=startDateButton]")
        });
        this.endDateWindow = Ext.create('Ung.window.SelectDateTime', {
            title: i18n._('End date and time'),
            dateTimeEmptyText: i18n._('end date and time'),
            buttonObj: this.down("button[name=endDateButton]")
        });
        this.subCmps.push(this.startDateWindow);
        this.subCmps.push(this.endDateWindow);

        this.pieLegendHint="<br/>"+i18n._('Hint: Click this label on the legend to hide this slice');
        this.cartesianLegendHint="<br/>"+i18n._('Hint: Click this label on the legend to hide this series');
        
        if(this.category) {
            this.loadEntries();
        }
    },
    buildEntriesSection: function () {
        var entriesSection = {
            region: 'west',
            layout: {type: 'vbox', align: 'stretch'},
            width: 250,
            split: true,
            collapsible: true,
            collapsed: false,
            floatable: false,
            items:[{
                name: 'reportEntriesGrid',
                title: i18n._("Select Report"),
                xtype: 'grid',
                border: false,
                margin: '0 0 10 0',
                flex: 5,
                hideHeaders: true,
                store:  Ext.create('Ext.data.Store', {
                    fields: ["title"],
                    data: []
                }),
                reserveScrollbar: true,
                columns: [{
                    dataIndex: 'title',
                    flex: 1,
                    renderer: function( value, metaData, record, rowIdx, colIdx, store ) {
                        var description = record.get("description");
                        if(description) {
                            metaData.tdAttr = 'data-qtip="' + Ext.String.htmlEncode( description ) + '"';
                        }
                        return value;
                    }
                }],
                selModel: {
                    selType: 'rowmodel',
                    listeners: {
                        select: Ext.bind(function( rowModel, record, rowIndex, eOpts ) {
                            this.loadReportEntry(Ext.clone(record.getData()));
                            this.eventEntriesGrid.getSelectionModel().deselectAll();
                        }, this)
                    }
                }
            }, {
                name: 'eventEntriesGrid',
                xtype: 'grid',
                title: i18n._("Select Events"),
                border: false,
                flex: 4,
                hideHeaders: true,
                store:  Ext.create('Ext.data.Store', {
                    sorters: "displayOrder",
                    fields: ["title", "displayOrder"],
                    data: []
                }),
                reserveScrollbar: true,
                columns: [{
                    dataIndex: 'title',
                    flex: 1
                }],
                selModel: {
                    selType: 'rowmodel',
                    listeners: {
                        select: Ext.bind(function( rowModel, record, rowIndex, eOpts ) {
                            this.loadEventEntry(Ext.clone(record.getData()));
                            this.reportEntriesGrid.getSelectionModel().deselectAll();
                        }, this)
                    }
                }
            }]
        };
        return entriesSection;
    },
    setCategory: function(category) {
        this.category = category;
        var selectInitialEntrySemaphore = 2;
        var loadEntriesHandler = Ext.bind(function() {
            selectInitialEntrySemaphore--;
            if(selectInitialEntrySemaphore==0) {
                this.selectInitialEntry();
            }
        }, this);
        this.loadEntries(loadEntriesHandler);
        
    },
    loadEntries: function(handler) {
        this.loadReportEntries(null, handler);
        this.loadEventEntries(handler);
    },
    loadReportEntries: function(initialEntryId, handler) {
        if(!this.reportEntriesGrid) {
            this.reportEntriesGrid = this.down("grid[name=reportEntriesGrid]");
        }
        rpc.reportingManagerNew.getReportEntries(Ext.bind(function(result, exception) {
            if(Ung.Util.handleException(exception)) return;
            var reportEntries = [];
            this.initialEntryIndex = null;
            var entry;
            for(var i=0; i<result.list.length; i++) {
                entry = result.list[i];
                if(entry.enabled) {
                    reportEntries.push(entry);
                    if(initialEntryId && entry.uniqueId == initialEntryId) {
                        this.initialEntryIndex = i;
                    }
                    if(this.initialEntryIndex==null && entry.type!="TEXT") {
                        this.initialEntryIndex = i;
                    }
                }
            }
            if(this.initialEntryIndex == null && reportEntries.length>0) {
                this.initialEntryIndex = 0;
            }
            this.reportEntriesGrid.getStore().loadData(reportEntries);
            this.reportEntriesGrid.setHidden(reportEntries.length == 0);
            if(initialEntryId && this.initialEntryIndex) {
                this.reportEntriesGrid.getSelectionModel().select(this.initialEntryIndex);
            }
            if(Ext.isFunction(handler)) {
                handler();
            }
        }, this), this.category);
    },
    loadEventEntries: function(handler) {
        if(!this.eventEntriesGrid) {
            this.eventEntriesGrid = this.down("grid[name=eventEntriesGrid]");
        }
        rpc.reportingManagerNew.getEventEntries(Ext.bind(function(result, exception) {
            if(Ung.Util.handleException(exception)) return;
            this.eventEntriesGrid.getStore().loadData(result.list);
            this.eventEntriesGrid.setHidden(result.list.length == 0);
            if(Ext.isFunction(handler)) {
                handler();
            }
        }, this), this.category);
    },
    
    loadReportData: function(data) {
        var i, column;
        if(!this.entry || !this.chartContainer || !this.chartContainer.isVisible()) {
            return;
        }
        var chart = this.chartContainer.down("[name=chart]");
        if(!chart) {
            return;
        }
        if(this.entry.type == 'TEXT') {
            var infos=[], reportData=[];
            if(data.length>0 && this.entry.textColumns!=null) {
                var textColumns=[], value;
                for(i=0; i<this.entry.textColumns.length; i++) {
                    column = this.entry.textColumns[i].split(" ").splice(-1)[0];
                    value = Ext.isEmpty(data[0][column])? 0 : data[0][column];
                    infos.push(value);
                    reportData.push({data: column, value: value});
                }
            }
            
            var sprite = chart.getSurface().get("infos");
            sprite.setAttributes({text:Ext.String.format.apply(Ext.String.format, [i18n._(this.entry.textString)].concat(infos))}, true);
            chart.renderFrame();
            this.reportDataGrid.getStore().loadData(reportData);
        } else if(this.entry.type == 'PIE_GRAPH') {
            var topData = data;
            if(this.entry.pieNumSlices && data.length>this.entry.pieNumSlices) {
                topData = [];
                var others = {value:0};
                others[this.entry.pieGroupColumn] = i18n._("Others");
                for(i=0; i<data.length; i++) {
                    if(i < this.entry.pieNumSlices) {
                        topData.push(data[i]);
                    } else {
                        others.value+=data[i].value;
                    }
                }
                others.value = Math.round(others.value*10)/10;
                topData.push(others);
            }
            if(topData.length == 0) {
                this.noDataSprite.show();
            } else {
                this.noDataSprite.hide();
            }
            chart.renderFrame();
            chart.getStore().loadData(topData);
            this.reportDataGrid.getStore().loadData(data);
        } else if(this.entry.type == 'TIME_GRAPH') {
            chart.getStore().loadData(data);
            this.reportDataGrid.getStore().loadData(data);
        }
    },
    loadReportEntry: function(entry) {
        var me = this;
        this.entry = entry;
        if(this.autoRefreshEnabled) {
            this.stopAutoRefresh(true);
        }
        this.cardsContainer.setActiveItem("chartContainer");
        this.reportDataGrid.show();
        this.limitSelector.hide();
        
        this.chartContainer.removeAll();
        this.setLoading(i18n._('Loading report... '));
        
        var i, column;
        
        var data = [];
        var tbar = [{
            xtype: 'button',
            text: i18n._('Customize'),
            hidden: !this.servletMode,
            name: "edit",
            tooltip: i18n._('Advanced report customization'),
            iconCls: 'icon-edit',
            handler:function () {
                this.customizeReport();
            },
            scope: this
        }, '->' , {
            xtype: 'button',
            text: i18n._('View Events'),
            name: "edit",
            tooltip: i18n._('View events for this report'),
            iconCls: 'icon-edit',
            handler:Ext.bind(this.viewEventsForReport, this)
        }, {
            xtype: 'button',
            iconCls: 'icon-export',
            text: i18n._("Download"),
            handler: Ext.bind(this.downloadChart, this)
        }]; 
        var chart, reportData=[];
        this.reportDataGrid.getStore().loadData([]);
        if(entry.type == 'TEXT') {
            chart = {
                xtype: 'draw',
                name: "chart",
                border: false,
                width: '100%',
                height: '100%',
                tbar: tbar,
                sprites: [{
                    type: 'text',
                    text: entry.title,
                    fontSize: 18,
                    width: 100,
                    height: 30,
                    x: 10, // the sprite x position
                    y: 22  // the sprite y position
                }, {
                    type: 'text',
                    text: entry.description,
                    fontSize: 12,
                    x: 10,
                    y: 40
                }, {
                    type: 'text',
                    id: 'infos',
                    text: "",
                    fontSize: 12,
                    x: 10,
                    y: 80
                }]
            };
            this.reportDataGrid.setColumns([{
                dataIndex: 'data',
                header: i18n._("data"),
                width: 100,
                flex: 1
            },{
                dataIndex: 'value',
                header: i18n._("value"),
                width: 100
            }]);
        } else if(entry.type == 'PIE_GRAPH') {
            var descriptionFn = function(val, record) {
                var title = (record.get(entry.pieGroupColumn)==null)?i18n._("none") : record.get(entry.pieGroupColumn);
                var value = (entry.units == "bytes") ? Ung.Util.bytesRenderer(record.get("value")) : record.get("value") + " " + i18n._(entry.units);
                return title + ": " + value;
            };

            chart = {
                xtype: 'polar',
                name: "chart",
                store: Ext.create('Ext.data.JsonStore', {
                    fields: [{name: "description", convert: descriptionFn }, {name:'value'} ],
                    data: []
                }),
                theme: 'category2',
                border: false,
                width: '100%',
                height: '100%',
                insetPadding: {top: 40, left: 40, right: 10, bottom: 10},
                innerPadding: 20,
                legend: {
                    docked: 'right'
                },
                tbar: tbar,
                sprites: [{
                    type: 'text',
                    text: entry.title,
                    fontSize: 18,
                    width: 100,
                    height: 30,
                    x: 10, // the sprite x position
                    y: 22  // the sprite y position
                }, {
                    type: 'text',
                    text: entry.description,
                    fontSize: 12,
                    x: 10,
                    y: 40
                }, this.noDataSprite = Ext.create("Ext.draw.sprite.Text", {
                    type: 'text',
                    hidden: true,
                    text: i18n._("Not enough data to generate the chart."),
                    fontSize: 14,
                    fillStyle: '#FF0000',
                    x: 10,
                    y: 80
                })],
                interactions: ['rotate', 'itemhighlight'],
                series: [{
                    type: 'pie',
                    angleField: 'value',
                    rotation: 45,
                    label: {
                        field: "description",
                        calloutLine: {
                            length: 10,
                            width: 3
                        }
                    },
                    highlight: true,
                    tooltip: {
                        trackMouse: true,
                        style: 'background: #fff',
                        showDelay: 0,
                        dismissDelay: 0,
                        hideDelay: 0,
                        renderer: function(storeItem, item) {
                            this.setHtml(storeItem.get("description")+me.pieLegendHint);
                        }
                    }
                }]
            };

            this.reportDataGrid.setColumns([{
                dataIndex: entry.pieGroupColumn,
                header: entry.pieGroupColumn,
                width: 100,
                flex: 1
            },{
                dataIndex: 'value',
                header: i18n._("value"),
                width: 100
            },{
                xtype: 'actioncolumn',
                menuDisabled: true,
                width: 20,
                items: [{
                    iconCls: 'icon-filter-row',
                    tooltip: i18n._('Add Condition'),
                    handler: Ext.bind(function(view, rowIndex, colIndex, item, e, record) {
                        this.buildWindowAddCondition();
                        var data = {
                            column: entry.pieGroupColumn,
                            operator: "=",
                            value: record.get(entry.pieGroupColumn)
                        };
                        this.windowAddCondition.setCondition(data);
                    }, this)
                }]
            }]);
        } else if(entry.type == 'TIME_GRAPH') {
            var axesFields = [], series=[];
            var legendHint = (entry.timeDataColumns.length > 1) ? this.cartesianLegendHint : "";
            var zeroFn = function(val) {
                return (val==null)?0:val;
            };
            var timeFn = function(val) {
                return (val==null || val.time==null)?0:i18n.timestampFormat(val);
            };
            var storeFields =[{name: 'time_trunc', convert: timeFn}];
            var reportDataColumns = [{
                dataIndex: 'time_trunc',
                header: 'time_trunc',
                width: 130,
                flex: entry.timeDataColumns.length>2? 0:1
            }];
            for(i=0; i<entry.timeDataColumns.length; i++) {
                column = entry.timeDataColumns[i].split(" ").splice(-1)[0];
                axesFields.push(column);
                storeFields.push({name: column, convert: zeroFn, type: 'integer'});
                reportDataColumns.push({
                    dataIndex: column,
                    header: column,
                    width: entry.timeDataColumns.length>2 ? 60 : 90
                });
            }
            if(!entry.timeStyle) {
                entry.timeStyle = "LINE";
            }
            if(entry.timeStyle.indexOf('OVERLAPPED') != -1  && entry.timeDataColumns.length <= 1){
                entry.timeStyle = entry.timeStyle.replace("_OVERLAPPED", "");
            }
            var timeStyleButtons = [], timeStyle, timeStyles = [
                { name: 'LINE', iconCls: 'icon-line-chart', text: i18n._("Line"), tooltip: i18n._("Switch to Line Chart") },
                { name: 'BAR_3D', iconCls: 'icon-bar3d-chart', text: i18n._("Bar 3D"), tooltip: i18n._("Switch to Bar 3D Chart") },
                { name: 'BAR_3D_OVERLAPPED', iconCls: 'icon-bar3d-overlapped-chart', text: i18n._("Bar 3D Overlapped"), tooltip: i18n._("Switch to Bar 3D Overlapped Chart") },
                { name: 'BAR', iconCls: 'icon-bar-chart', text: i18n._("Bar"), tooltip: i18n._("Switch to Bar Chart") },
                { name: 'BAR_OVERLAPPED', iconCls: 'icon-bar-overlapped-chart', text: i18n._("Bar Overlapped"), tooltip: i18n._("Switch to Bar Overlapped Chart") }
            ];
            
            for(i=0; i<timeStyles.length; i++) {
                timeStyle = timeStyles[i];
                timeStyleButtons.push({
                    xtype: 'button',
                    pressed: entry.timeStyle == timeStyle.name,
                    hidden: (timeStyle.name.indexOf('OVERLAPPED') != -1 ) && (entry.timeDataColumns.length <= 1),
                    name: timeStyle.name,
                    iconCls: timeStyle.iconCls,
                    text: timeStyle.text,
                    tooltip: timeStyle.tooltip,
                    handler: Ext.bind(function(button) {
                        entry.timeStyle = button.name;
                        this.loadReportEntry(entry);
                    }, this)
                });
            }
            timeStyleButtons.push("-");
            chart = {
                xtype: 'cartesian',
                name: "chart",
                store: Ext.create('Ext.data.JsonStore', {
                    fields: storeFields,
                    data: []
                }),
                theme: 'category2',
                border: false,
                animation: false,
                width: '100%',
                height: '100%',
                insetPadding: {top: 50, left: 10, right: 10, bottom: 10},
                legend: {
                    docked: 'bottom'
                },
                tbar: timeStyleButtons.concat(tbar),
                sprites: [{
                    type: 'text',
                    text: entry.title,
                    fontSize: 18,
                    width: 100,
                    height: 30,
                    x: 10, // the sprite x position
                    y: 22  // the sprite y position
                }, {
                    type: 'text',
                    text: entry.description,
                    fontSize: 12,
                    x: 10,
                    y: 40
                }],
                interactions: ['itemhighlight'],
                axes: [{
                    type: (entry.timeStyle.indexOf('BAR_3D')!=-1) ? 'numeric3d' : 'numeric',
                    fields: axesFields,
                    position: 'left',
                    grid: true,
                    minimum: 0,
                    renderer: function (v) {
                        return (entry.units == "bytes") ? Ung.Util.bytesRenderer(v) : v + " " + i18n._(entry.units);
                    }
                }, {
                    type: (entry.timeStyle.indexOf('BAR_3D')!=-1) ? 'category3d' : 'category',
                    fields: 'time_trunc',
                    position: 'bottom',
                    grid: true,
                    label: {
                        rotate: {
                            degrees: -90
                        }
                    }
                }]
            };

            if (entry.timeStyle == 'LINE') {
                for(i=0; i<axesFields.length; i++) {
                    series.push({
                        type: 'line',
                        axis: 'left',
                        title: axesFields[i],
                        xField: 'time_trunc',
                        yField: axesFields[i],
                        style: {
                            opacity: 0.90,
                            lineWidth: 3
                        },
                        marker: {
                            radius: 2
                        },
                        highlight: {
                            fillStyle: '#000',
                            radius: 4,
                            lineWidth: 1,
                            strokeStyle: '#fff'
                        },
                        tooltip: {
                            trackMouse: true,
                            style: 'background: #fff',
                            renderer: function(storeItem, item) {
                                var title = item.series.getTitle();
                                this.setHtml(title + ' for ' + storeItem.get('time_trunc') + ': ' + storeItem.get(item.series.getYField()) + " " +i18n._(entry.units) + legendHint);
                            }
                        }
                    });
                }
                chart.series = series;
            } else if(entry.timeStyle.indexOf('OVERLAPPED') != -1) {
                for(i=0; i<axesFields.length; i++) {
                    series.push({
                        type: (entry.timeStyle.indexOf('BAR_3D')!=-1)?'bar3d': 'bar',
                        axis: 'left',
                        title: axesFields[i],
                        xField: 'time_trunc',
                        yField: axesFields[i],
                        style: (entry.timeStyle.indexOf('BAR_3D') != -1)? { opacity: 0.70, lineWidth: 1+5*i } : {  opacity: 0.60,  maxBarWidth: Math.max(40-2*i, 2) },
                        tooltip: {
                            trackMouse: true,
                            style: 'background: #fff',
                            renderer: function(storeItem, item) {
                                var title = item.series.getTitle();
                                this.setHtml(title + ' for ' + storeItem.get('time_trunc') + ': ' + storeItem.get(item.series.getYField()) + " " +i18n._(entry.units) + legendHint);
                            }
                        }
                    });
                }
                chart.series = series;
            } else if((entry.timeStyle.indexOf('BAR') != -1 )) {
                chart.series = [{
                    type: (entry.timeStyle.indexOf('BAR_3D')!=-1)?'bar3d': 'bar',
                    axis: 'left',
                    title: axesFields,
                    xField: 'time_trunc',
                    yField: axesFields,
                    stacked: false,
                    style: {
                        opacity: 0.90,
                        inGroupGapWidth: 1
                    },
                    highlight: true,
                    tooltip: {
                        trackMouse: true,
                        style: 'background: #fff',
                        renderer: function(storeItem, item) {
                            var title = item.series.getTitle()[Ext.Array.indexOf(item.series.getYField(), item.field)];
                            this.setHtml(title + ' for ' + storeItem.get('time_trunc') + ': ' + storeItem.get(item.field) + " " +i18n._(entry.units) + legendHint);
                        }
                    }
                }];
            }
            this.reportDataGrid.setColumns(reportDataColumns);
        }
        
        if(chart.xtype!= 'draw') {
            if ( entry.colors != null && entry.colors.length > 0 ) {
                chart.colors = entry.colors;
            } else {
                chart.colors = ['#00b000', '#3030ff', '#009090', '#00ffff', '#707070', '#b000b0', '#fff000', '#b00000', '#ff0000', '#ff6347', '#c0c0c0'];
            }
        }
        
        this.chartContainer.add(chart);
        rpc.reportingManagerNew.getDataForReportEntry(Ext.bind(function(result, exception) {
            this.setLoading(false);
            if(Ung.Util.handleException(exception)) return;
            this.loadReportData(result.list);
        }, this), entry, this.startDateWindow.date, this.endDateWindow.date, this.extraConditions, -1);
        Ung.panel.Reports.getColumnsForTable(entry.table, this.extraConditionsPanel.columnsStore);
    },
    loadEventEntry: function(entry) {
        var i, col, sortType, config;
        this.entry = entry;
        if(this.autoRefreshEnabled) {
            this.stopAutoRefresh(true);
        }
        if(!entry.defaultColumns) {
            entry.defaultColumns = [];
        }
        this.cardsContainer.setActiveItem("gridEvents");
        this.reportDataGrid.hide();
        this.limitSelector.show();
        
        this.gridEvents.setTitle(entry.title);
        var tableConfig = Ext.clone(Ung.panel.Reports.getTableConfig(entry.table));
        if(!tableConfig) {
            console.log("tableConfig auto generated for table: "+entry.table+". Consider adding it to Ung.panel.Reports.getTableConfig.");
            tableConfig = {
                fields: [],
                columns: []
            };
            for(i=0; i< entry.defaultColumns.length; i++) {
                col = entry.defaultColumns[i];
                config = Ung.panel.Reports.getColumnConfig(entry.defaultColumns[i]);
                tableConfig.columns.push(config.column);
                tableConfig.fields.push(config.field);
            }
        } else {
            var columnsNames = {};
            for(i=0; i< tableConfig.columns.length; i++) {
                col = tableConfig.columns[i].dataIndex;
                columnsNames[col]=true;
                col = tableConfig.columns[i];
                if((entry.defaultColumns.length>0) && (entry.defaultColumns.indexOf(col.dataIndex) < 0)) {
                    col.hidden = true;
                }
            }
            for(i=0; i<entry.defaultColumns.length; i++) {
                col = entry.defaultColumns[i];
                if(!columnsNames[col]) {
                    config = Ung.panel.Reports.getColumnConfig(col);
                    tableConfig.columns.push(config.column);
                    tableConfig.fields.push(config.field);
                }
            }
        }
        var store = Ext.create('Ext.data.Store', {
            fields: tableConfig.fields,
            data: [],
            proxy: {
                type: 'memory',
                reader: {
                    type: 'json'
                }
            }
        });
        this.gridEvents.reconfigure(store, tableConfig.columns);
        this.refreshHandler();
        Ung.panel.Reports.getColumnsForTable(entry.table, this.extraConditionsPanel.columnsStore);
    },
    refreshHandler: function () {
        if(this.autoRefreshEnabled) {
            return;
        }
        this.refresheEntry();
    },
    autoRefresh: function() {
        if(!this.autoRefreshEnabled) {
            return;
        }
        this.refresheEntry();
    },
    refresheEntry: function() {
        if(!this.entry) {
            return;
        }
        if(Ung.panel.Reports.isEvent(this.entry)) {
            this.refreshEvents();
        } else {
            this.refreshReportData();
        }
    },
    refreshReportData: function() {
        if(!this.entry) {
            return;
        }
        if(!this.autoRefreshEnabled) { this.setLoading(i18n._('Refreshing report... ')); }
        rpc.reportingManagerNew.getDataForReportEntry(Ext.bind(function(result, exception) {
            this.setLoading(false);
            if(Ung.Util.handleException(exception)) return;
            this.loadReportData(result.list);
            if(this!=null && this.rendered && this.autoRefreshEnabled) {
                Ext.Function.defer(this.autoRefresh, this.autoRefreshInterval*1000, this);
            }
        }, this), this.entry, this.startDateWindow.date, this.endDateWindow.date, this.extraConditions, -1);
    },
    refreshEvents: function() {
        if(!this.entry) {
            return;
        }
        var limit = this.limitSelector.getValue();
            if(!this.autoRefreshEnabled) { this.setLoading(i18n._('Querying Database...')); }
            rpc.reportingManagerNew.getEventsForDateRangeResultSet(Ext.bind(function(result, exception) {
                this.setLoading(false);
                if(Ung.Util.handleException(exception)) return;
                this.loadResultSet(result);
            }, this), this.entry, this.extraConditions, limit, this.startDateWindow.date, this.endDateWindow.date);
    },
    autoRefreshEnabled: false,
    startAutoRefresh: function(setButton) {
        if(!this.entry) {
            this.down('button[name=auto_refresh]').toggle(false);
            return;
        }

        this.autoRefreshEnabled=true;
        this.down('button[name=refresh]').disable();
        this.autoRefresh();
    },
    stopAutoRefresh: function(setButton) {
        this.autoRefreshEnabled=false;
        if(setButton) {
            this.down('button[name=auto_refresh]').toggle(false);
        }
        this.down('button[name=refresh]').enable();
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
                //(fields[i].convert==Ung.panel.Reports.mailEventConvertAction)?'P':
                (property=="spam_blocker_action")?'P':
            property+"_"+(i*index)+"_"+Math.floor((Math.random()*10));
        }
        return rec;
    },
    loadNextChunkCallback: function(result, exception) {
        if(Ung.Util.handleException(exception)) return;
        var newEvents = result;
        // If we got results append them to the current events list, and make another call for more
        if ( newEvents != null && newEvents.list != null && newEvents.list.length != 0 ) {
            this.events.push.apply( this.events, newEvents.list );
            if(!this.autoRefreshEnabled) { this.setLoading(i18n._('Fetching Events...') + ' (' + this.events.length + ')'); }
            this.reader.getNextChunk(Ext.bind(this.loadNextChunkCallback, this), 1000);
            return;
        }
        // If we got here, then we either reached the end of the resultSet or ran out of room display the results
        if (this.gridEvents!=null && this.gridEvents.getStore() != null) {
            this.gridEvents.getStore().getProxy().setData(this.events);
            this.gridEvents.getStore().load();
        }
        this.setLoading(false);
        
        if(this!=null && this.rendered && this.autoRefreshEnabled) {
            Ext.Function.defer(this.autoRefresh, this.autoRefreshInterval*1000, this);
        }
    },
    // Refresh the events list
    loadResultSet: function(result) {
        this.events = [];

        if( testMode ) {
            var emptyRec={};
            var length = Math.floor((Math.random()*5000));
            var fields = this.gridEvents.getStore().getModel().getFields();
            for(var i=0; i<length; i++) {
                this.events.push(this.getTestRecord(i, fields));
            }
        }

        this.reader = result;
        if(this.reader) {
            if(!this.autoRefreshEnabled) { this.setLoading(i18n._('Fetching Events...')); }
            this.reader.getNextChunk(Ext.bind(this.loadNextChunkCallback, this), 1000);
        } else {
            this.loadNextChunkCallback(null);
        }
    },
    getColumnList: function() {
        var columns= this.gridEvents.getColumns(), columnList = "";
        for (var i=0; i<columns.length ; i++) {
            if (i !== 0) {
                columnList += ",";
            }
            if (columns[i].dataIndex != null) {
                columnList += columns[i].dataIndex;
            }
        }
        return columnList;
    },
    exportReportDataHandler: function() {
        if(!this.entry) {
            return;
        }
        var processRow = function (row) {
            var data = [];
            for (var j = 0; j < row.length; j++) {
                var innerValue = row[j] == null ? '' : row[j].toString();
                data.push('"' + innerValue.replace(/"/g, '""') + '"');
            }
            return data.join(",") + '\r\n';
        };

        var records = this.reportDataGrid.getStore().getRange(), list=[], columns=[], headers=[], i, j, row;
        var gridColumns = this.reportDataGrid.getColumns();
        for(i=0; i<gridColumns.length;i++) {
            if(gridColumns[i].initialConfig.dataIndex) {
                columns.push(gridColumns[i].initialConfig.dataIndex);
                headers.push(gridColumns[i].initialConfig.header);
            }
        }
        list.push(processRow(headers));
        for(i=0; i<records.length;i++) {
            row = [];
            for(j=0; j<columns.length;j++) {
                row.push(records[i].get(columns[j]));
            }
            list.push(processRow(row));
        }
        var content = list.join("");
        var fileName = this.entry.title.trim().replace(/ /g,"_")+".csv";
        Ung.Util.download(content, fileName, 'text/csv');
    },
    downloadChart: function() {
        if(!this.entry) {
            return;
        }
        var chart = this.chartContainer.down("[name=chart]");
        if(!chart) {
            return;
        }
        var fileName = this.entry.title.trim().replace(/ /g,"_")+".png";
        Ext.MessageBox.wait(i18n._("Downloading Chart..."), i18n._("Please wait"));
        var downloadForm = document.getElementById('downloadForm');
        downloadForm["type"].value="imageDownload";
        downloadForm["arg1"].value=fileName;
        downloadForm["arg2"].value=chart.getImage().data;
        downloadForm["arg3"].value="";
        downloadForm["arg4"].value="";
        downloadForm["arg5"].value="";
        downloadForm["arg6"].value="";
        downloadForm.submit();
        Ext.MessageBox.hide();
        /*
        if (Ext.os.is.Desktop) {
            chart.download({
                filename: fileName
            });
        } else {
            chart.preview();
        } */
    },
    exportEventsHandler: function() {
        if(!this.entry) {
            return;
        }
        var startDate = this.startDateWindow.date;
        var endDate = this.endDateWindow.date;
        
        Ext.MessageBox.wait(i18n._("Exporting Events..."), i18n._("Please wait"));
        var name=this.entry.title.trim().replace(/ /g,"_");
        var downloadForm = document.getElementById('downloadForm');
        downloadForm["type"].value="eventLogExport";
        downloadForm["arg1"].value=name;
        downloadForm["arg2"].value=Ext.encode(this.entry);
        downloadForm["arg3"].value=Ext.encode(this.extraConditions);
        downloadForm["arg4"].value=this.getColumnList();
        downloadForm["arg5"].value=startDate?startDate.getTime():-1;
        downloadForm["arg6"].value=endDate?endDate.getTime():-1;
        downloadForm.submit();
        Ext.MessageBox.hide();
    },
    buildWindowAddCondition: function() {
        var me = this;
        if(!this.windowAddCondition) {
            this.windowAddCondition = Ext.create("Ung.EditWindow", {
                title: i18n._("Add Condition"),
                grid: null,
                height: 150,
                width: 600,
                sizeToRack: false,
                // size to grid on show
                sizeToGrid: false,
                center: true,
                items: [{
                    xtype: "panel",
                    bodyStyle: 'padding:10px 10px 0px 10px;',
                    items: [{
                        xtype: "component",
                        margin: '0 0 10 0',
                        html: i18n._("Add a condition using report data:")
                    }, {
                        xtype: "container",
                        layout: "column",
                        defaults: {
                            margin: '0 10 0 0'
                        },
                        items: [{
                            xtype: "textfield",
                            name: "column",
                            width: 180,
                            readOnly: true
                        }, {
                            xtype: 'combo',
                            width: 90,
                            name: "operator",
                            editable: false,
                            valueField: "name",
                            displayField: "name",
                            queryMode: 'local',
                            value: "=",
                            store: ["=", "!=", "<>", ">", "<", ">=", "<=", "between", "like", "in", "is"]
                        }, {
                            xtype: "textfield",
                            name: "value",
                            emptyText: i18n._("[no value]"),
                            width: 180
                        }]
                    }]
                }],
                updateAction: function() {
                    var data = {
                        column: this.down("[name=column]").getValue(),
                        operator: this.down("[name=operator]").getValue(),
                        value: this.down("[name=value]").getValue()
                    };
                    me.extraConditionsPanel.expand();
                    me.extraConditionsPanel.fillCondition(data);
                    this.cancelAction();
                },
                setCondition: function(data) {
                    this.show();
                    this.down("[name=column]").setValue(data.column);
                    this.down("[name=operator]").setValue(data.operator);
                    this.down("[name=value]").setValue(data.value);
                },
                isDirty: function() {
                    return false;
                },
                closeWindow: function() {
                    this.hide();
                }
            });
            this.subCmps.push(this.windowAddCondition);
        }
    },
    customizeReport: function() {
        if(!this.entry) {
            return;
        }
        if(!this.winReportEditor) {
            var me = this;
            this.winReportEditor = Ext.create('Ung.window.ReportEditor', {
                sizeToComponent: this.chartContainer,
                title: i18n._("Advanced report customization"),
                forReportCustomization: true,
                parentCmp: this,
                grid: {},
                isDirty: function() {
                    return false;
                },
                updateAction: function() {
                    Ung.window.ReportEditor.prototype.updateAction.apply(this, arguments);
                    me.entry = this.record.getData();
                    me.loadReportEntry(me.entry);
                }
            });
            this.subCmps.push(this.winReportEditor);
        }
        var record = Ext.create('Ext.data.Model', this.entry);
        this.winReportEditor.populate(record);
        this.winReportEditor.show();
    },
    viewEventsForReport: function() {
        if(!this.entry) {
            return;
        }
        
        var entry = {
            javaClass: "com.untangle.node.reporting.EventEntry",
            category: this.entry.category,
            conditions: this.entry.conditions,
            displayOrder: 1,
            table: this.entry.table,
            title: Ext.String.format(i18n._('Events for report: {0}'), this.entry.title)
        };
        this.loadEventEntry(entry);
        if(this.reportEntriesGrid){
            this.reportEntriesGrid.getSelectionModel().deselectAll();
        }
    },
    isDirty: function() {
        return false;
    },
    selectInitialEntry: function() {
        if(this.reportEntriesGrid && this.reportEntriesGrid.getStore().getCount() > 0) {
            this.reportEntriesGrid.getSelectionModel().select(this.initialEntryIndex);
        } else if (this.eventEntriesGrid && this.eventEntriesGrid.getStore().getCount() > 0) {
            this.eventEntriesGrid.getSelectionModel().select(0);
        }
    },
    listeners: {
        "activate": {
            fn: function() {
                if(this.category && !this.entry) {
                    this.selectInitialEntry();
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
    statics: {
        isEvent: function(entry) {
            return "com.untangle.node.reporting.EventEntry" == entry.javaClass;
        },
        getColumnRenderer: function(columnName) {
            if(!this.columnRenderers) {
                this.columnRenderers = {
                    policy_id: function(value) {
                        return rpc.policyNamesMap[value] || value;
                    },
                    protocol: function(value) {
                        switch (value) {
                          case 0: return "HOPOPT";
                          case 1: return "ICMP";
                          case 2: return "IGMP";
                          case 3: return "GGP";
                          case 4: return "IP-in-IP";
                          case 5: return "ST";
                          case 6: return "TCP";
                          case 7: return "CBT";
                          case 8: return "EGP";
                          case 9: return "IGP";
                          case 10: return "BBN-RCC-MON";
                          case 11: return "NVP-II";
                          case 12: return "PUP";
                          case 13: return "ARGUS";
                          case 14: return "EMCON";
                          case 15: return "XNET";
                          case 16: return "CHAOS";
                          case 17: return "UDP";
                          case 18: return "MUX";
                          case 19: return "DCN-MEAS";
                          case 20: return "HMP";
                          case 21: return "PRM";
                          case 22: return "XNS-IDP";
                          case 23: return "TRUNK-1";
                          case 24: return "TRUNK-2";
                          case 25: return "LEAF-1";
                          case 26: return "LEAF-2";
                          case 27: return "RDP";
                          case 28: return "IRTP";
                          case 29: return "ISO-TP4";
                          case 30: return "NETBLT";
                          case 31: return "MFE-NSP";
                          case 32: return "MERIT-INP";
                          case 33: return "DCCP";
                          case 34: return "3PC";
                          case 35: return "IDPR";
                          case 36: return "XTP";
                          case 37: return "DDP";
                          case 38: return "IDPR-CMTP";
                          case 39: return "TP++";
                          case 40: return "IL";
                          case 41: return "IPv6";
                          case 42: return "SDRP";
                          case 43: return "IPv6-Route";
                          case 44: return "IPv6-Frag";
                          case 45: return "IDRP";
                          case 46: return "RSVP";
                          case 47: return "GRE";
                          case 48: return "MHRP";
                          case 49: return "BNA";
                          case 50: return "ESP";
                          case 51: return "AH";
                          case 52: return "I-NLSP";
                          case 53: return "SWIPE";
                          case 54: return "NARP";
                          case 55: return "MOBILE";
                          case 56: return "TLSP";
                          case 57: return "SKIP";
                          case 58: return "IPv6-ICMP";
                          case 59: return "IPv6-NoNxt";
                          case 60: return "IPv6-Opts";
                          case 62: return "CFTP";
                          case 64: return "SAT-EXPAK";
                          case 65: return "KRYPTOLAN";
                          case 66: return "RVD";
                          case 67: return "IPPC";
                          case 69: return "SAT-MON";
                          case 70: return "VISA";
                          case 71: return "IPCU";
                          case 72: return "CPNX";
                          case 73: return "CPHB";
                          case 74: return "WSN";
                          case 75: return "PVP";
                          case 76: return "BR-SAT-MON";
                          case 77: return "SUN-ND";
                          case 78: return "WB-MON";
                          case 79: return "WB-EXPAK";
                          case 80: return "ISO-IP";
                          case 81: return "VMTP";
                          case 82: return "SECURE-VMTP";
                          case 83: return "VINES";
                          case 84: return "TTP";
                          case 84: return "IPTM";
                          case 85: return "NSFNET-IGP";
                          case 86: return "DGP";
                          case 87: return "TCF";
                          case 88: return "EIGRP";
                          case 89: return "OSPF";
                          case 90: return "Sprite-RPC";
                          case 91: return "LARP";
                          case 92: return "MTP";
                          case 93: return "AX.25";
                          case 94: return "IPIP";
                          case 95: return "MICP";
                          case 96: return "SCC-SP";
                          case 97: return "ETHERIP";
                          case 98: return "ENCAP";
                          case 100: return "GMTP";
                          case 101: return "IFMP";
                          case 102: return "PNNI";
                          case 103: return "PIM";
                          case 104: return "ARIS";
                          case 105: return "SCPS";
                          case 106: return "QNX";
                          case 107: return "A/N";
                          case 108: return "IPComp";
                          case 109: return "SNP";
                          case 110: return "Compaq-Peer";
                          case 111: return "IPX-in-IP";
                          case 112: return "VRRP";
                          case 113: return "PGM";
                          case 115: return "L2TP";
                          case 116: return "DDX";
                          case 117: return "IATP";
                          case 118: return "STP";
                          case 119: return "SRP";
                          case 120: return "UTI";
                          case 121: return "SMP";
                          case 122: return "SM";
                          case 123: return "PTP";
                          case 124: return "IS-IS";
                          case 125: return "FIRE";
                          case 126: return "CRTP";
                          case 127: return "CRUDP";
                          case 128: return "SSCOPMCE";
                          case 129: return "IPLT";
                          case 130: return "SPS";
                          case 131: return "PIPE";
                          case 132: return "SCTP";
                          case 133: return "FC";
                          case 134: return "RSVP-E2E-IGNORE";
                          case 135: return "Mobility";
                          case 136: return "UDPLite";
                          case 137: return "MPLS-in-IP";
                          case 138: return "manet";
                          case 139: return "HIP";
                          case 140: return "Shim6";
                          case 141: return "WESP";
                          case 142: return "ROHC";
                        default: return value.toString();
                        }
                    }
                };
            }
            return this.columnRenderers[columnName];
        },
        getColumnHumanReadableName: function(columnName) {
            if(!this.columnsHumanReadableNames) {
                this.columnsHumanReadableNames = {
                    action: i18n._('Action'),
                    ad_blocker_action: 'Ad Blocker ' + i18n._('Action'),
                    ad_blocker_cookie_ident: 'Ad Blocker ' + i18n._('Cookie'),
                    addr: i18n._('Address'),
                    addr_kind: i18n._('Address Kind'),
                    addr_name: i18n._('Address Name'),
                    address: i18n._('Address'),
                    application_control_application: 'Application Control ' + i18n._('Application'),
                    application_control_blocked: 'Application Control ' + i18n._('Blocked'),
                    application_control_confidence: 'Application Control ' + i18n._('Confidence'),
                    application_control_detail: 'Application Control ' + i18n._('Detail'),
                    application_control_flagged: 'Application Control ' + i18n._('Flagged'),
                    application_control_lite_blocked: 'Application Control Lite ' + i18n._('Blocked'),
                    application_control_lite_protocol: 'Application Control Lite ' + i18n._('Protocol'),
                    application_control_protochain: 'Application Control ' + i18n._('Protochain'),
                    application_control_ruleid: 'Application Control ' + i18n._('Rule ID'),
                    auth_type: i18n._('Authorization Type'),
                    bandwidth_control_priority: 'Bandwidth Control ' + i18n._('Priority'),
                    bandwidth_control_rule: 'Bandwidth Control ' + i18n._('Rule ID'),
                    blocked: i18n._('Blocked'),
                    bypasses: i18n._('Bypasses'),
                    bypassed: i18n._('Bypassed'),
                    c2p_bytes: i18n._('From-Client Bytes'),
                    c2s_content_length: i18n._('Client-to-server Content Length'),
                    c_client_addr: i18n._('Client-side Client Address'),
                    c_client_port: i18n._('Client-side Client Port'),
                    c_server_addr: i18n._('Client-side Server Address'),
                    c_server_port: i18n._('Client-side Server Port'),
                    captive_portal_blocked: 'Captive Portal ' + i18n._('Blocked'),
                    captive_portal_rule_index: 'Captive Portal ' + i18n._('Rule ID'),
                    category: i18n._('Category'),
                    class_id: i18n._('Classtype ID'),
                    classtype: i18n._('Classtype'),
                    client_addr: i18n._('Client Address'),
                    client_address: i18n._('Client Address'),
                    client_intf: i18n._('Client Interface'),
                    client_name: i18n._('Client Name'),
                    client_protocol: i18n._('Client Protocol'),
                    client_username: i18n._('Client Username'),
                    connect_stamp: i18n._('Connect Time'),
                    cpu_system: i18n._('CPU System Utilization'),
                    cpu_user: i18n._('CPU User Utilization'),
                    description: i18n._('Text detail of the event'),
                    dest_addr: i18n._('Destination Address'),
                    dest_port: i18n._('Destination Port'),
                    disk_free: i18n._('Disk Free'),
                    disk_total: i18n._('Disk Size'),
                    domain: i18n._('Domain'),
                    elapsed_time: i18n._('Elapsed Time'),
                    end_time: i18n._('End Time'),
                    event_id: i18n._('Event ID'),
                    event_info: i18n._('Event Type'),
                    firewall_blocked: 'Firewall ' + i18n._('Blocked'),
                    firewall_flagged: 'Firewall ' + i18n._('Flagged'),
                    firewall_rule_index: 'Firewall ' + i18n._('Rule ID'),
                    gen_id: i18n._('Grouping ID'),
                    goodbye_stamp: i18n._('End Time'),
                    hit_bytes: i18n._('Hit Bytes'),
                    hits: i18n._('Hits'),
                    host: i18n._('Host'),
                    hostname: i18n._('Hostname'),
                    interface_id: i18n._('Interface ID'),
                    ipaddr: i18n._('Client Address'),
                    json: i18n._('JSON Text'),
                    key: i18n._('Key'),
                    load_1: i18n._('CPU load (1-min)'),
                    load_15: i18n._('CPU load (15-min)'),
                    load_5: i18n._('CPU load (5-min)'),
                    local: i18n._('Local'),
                    login: i18n._('Login'),
                    login_name: i18n._('Login Name'),
                    mem_buffers: i18n._('Memory Buffers'),
                    mem_cache: i18n._('Memory Cache'),
                    mem_free: i18n._('Memory Free'),
                    method: i18n._('Method'),
                    miss_bytes: i18n._('Miss Bytes'),
                    misses: i18n._('Misses'),
                    msg: i18n._('Message'),
                    msg_id: i18n._('Message ID'),
                    name: i18n._('Interface Name'),
                    net_interface: i18n._('Net Interface'),
                    net_process: i18n._('Net Process'),
                    os_name: i18n._('Interface O/S Name'),
                    p2c_bytes: i18n._('To-Client Bytes'),
                    p2s_bytes: i18n._('To-Server Bytes'),
                    phish_blocker_action: 'Phish Blocker ' + i18n._('Action'),
                    phish_blocker_is_spam: 'Phish Blocker ' + i18n._('Phish'),
                    phish_blocker_score: 'Phish Blocker ' + i18n._('Score'),
                    phish_blocker_tests_string: 'Phish Blocker ' + i18n._('Tests'),
                    policy_id: i18n._('Policy ID'),
                    pool_address: i18n._('Pool Address'),
                    protocol: i18n._('Protocol'),
                    reason: i18n._('Reason'),
                    receiver: i18n._('Receiver'),
                    remote_address: i18n._('Remote Address'),
                    remote_port: i18n._('Remote Port'),
                    request_id: i18n._('Request ID'),
                    rx_bytes: i18n._('Bytes Received'),
                    s2c_content_length: i18n._('Server-to-client Content Length'),
                    s2c_content_type: i18n._('Server-to-client Content Type'),
                    s2p_bytes: i18n._('From-Server Bytes'),
                    s_client_addr: i18n._('Server-side Client Address'),
                    s_client_port: i18n._('Server-side Client Port'),
                    s_server_addr: i18n._('Server-side Server Address'),
                    s_server_port: i18n._('Server-side Server Port'),
                    sender: i18n._('Sender'),
                    server_intf: i18n._('Server Interface'),
                    session_id: i18n._('Session ID'),
                    settings_file: i18n._('Settings File'),
                    shield_blocked: 'Shield ' + i18n._('Blocked'),
                    sig_id: i18n._('Signature ID'),
                    size: i18n._('Size'),
                    source_addr: i18n._('Source Address'),
                    source_port: i18n._('Source Port'),
                    spam_blocker_action: 'Spam Blocker ' + i18n._('Action'),
                    spam_blocker_is_spam: 'Spam Blocker ' + i18n._('Spam'),
                    spam_blocker_lite_action: 'Spam Blocker Lite ' + i18n._('Action'),
                    spam_blocker_lite_is_spam: 'Spam Blocker Lite ' + i18n._('Spam'),
                    spam_blocker_lite_score: 'Spam Blocker Lite ' + i18n._('Score'),
                    spam_blocker_lite_tests_string: 'Spam Blocker Lite ' + i18n._('Tests'),
                    spam_blocker_score: 'Spam Blocker ' + i18n._('Score'),
                    spam_blocker_tests_string: 'Spam Blocker ' + i18n._('Tests'),
                    ssl_inspector_detail: 'HTTPS Inspector ' + i18n._('Detail'),
                    ssl_inspector_ruleid: 'HTTPS Inspector ' + i18n._('Rule ID'),
                    ssl_inspector_status: 'HTTPS Inspector ' + i18n._('Status'),
                    start_time: i18n._('Start Time'),
                    subject: i18n._('Subject'),
                    succeeded: i18n._('Succeeded'),
                    success: i18n._('Success'),
                    summary_text: i18n._('Summary Text'),
                    swap_free: i18n._('Swap Free'),
                    swap_total: i18n._('Swap Size'),
                    systems: i18n._('System bypasses'),
                    term: i18n._('Search Term'),
                    time_stamp: i18n._('Timestamp'),
                    tx_bytes: i18n._('Bytes Sent'),
                    type: i18n._('Type'),
                    uri: i18n._('URI'),
                    username: i18n._('Username'),
                    value: i18n._('Value'),
                    vendor_name: i18n._('Vendor Name'),
                    virus_blocker_clean: 'Virus Blocker ' + i18n._('Clean'),
                    virus_blocker_lite_clean: 'Virus Blocker Lite ' + i18n._('Clean'),
                    virus_blocker_lite_name: 'Virus Blocker Lite ' + i18n._('Name'),
                    virus_blocker_name: 'Virus Blocker ' + i18n._('Name'),
                    web_filter_blocked: 'Web Filter ' + i18n._('Blocked'),
                    web_filter_category: 'Web Filter ' + i18n._('Category'),
                    web_filter_flagged: 'Web Filter ' + i18n._('Flagged'),
                    web_filter_lite_blocked: 'Web Filter Lite ' + i18n._('Blocked'),
                    web_filter_lite_category: 'Web Filter Lite ' + i18n._('Category'),
                    web_filter_lite_flagged: 'Web Filter Lite ' + i18n._('Flagged'),
                    web_filter_lite_reason: 'Web Filter Lite ' + i18n._('Reason'),
                    web_filter_reason: 'Web Filter ' + i18n._('Reason')
                };
            }
            if(!columnName) columnName="";
            var readableName = this.columnsHumanReadableNames[columnName];
            return readableName!=null ? readableName : columnName.replace(/_/g," ");
        },
        getColumnsForTable: function(table, store) {
            if(table != null && table.length > 2) {
                rpc.reportingManagerNew.getColumnsForTable(function(result, exception) {
                    if(Ung.Util.handleException(exception)) return;
                    var columns = [];
                    for (var i=0; i< result.length; i++) {
                        columns.push({
                            name: result[i],
                            displayName: Ung.panel.Reports.getColumnHumanReadableName(result[i]) + " ["+result[i]+"]"
                        });
                    }
                    store.loadData(columns);
                }, table);
            }
        },
        getColumnConfig: function(columnName) {
            var config = {
                column: {
                    header: Ung.panel.Reports.getColumnHumanReadableName(columnName),
                    dataIndex: columnName,
                    sortable: true,
                    flex: 1
                },
                field: {
                    name: columnName
                }
            };
            var sortType = this.getColumnSortType(columnName);
            if(sortType) {
                config.field.sortType = sortType;
            }
            if(columnName == "time_stamp") {
                config.column.renderer = function(value) {
                    return i18n.timestampFormat(value);
                };
            }
            return config;
        },
        getColumnSortType: function(columnName) {
            if(!this.columnsSortTypes) {
                this.columnsSortTypes = {
                    'time_stamp': 'asTimestamp',
                    'sid': 'asInt',
                    'protocol': 'asInt',
                    'network': 'asIp'
                };
            }
            if(!columnName) columnName="";
            var sortType = this.columnsSortTypes[columnName];
            if(!sortType) {
                if(/_addr$/.test(columnName) || /address$/.test(columnName)) {
                    sortType = 'asIp';
                } else if(/_port$/.test(columnName) || /_id$/.test(columnName)) {
                    sortType = 'asInt';
                }
            }
            return sortType;
        },
        getTableConfig: function(table) {
            if(!this.tableConfig) {
                this.tableConfig = {
                    sessions: {
                        fields: [{
                            name: 'time_stamp',
                            sortType: 'asTimestamp'
                        }, {
                            name: 'bandwidth_control_priority'
                        }, {
                            name: 'bandwidth_control_rule'
                        }, {
                            name: 'protocol'
                        }, {
                            name: 'username'
                        }, {
                            name: 'hostname'
                        }, {
                            name: 'client_intf'
                        }, {
                            name: 'server_intf'
                        }, {
                            name: 'c_client_addr',
                            sortType: 'asIp'
                        }, {
                            name: 'c_client_port',
                            sortType: 'asInt'
                        }, {
                            name: 'c_server_addr',
                            sortType: 'asIp'
                        }, {
                            name: 'c_server_port',
                            sortType: 'asInt'
                        }, {
                            name: 's_client_addr',
                            sortType: 'asIp'
                        }, {
                            name: 's_client_port',
                            sortType: 'asInt'
                        }, {
                            name: 's_server_addr',
                            sortType: 'asIp'
                        }, {
                            name: 's_server_port',
                            sortType: 'asInt'
                        }, {
                            name: 'application_control_application',
                            type: 'string'
                        }, {
                            name: 'application_control_protochain',
                            type: 'string'
                        }, {
                            name: 'application_control_flagged',
                            type: 'boolean'
                        }, {
                            name: 'application_control_blocked',
                            type: 'boolean'
                        }, {
                            name: 'application_control_confidence'
                        }, {
                            name: 'application_control_detail'
                        }, {
                            name: 'application_control_lite_blocked'
                        }, {
                            name: 'application_control_lite_protocol',
                            type: 'string'
                        }, {
                            name: 'application_control_ruleid'
                        }, {
                            name: 'ssl_inspector_status'
                        }, {
                            name: 'ssl_inspector_detail'
                        }, {
                            name: 'ssl_inspector_ruleid'
                        }, {
                            name: 'policy_id'
                        }, {
                            name: 'firewall_blocked'
                        }, {
                            name: 'firewall_flagged'
                        }, {
                            name: 'firewall_rule_index'
                        }, {
                            name: 'ips_blocked'
                        }, {
                            name: 'ips_ruleid'
                        }, {
                            name: 'ips_description',
                            type: 'string'
                        }, {
                            name: "captive_portal_rule_index"
                        }, {
                            name: "captive_portal_blocked"
                        }],
                        columns: [{
                            header: i18n._("Timestamp"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: 'time_stamp',
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        }, {
                            header: i18n._("Protocol"),
                            width: Ung.Util.portFieldWidth,
                            sortable: true,
                            dataIndex: 'protocol',
                            renderer: Ung.panel.Reports.getColumnRenderer('protocol')
                        }, {
                            header: i18n._('Policy Id'),
                            width: 60,
                            sortable: true,
                            dataIndex: 'policy_id',
                            renderer: Ung.Main.getPolicyName
                        }, {
                            header: i18n._("Client Interface") ,
                            width: Ung.Util.portFieldWidth + 40, // +40 for column header
                            sortable: true,
                            dataIndex: 'client_intf'
                        }, {
                            header: i18n._("Server Interface") ,
                            width: Ung.Util.portFieldWidth + 40, // +40 for column header
                            sortable: true,
                            dataIndex: 'server_intf'
                        }, {
                            header: i18n._("Username"),
                            width: Ung.Util.usernameFieldWidth,
                            sortable: true,
                            dataIndex: 'username'
                        }, {
                            header: i18n._("Hostname"),
                            width: Ung.Util.hostnameFieldWidth,
                            sortable: true,
                            dataIndex: 'hostname'
                        }, {
                            header: i18n._("Client"),
                            width: Ung.Util.ipFieldWidth,
                            sortable: true,
                            dataIndex: 'c_client_addr'
                        }, {
                            header: i18n._("Client Port"),
                            width: Ung.Util.portFieldWidth,
                            sortable: true,
                            dataIndex: 'c_client_port',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._("New Client"),
                            width: Ung.Util.ipFieldWidth,
                            sortable: true,
                            dataIndex: 's_client_addr'
                        }, {
                            header: i18n._("New Client Port"),
                            width: Ung.Util.portFieldWidth,
                            sortable: true,
                            dataIndex: 's_client_port',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._("Original Server") ,
                            width: Ung.Util.ipFieldWidth + 40, // +40 for column header
                            sortable: true,
                            dataIndex: 'c_server_addr'
                        }, {
                            header: i18n._("Original Server Port"),
                            width: Ung.Util.portFieldWidth + 40, // +40 for column header
                            sortable: true,
                            dataIndex: 'c_server_port',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._("Server") ,
                            width: Ung.Util.ipFieldWidth + 40, // +40 for column header
                            sortable: true,
                            dataIndex: 's_server_addr'
                        }, {
                            header: i18n._("Server Port"),
                            width: Ung.Util.portFieldWidth + 40, // +40 for column header
                            sortable: true,
                            dataIndex: 's_server_port',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._('Rule ID') + ' (Application Control)',
                            width: 70,
                            sortable: true,
                            dataIndex: 'application_control_ruleid',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._('Priority') + ' (Bandwidth Control)',
                            width: 120,
                            sortable: true,
                            dataIndex: 'bandwidth_control_priority',
                            renderer: function(value) {
                                if (Ext.isEmpty(value)) {
                                    return "";
                                }
                                switch(value) {
                                    case 0: return "";
                                    case 1: return i18n._("Very High");
                                    case 2: return i18n._("High");
                                    case 3: return i18n._("Medium");
                                    case 4: return i18n._("Low");
                                    case 5: return i18n._("Limited");
                                    case 6: return i18n._("Limited More");
                                    case 7: return i18n._("Limited Severely");
                                    default: return Ext.String.format(i18n._("Unknown Priority: {0}"), value);
                                }
                            }
                        }, {
                            header: i18n._('Rule') + ' (Bandwidth Control)',
                            width: 120,
                            sortable: true,
                            dataIndex: 'bandwidth_control_rule',
                            renderer: function(value) {
                                return Ext.isEmpty(value) ? i18n._("none") : value;
                            }
                        }, {
                            header: i18n._('Application') + ' (Application Control)',
                            width: 120,
                            sortable: true,
                            dataIndex: 'application_control_application'
                        }, {
                            header: i18n._('ProtoChain') + ' (Application Control)',
                            width: 180,
                            sortable: true,
                            dataIndex: 'application_control_protochain'
                        }, {
                            header: i18n._('Blocked') + ' (Application Control)',
                            width: Ung.Util.booleanFieldWidth,
                            sortable: true,
                            dataIndex: 'application_control_blocked',
                            filter: {
                                type: 'boolean',
                                yesText: 'true',
                                noText: 'false'
                            }
                        }, {
                            header: i18n._('Flagged') + ' (Application Control)',
                            width: Ung.Util.booleanFieldWidth,
                            sortable: true,
                            dataIndex: 'application_control_flagged',
                            filter: {
                                type: 'boolean',
                                yesText: 'true',
                                noText: 'false'
                            }
                        }, {
                            header: i18n._('Confidence') + ' (Application Control)',
                            width: Ung.Util.portFieldWidth,
                            sortable: true,
                            dataIndex: 'application_control_confidence',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._('Detail') + ' (Application Control)',
                            width: 200,
                            sortable: true,
                            dataIndex: 'application_control_detail'
                        },{
                            header: i18n._('Protocol') + ' (Application Control Lite)',
                            width: 120,
                            sortable: true,
                            dataIndex: 'application_control_lite_protocol'
                        }, {
                            header: i18n._('Blocked') + ' (Application Control Lite)',
                            width: Ung.Util.booleanFieldWidth,
                            sortable: true,
                            dataIndex: 'application_control_lite_blocked',
                            filter: {
                                type: 'boolean',
                                yesText: 'true',
                                noText: 'false'
                            }
                        }, {
                            header: i18n._('Rule ID') + ' (HTTPS Inspector)',
                            width: 70,
                            sortable: true,
                            dataIndex: 'ssl_inspector_ruleid',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._('Status') + ' (HTTPS Inspector)',
                            width: 100,
                            sortable: true,
                            dataIndex: 'ssl_inspector_status'
                        }, {
                            header: i18n._('Detail') + ' (HTTPS Inspector)',
                            width: 250,
                            sortable: true,
                            dataIndex: 'ssl_inspector_detail'
                        }, {
                            header: i18n._('Blocked') + ' (Firewall)',
                            width: Ung.Util.booleanFieldWidth,
                            sortable: true,
                            dataIndex: 'firewall_blocked',
                            filter: {
                                type: 'boolean',
                                yesText: 'true',
                                noText: 'false'
                            }
                        }, {
                            header: i18n._('Flagged') + ' (Firewall)',
                            width: Ung.Util.booleanFieldWidth,
                            sortable: true,
                            dataIndex: 'firewall_flagged',
                            filter: {
                                type: 'boolean',
                                yesText: 'true',
                                noText: 'false'
                            }
                        }, {
                            header: i18n._('Rule Id') + ' (Firewall)',
                            width: 60,
                            sortable: true,
                            flex:1,
                            dataIndex: 'firewall_rule_index',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._('Blocked') + ' (Intrusion Prevention)',
                            width: Ung.Util.booleanFieldWidth,
                            sortable: true,
                            dataIndex: 'ips_blocked',
                            filter: {
                                type: 'boolean',
                                yesText: 'true',
                                noText: 'false'
                            }
                        }, {
                            header: i18n._('Rule Id') + ' (Intrusion Prevention)',
                            width: 60,
                            sortable: true,
                            dataIndex: 'ips_ruleid'
                        }, {
                            header: i18n._('Rule Description') + ' (Intrusion Prevention)',
                            width: 150,
                            sortable: true,
                            flex:1,
                            dataIndex: 'ips_description'
                        }, {
                            header: i18n._('Rule ID') + ' (Captive Portal)',
                            width: 80,
                            dataIndex: 'captive_portal_rule_index'
                        }, {
                            header: i18n._('Captured') + ' (Captive Portal)',
                            width: 100,
                            sortable: true,
                            dataIndex: "captive_portal_blocked",
                            filter: {
                                type: 'boolean',
                                yesText: 'true',
                                noText: 'false'
                            }
                        }]
                    },
                    http_events: {
                        fields: [{
                            name: 'request_id',
                            sortType: 'asInt'
                        }, {
                            name: 'time_stamp',
                            sortType: 'asTimestamp'
                        }, {
                            name: 'session_id',
                            sortType: 'asInt'
                        }, {
                            name: 'client_intf',
                            sortType: 'asInt'
                        }, {
                            name: 'server_intf',
                            sortType: 'asInt'
                        }, {
                            name: 'c_client_addr',
                            sortType: 'asIp'
                        }, {
                            name: 'c_client_port',
                            sortType: 'asInt'
                        }, {
                            name: 'c_server_addr',
                            sortType: 'asIp'
                        }, {
                            name: 'c_server_port',
                            sortType: 'asInt'
                        }, {
                            name: 's_client_addr',
                            sortType: 'asIp'
                        }, {
                            name: 's_client_port',
                            sortType: 'asInt'
                        }, {
                            name: 's_server_addr',
                            sortType: 'asIp'
                        }, {
                            name: 's_server_port',
                            sortType: 'asInt'
                        }, {
                            name: 'username',
                            type: 'string'
                        }, {
                            name: 'hostname',
                            type: 'string'
                        }, {
                            name: 'method',
                            type: 'string'
                        }, {
                            name: 'domain',
                            type: 'string'
                        }, {
                            name: 'host',
                            type: 'string'
                        }, {
                            name: 'uri',
                            type: 'string'
                        }, {
                            name: 'c2s_content_length',
                            sortType: 'asInt'
                        }, {
                            name: 's2c_content_length',
                            sortType: 'asInt'
                        }, {
                            name: 's2c_content_type'
                        }, {
                            name: 'web_filter_lite_blocked',
                            type: 'boolean'
                        }, {
                            name: 'web_filter_blocked',
                            type: 'boolean'
                        }, {
                            name: 'web_filter_lite_flagged',
                            type: 'boolean'
                        }, {
                            name: 'web_filter_flagged',
                            type: 'boolean'
                        }, {
                            name: 'web_filter_lite_category',
                            type: 'string'
                        }, {
                            name: 'web_filter_category',
                            type: 'string'
                        }, {
                            name: 'web_filter_lite_reason',
                            type: 'string',
                            convert: Ung.panel.Reports.httpEventConvertReason
                        }, {
                            name: 'web_filter_reason',
                            type: 'string',
                            convert: Ung.panel.Reports.httpEventConvertReason
                        }, {
                            name: 'ad_blocker_action',
                            type: 'string',
                            convert: function(value) {
                                return (value == 'B')?i18n._("block") : i18n._("pass");
                            }
                        }, {
                            name: 'ad_blocker_cookie_ident',
                            type: 'string'
                        }, {
                            name: 'virus_blocker_clean',
                            type: 'boolean'
                        }, {
                            name: 'virus_blocker_name',
                            type: 'string'
                        }, {
                            name: 'virus_blocker_lite_clean',
                            type: 'boolean'
                        }, {
                            name: 'virus_blocker_lite_name',
                            type: 'string'
                        }],
                        columns: [{
                            header: i18n._("Request ID"),
                            width: Ung.Util.portFieldWidth,
                            sortable: true,
                            dataIndex: 'request_id'
                        }, {
                            header: i18n._("Timestamp"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: 'time_stamp',
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        }, {
                            header: i18n._("Session ID"),
                            width: Ung.Util.portFieldWidth,
                            sortable: true,
                            dataIndex: 'session_id'
                        }, {
                            header: i18n._("Client Interface") ,
                            width: Ung.Util.portFieldWidth + 40, // +40 for column header
                            sortable: true,
                            dataIndex: 'client_intf'
                        }, {
                            header: i18n._("Server Interface") ,
                            width: Ung.Util.portFieldWidth + 40, // +40 for column header
                            sortable: true,
                            dataIndex: 'server_intf'
                        }, {
                            header: i18n._("Client"),
                            width: Ung.Util.ipFieldWidth,
                            sortable: true,
                            dataIndex: 'c_client_addr'
                        }, {
                            header: i18n._("Client Port"),
                            width: Ung.Util.portFieldWidth,
                            sortable: true,
                            dataIndex: 'c_client_port',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._("New Client"),
                            width: Ung.Util.ipFieldWidth,
                            sortable: true,
                            dataIndex: 's_client_addr'
                        }, {
                            header: i18n._("New Client Port"),
                            width: Ung.Util.portFieldWidth,
                            sortable: true,
                            dataIndex: 's_client_port',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._("Original Server") ,
                            width: Ung.Util.ipFieldWidth + 40, // +40 for column header
                            sortable: true,
                            dataIndex: 'c_server_addr'
                        }, {
                            header: i18n._("Original Server Port"),
                            width: Ung.Util.portFieldWidth + 40, // +40 for column header
                            sortable: true,
                            dataIndex: 'c_server_port',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._("Server") ,
                            width: Ung.Util.ipFieldWidth + 40, // +40 for column header
                            sortable: true,
                            dataIndex: 's_server_addr'
                        }, {
                            header: i18n._("Server Port"),
                            width: Ung.Util.portFieldWidth + 40, // +40 for column header
                            sortable: true,
                            dataIndex: 's_server_port',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._("Hostname"),
                            width: Ung.Util.hostnameFieldWidth,
                            sortable: true,
                            dataIndex: 'hostname'
                        }, {
                            header: i18n._("Username"),
                            width: Ung.Util.usernameFieldWidth,
                            sortable: true,
                            dataIndex: 'username'
                        }, {
                            header: i18n._("Domain"),
                            width: Ung.Util.hostnameFieldWidth,
                            sortable: true,
                            dataIndex: 'domain'
                        }, {
                            header: i18n._("Host"),
                            width: Ung.Util.hostnameFieldWidth,
                            sortable: true,
                            dataIndex: 'host'
                        }, {
                            header: i18n._("Uri"),
                            flex:1,
                            width: Ung.Util.uriFieldWidth,
                            sortable: true,
                            dataIndex: 'uri'
                        }, {
                            header: i18n._("Method"),
                            width: Ung.Util.portFieldWidth,
                            sortable: true,
                            dataIndex: 'method'
                        }, {
                            header: i18n._("Download Content Length"),
                            width: Ung.Util.portFieldWidth,
                            sortable: true,
                            dataIndex: 's2c_content_length'
                        }, {
                            header: i18n._("Upload Content Length"),
                            width: Ung.Util.portFieldWidth,
                            sortable: true,
                            dataIndex: 'c2s_content_length'
                        }, {
                            header: i18n._("Content Type"),
                            width: 150,
                            sortable: true,
                            dataIndex: 's2c_content_type'
                        }, {
                            header: i18n._("Blocked") + " (Web Filter Lite)",
                            width: Ung.Util.booleanFieldWidth,
                            sortable: true,
                            dataIndex: 'web_filter_lite_blocked',
                            filter: {
                                type: 'boolean',
                                yesText: 'true',
                                noText: 'false'
                            }
                        }, {
                            header: i18n._("Flagged") + " (Web Filter Lite)",
                            width: Ung.Util.booleanFieldWidth,
                            dataIndex: 'web_filter_lite_flagged',
                            filter: {
                                type: 'boolean',
                                yesText: 'true',
                                noText: 'false'
                            }
                        }, {
                            header: i18n._("Reason For Action") + " (Web Filter Lite)",
                            width: 150,
                            sortable: true,
                            dataIndex: 'web_filter_lite_reason'
                        }, {
                            header: i18n._("Category") + " (Web Filter Lite)",
                            width: 120,
                            sortable: true,
                            dataIndex: 'web_filter_lite_category'
                        }, {
                            header: i18n._("Blocked") + " (Web Filter)",
                            width: Ung.Util.booleanFieldWidth,
                            sortable: true,
                            dataIndex: 'web_filter_blocked',
                            filter: {
                                type: 'boolean',
                                yesText: 'true',
                                noText: 'false'
                            }
                        }, {
                            header: i18n._("Flagged") + " (Web Filter)",
                            width: Ung.Util.booleanFieldWidth,
                            sortable: true,
                            dataIndex: 'web_filter_flagged',
                            filter: {
                                type: 'boolean',
                                yesText: 'true',
                                noText: 'false'
                            }
                        }, {
                            header: i18n._("Reason For Action") +  " (Web Filter)",
                            width: 150,
                            sortable: true,
                            dataIndex: 'web_filter_reason'
                        }, {
                            header: i18n._("Category") + " (Web Filter)",
                            width: 120,
                            sortable: true,
                            dataIndex: 'web_filter_category'
                        }, {
                            header: i18n._("Action") + " (Ad Blocker)",
                            width: 120,
                            sortable: true,
                            dataIndex: 'ad_blocker_action'
                        }, {
                            header: i18n._("Blocked Cookie") + " (Ad Blocker)",
                            width: 100,
                            sortable: true,
                            dataIndex: 'ad_blocker_cookie_ident'
                        }, {
                            header: i18n._('Clean') + ' (Virus Blocker Lite)',
                            width: Ung.Util.booleanFieldWidth,
                            sortable: true,
                            dataIndex: 'virus_blocker_lite_clean'
                        }, {
                            header: i18n._('Virus Name') + ' (Virus Blocker Lite)',
                            width: 140,
                            sortable: true,
                            dataIndex: 'virus_blocker_lite_name'
                        }, {
                            header: i18n._('Clean') + ' (Virus Blocker)',
                            width: Ung.Util.booleanFieldWidth,
                            sortable: true,
                            dataIndex: 'virus_blocker_clean'
                        }, {
                            header: i18n._('Virus Name') + ' (Virus Blocker)',
                            width: 140,
                            sortable: true,
                            dataIndex: 'virus_blocker_name'
                        }]
                    },
                    http_query_events: {
                        fields: [{
                            name: 'time_stamp',
                            sortType: 'asTimestamp'
                        }, {
                            name: 'c_client_addr',
                            sortType: 'asIp'
                        }, {
                            name: 'username'
                        }, {
                            name: 'hostname'
                        }, {
                            name: 'c_server_addr',
                            sortType: 'asIp'
                        }, {
                            name: 's_server_port',
                            sortType: 'asInt'
                        }, {
                            name: 'host'
                        }, {
                            name: 'uri'
                        }, {
                            name: 'term'
                        }],
                        columns: [{
                            header: i18n._("Timestamp"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: 'time_stamp',
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        }, {
                            header: i18n._("Hostname"),
                            width: Ung.Util.hostnameFieldWidth,
                            sortable: true,
                            dataIndex: 'hostname'
                        }, {
                            header: i18n._("Client"),
                            width: Ung.Util.ipFieldWidth,
                            sortable: true,
                            dataIndex: 'c_client_addr'
                        }, {
                            header: i18n._("Username"),
                            width: Ung.Util.usernameFieldWidth,
                            sortable: true,
                            dataIndex: 'username'
                        }, {
                            header: i18n._("Host"),
                            width: Ung.Util.hostnameFieldWidth,
                            sortable: true,
                            dataIndex: 'host'
                        }, {
                            header: i18n._("Uri"),
                            flex:1,
                            width: Ung.Util.uriFieldWidth,
                            sortable: true,
                            dataIndex: 'uri'
                        }, {
                            header: i18n._("Query Term"),
                            flex:1,
                            width: Ung.Util.uriFieldWidth,
                            sortable: true,
                            dataIndex: 'term'
                        }, {
                            header: i18n._("Server"),
                            width: Ung.Util.ipFieldWidth,
                            sortable: true,
                            dataIndex: 'c_server_addr'
                        }, {
                            header: i18n._("Server Port"),
                            width: Ung.Util.portFieldWidth,
                            sortable: true,
                            dataIndex: 's_server_port',
                            filter: {
                                type: 'numeric'
                            }
                        }]
                    },
                    mail_addrs: {
                        fields: [{
                            name: 'time_stamp',
                            sortType: 'asTimestamp'
                        }, {
                            name: 'hostname'
                        }, {
                            name: 'c_client_addr',
                            sortType: 'asIp'
                        }, {
                            name: 'username'
                        }, {
                            name: 'c_server_addr',
                            sortType: 'asIp'
                        }, {
                            name: 's_server_addr',
                            sortType: 'asIp'
                        }, {
                            name: 'virus_blocker_name'
                        }, {
                            name: 'virus_blocker_lite_name'
                        }, {
                            name: 'subject',
                            type: 'string'
                        }, {
                            name: 'addr',
                            type: 'string'
                        }, {
                            name: 'sender',
                            type: 'string'
                        }, {
                            name: 'vendor'
                        }, {
                            name:  'spam_blocker_lite_action',
                            type: 'string',
                            convert: Ung.panel.Reports.mailEventConvertAction
                        }, {
                            name: 'spam_blocker_lite_score'
                        }, {
                            name: 'spam_blocker_lite_is_spam',
                            type: 'boolean'
                        }, {
                            name: 'spam_blocker_lite_tests_string'
                        }, {
                            name:  'spam_blocker_action',
                            type: 'string',
                            convert: Ung.panel.Reports.mailEventConvertAction
                        }, {
                            name: 'spam_blocker_score'
                        }, {
                            name: 'spam_blocker_is_spam',
                            type: 'boolean'
                        }, {
                            name: 'spam_blocker_tests_string'
                        }, {
                            name:  'phish_blocker_action',
                            type: 'string',
                            convert: Ung.panel.Reports.mailEventConvertAction
                        }, {
                            name: 'phish_blocker_score'
                        }, {
                            name: 'phish_blocker_is_spam',
                            type: 'boolean'
                        }, {
                            name: 'phish_blocker_tests_string'
                        }],
                        columns: [{
                            header: i18n._("Timestamp"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: 'time_stamp',
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        }, {
                            header: i18n._("Hostname"),
                            width: Ung.Util.hostnameFieldWidth,
                            sortable: true,
                            dataIndex: 'hostname'
                        }, {
                            header: i18n._("Client"),
                            width: Ung.Util.ipFieldWidth,
                            sortable: true,
                            dataIndex: 'c_client_addr'
                        }, {
                            header: i18n._("Server"),
                            width: Ung.Util.ipFieldWidth,
                            sortable: true,
                            dataIndex: 'c_server_addr'
                        }, {
                            header: i18n._("Server"),
                            width: Ung.Util.ipFieldWidth,
                            sortable: true,
                            dataIndex: 's_server_addr'
                        }, { 
                            header: 'Virus Blocker Lite ' + i18n._('Name'),
                            width: 140,
                            sortable: true,
                            dataIndex: 'virus_blocker_lite_name'
                        }, {
                            header: 'Virus Blocker ' + i18n._('Name'),
                            width: 140,
                            sortable: true,
                            dataIndex: 'virus_blocker_name'
                        }, {
                            header: i18n._("Receiver"),
                            width: Ung.Util.emailFieldWidth,
                            sortable: true,
                            dataIndex: 'addr'
                        }, {
                            header: i18n._("Sender"),
                            width: Ung.Util.emailFieldWidth,
                            sortable: true,
                            dataIndex: 'sender'
                        }, {
                            header: i18n._("Subject"),
                            flex:1,
                            width: 150,
                            sortable: true,
                            dataIndex: 'subject'
                        }, {
                            header: i18n._("Action (Spam Blocker Lite)"),
                            width: 125,
                            sortable: true,
                            dataIndex: 'spam_blocker_lite_action'
                        }, {
                            header: i18n._("Spam Score (Spam Blocker Lite)"),
                            width: 70,
                            sortable: true,
                            dataIndex: 'spam_blocker_lite_score',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._("Is Spam (Spam Blocker Lite)"),
                            width: 70,
                            sortable: true,
                            dataIndex: 'spam_blocker_lite_is_spam'
                        }, {
                            header: i18n._("Detail (Spam Blocker Lite)"),
                            width: 125,
                            sortable: true,
                            dataIndex: 'spam_blocker_lite_tests_string'
                        }, {
                            header: i18n._("Action (Spam Blocker)"),
                            width: 125,
                            sortable: true,
                            dataIndex: 'spam_blocker_action'
                        }, {
                            header: i18n._("Spam Score (Spam Blocker)"),
                            width: 70,
                            sortable: true,
                            dataIndex: 'spam_blocker_score',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._("Is Spam (Spam Blocker)"),
                            width: 70,
                            sortable: true,
                            dataIndex: 'spam_blocker_is_spam'
                        }, {
                            header: i18n._("Detail (Spam Blocker)"),
                            width: 125,
                            sortable: true,
                            dataIndex: ''
                        }, {
                            header: i18n._("Action (Phish Blocker)"),
                            width: 125,
                            sortable: true,
                            dataIndex: 'phish_blocker_action'
                        }, {
                            header: i18n._("Is Phish (Phish Blocker)"),
                            width: 70,
                            sortable: true,
                            dataIndex: 'phish_blocker_is_spam'
                        }, {
                            header: i18n._("Detail (Phish Blocker)"),
                            width: 125,
                            sortable: true,
                            dataIndex: 'phish_blocker_tests_string'
                        }]
                    },
                    directory_connector_login_events: {
                        fields: [{
                            name: 'id'
                        }, {
                            name: 'time_stamp',
                            sortType: 'asTimestamp'
                        }, {
                            name: 'login_name'
                        }, {
                            name: 'type'
                        }, {
                            name: 'client_addr',
                            sortType: 'asIp'
                        }],
                        columns: [{
                            header: i18n._("Timestamp"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: 'time_stamp',
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        }, {
                            header: i18n._("Client"),
                            width: Ung.Util.ipFieldWidth,
                            sortable: true,
                            dataIndex: 'client_addr'
                        }, {
                            header: i18n._("Username"),
                            width: Ung.Util.usernameFieldWidth,
                            sortable: true,
                            dataIndex: 'login_name'
                        }, {
                            header: i18n._('Action'),
                            width: 100,
                            sortable: true,
                            dataIndex: 'type',
                            renderer: Ext.bind(function(value) {
                                switch(value) {
                                    case "I": return i18n._("login");
                                    case "U": return i18n._("update");
                                    case "O": return i18n._("logout");
                                    default: return i18n._("unknown");
                                }
                            }, this)
                        }]
                    },
                    admin_logins: {
                        fields: [{
                            name: 'time_stamp',
                            sortType: 'asTimestamp'
                        }, {
                            name: 'login',
                            type: 'string'
                        }, {
                            name: 'succeeded',
                            type: 'string',
                            convert: Ext.bind(function(value) {
                                return value ?  i18n._("success"): i18n._("failed");
                            }, this)
                        }, {
                            name: 'local',
                            type: 'string',
                            convert: Ext.bind(function(value) {
                                return value ?  i18n._("local"): i18n._("remote");
                            }, this)
                        }, {
                            name: 'client_address',
                            type: 'string'
                        }, {
                            name: 'reason',
                            type: 'string'
                        }],
                        columns: [{
                            header: i18n._("Timestamp"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: 'time_stamp',
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        }, {
                            header: i18n._("Login"),
                            width: 120,
                            sortable: true,
                            dataIndex: 'login'
                        }, {
                            header: i18n._("Success"),
                            width: 120,
                            sortable: true,
                            dataIndex: 'succeeded'
                        }, {
                            header: i18n._("Local"),
                            width: 120,
                            sortable: true,
                            dataIndex: 'local'
                        }, {
                            header: i18n._("Client Address"),
                            width: Ung.Util.ipFieldWidth,
                            sortable: true,
                            dataIndex: 'client_addr'
                        }, {
                            header: i18n._('Reason'),
                            width: 200,
                            sortable: true,
                            dataIndex: 'reason',
                            renderer: Ext.bind(function(value) {
                                switch(value) {
                                    case "U": return i18n._("invalid username");
                                    case "P": return i18n._("invalid password");
                                    default: return i18n._("");
                                }
                            }, this)
                        }]
                    },
                    configuration_backup_events: {
                        fields: [{
                            name: 'time_stamp',
                            sortType: 'asTimestamp'
                        }, {
                            name: 'success',
                            type: 'string',
                            convert: Ext.bind(function(value) {
                                return value ?  i18n._("success"): i18n._("failed");
                            }, this)
                        }, {
                            name: 'description',
                            type: 'string'
                        }],
                        columns: [{
                            header: i18n._("Timestamp"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: 'time_stamp',
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        }, {
                            header: i18n._("Action"),
                            width: 120,
                            sortable: false,
                            renderer: Ext.bind(function(value) {
                                return i18n._("backup");
                            }, this)
                        }, {
                            header: i18n._("Result"),
                            width: 120,
                            sortable: true,
                            dataIndex: 'success'
                        }, {
                            header: i18n._("Details"),
                            flex:1,
                            width: 200,
                            sortable: true,
                            dataIndex: 'description'
                        }]
                    },
                    wan_failover_test_events: {
                        fields: [{
                            name: "time_stamp",
                            sortType: 'asTimestamp'
                        },{
                            name: "interfaceId"
                        },{
                            name: "name"
                        },{
                            name: "success"
                        },{
                            name: "description"
                        }],
                        columns: [{
                            header: i18n._("Timestamp"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: 'time_stamp',
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        },{
                            header: i18n._("Interface"),
                            width: 120,
                            sortable: true,
                            dataIndex: "name"
                        },{
                            header: i18n._("Success"),
                            width: 120,
                            sortable: true,
                            dataIndex: "success",
                            filter: {
                                type: 'boolean',
                                yesText: 'true',
                                noText: 'false'
                            }
                        },{
                            header: i18n._("Test Description"),
                            width: 120,
                            sortable: true,
                            dataIndex: "description",
                            flex:1
                        }]
                    },
                    wan_failover_action_events: {
                        fields: [{
                            name: "time_stamp",
                            sortType: 'asTimestamp'
                        },{
                            name: "interface_id"
                        },{
                            name: "name"
                        },{
                            name: "action"
                        }],
                        columns: [{
                            header: i18n._("Timestamp"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: 'time_stamp',
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        },{
                            header: i18n._("Interface"),
                            width: 120,
                            sortable: true,
                            dataIndex: "name"
                        },{
                            header: i18n._("Action"),
                            width: 120,
                            sortable: true,
                            dataIndex: "action"
                        }]
                    },
                    ipsec_user_events: {
                        fields: [{
                            name: "client_username"
                        },{
                            name: "client_protocol"
                        },{
                            name: "connect_stamp",
                            sortType: 'asTimestamp'
                        },{
                            name: "goodbye_stamp",
                            sortType: 'asTimestamp'
                        },{
                            name: "elapsed_time"
                        },{
                            name: "client_address",
                            sortType: 'asIp'
                        },{
                            name: "net_interface"
                        },{
                            name: "net_process"
                        },{
                            name: "rx_bytes"
                        },{
                            name: "tx_bytes"
                        }],
                        columns: [{
                            header: i18n._("Address"),
                            width: Ung.Util.ipFieldWidth,
                            sortable: true,
                            dataIndex: "client_address"
                        },{
                            header: i18n._("Username"),
                            width: Ung.Util.usernameFieldWidth,
                            sortable: true,
                            dataIndex: "client_username"
                        },{
                            header: i18n._("Protocol"),
                            width: 120,
                            sortable: true,
                            dataIndex: "client_protocol"
                        },{
                            header: i18n._("Login Time"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: "connect_stamp",
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        },{
                            header: i18n._("Logout Time"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: "goodbye_stamp",
                            renderer: function(value) {
                                return (value ==="" ? "" : i18n.timestampFormat(value));
                            }
                        },{
                            header: i18n._("Elapsed"),
                            width: 120,
                            sortable: true,
                            dataIndex: "elapsed_time"
                        },{
                            header: i18n._("Interface"),
                            width: 80,
                            sortable: true,
                            dataIndex: "net_interface"
                        },{
                            header: i18n._("RX Bytes"),
                            width: 120,
                            sortable: true,
                            dataIndex: "rx_bytes"
                        },{
                            header: i18n._("TX Bytes"),
                            width: 120,
                            sortable: true,
                            dataIndex: "tx_bytes"
                        }]
                    },
                    smtp_tarpit_events: {
                        fields: [{
                            name: 'time_stamp',
                            sortType: 'asTimestamp'
                        }, {
                            name: 'skipped',
                            type: 'string',
                            convert: Ext.bind(function(value) {
                                return value ? i18n._("skipped"): i18n._("blocked");
                            }, this)
                        }, {
                            name: 'ipaddr',
                            convert: function(value) {
                                return value == null ? "": value;
                            }
                        }, {
                            name: 'hostname'
                        }],
                        // the list of columns
                        columns: [{
                            header: i18n._("Timestamp"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: 'time_stamp',
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        }, {
                            header: i18n._("Action"),
                            width: 120,
                            sortable: true,
                            dataIndex: 'skipped'
                        }, {
                            header: i18n._("Sender"),
                            width: 120,
                            sortable: true,
                            dataIndex: 'ipaddr'
                        }, {
                            header: i18n._("DNSBL Server"),
                            width: 120,
                            sortable: true,
                            dataIndex: 'hostname'
                        }]
                    },
                    webcache_stats: {
                        fields: [{
                            name: 'time_stamp',
                            sortType: 'asTimestamp'
                        }, {
                            name: 'hits'
                        }, {
                            name: 'misses'
                        }, {
                            name: 'bypasses'
                        }, {
                            name: 'systems'
                        }, {
                            name: 'hit_bytes'
                        }, {
                            name: 'miss_bytes'
                        }],
                        columns: [{
                            header: i18n._("Timestamp"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: 'time_stamp',
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        }, {
                            header: i18n._("Hit Count"),
                            width: 120,
                            sortable: false,
                            dataIndex: 'hits',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._("Miss Count"),
                            width: 120,
                            sortable: false,
                            dataIndex: 'misses',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._("Bypass Count"),
                            width: 120,
                            sortable: false,
                            dataIndex: 'bypasses',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._("System Count"),
                            width: 120,
                            sortable: false,
                            dataIndex: 'systems',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._("Hit Bytes"),
                            width: 120,
                            sortable: true,
                            dataIndex: 'hit_bytes',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._("Miss Bytes"),
                            width: 120,
                            sortable: true,
                            dataIndex: 'miss_bytes',
                            filter: {
                                type: 'numeric'
                            }
                        }]
                    },
                    capture_user_events: {
                        fields: [{
                            name: "time_stamp",
                            sortType: 'asTimestamp'
                        },{
                            name: "client_addr",
                            sortType: 'asIp'
                        },{
                            name: "login_name"
                        },{
                            name: "auth_type"
                        },{
                            name: "event_info"
                        }],
                        columns: [{
                            header: i18n._("Timestamp"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: "time_stamp",
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        },{
                            header: i18n._("Client"),
                            width: Ung.Util.ipFieldWidth,
                            sortable: true,
                            dataIndex: "client_addr"
                        },{
                            header: i18n._("Username"),
                            width: Ung.Util.usernameFieldWidth,
                            sortable: true,
                            dataIndex: "login_name",
                            flex:1
                        },{
                            header: i18n._("Action"),
                            width: 165,
                            sortable: true,
                            dataIndex: "event_info",
                            renderer: Ext.bind(function( value ) {
                                switch ( value ) {
                                    case "LOGIN":
                                        return i18n._( "Login Success" );
                                    case "FAILED":
                                        return i18n._( "Login Failure" );
                                    case "TIMEOUT":
                                        return i18n._( "Session Timeout" );
                                    case "INACTIVE":
                                        return i18n._( "Idle Timeout" );
                                    case "USER_LOGOUT":
                                        return i18n._( "User Logout" );
                                    case "ADMIN_LOGOUT":
                                        return i18n._( "Admin Logout" );
                                }
                                return "";
                            }, this )
                        },{
                            header: i18n._("Authentication"),
                            width: 165,
                            sortable: true,
                            dataIndex: "auth_type",
                            renderer: Ext.bind(function( value ) {
                                switch ( value ) {
                                    case "NONE":
                                        return i18n._( "None" );
                                    case "LOCAL_DIRECTORY":
                                        return i18n._( "Local Directory" );
                                    case "ACTIVE_DIRECTORY":
                                        return i18n._( "Active Directory" );
                                    case "RADIUS":
                                        return i18n._( "RADIUS" );
                                    case "CUSTOM":
                                        return i18n._( "Custom" );
                                }
                                return "";
                            }, this )
                        }]
                    },
                    intrusion_prevention_events: {
                        fields: [{
                            name: 'time_stamp',
                            sortType: 'asTimestamp'
                        }, {
                            name: 'sig_id',
                            sortType: 'asInt'
                        }, {
                            name: 'gen_id',
                            sortType: 'asInt'
                        }, {
                            name: 'class_id',
                            sortType: 'asInt'
                        }, {
                            name: 'source_addr',
                            sortType: 'asIp'
                        }, {
                            name: 'source_port',
                            sortType: 'asInt'
                        }, {
                            name: 'dest_addr',
                            sortType: 'asIp'
                        }, {
                            name: 'dest_port',
                            sortType: 'asInt'
                        }, {
                            name: 'protocol',
                            sortType: 'asInt'
                        }, {
                            name: 'blocked',
                            type: 'boolean'
                        }, {
                            name: 'category',
                            type: 'string'
                        }, {
                            name: 'classtype',
                            type: 'string'
                        }, {
                            name: 'msg',
                            type: 'string'
                        }],
                        columns: [{
                            header: i18n._("Timestamp"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: 'time_stamp',
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        }, {
                            header: i18n._("Sid"),
                            width: 70,
                            sortable: true,
                            dataIndex: 'sig_id',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._("Gid"),
                            width: 70,
                            sortable: true,
                            dataIndex: 'gen_id',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._("Cid"),
                            width: 70,
                            sortable: true,
                            dataIndex: 'class_id',
                            filter: {
                                type: 'numeric'
                            }
                        }, {
                            header: i18n._("Source Address"),
                            width: Ung.Util.ipFieldWidth,
                            sortable: true,
                            dataIndex: 'source_addr'
                        }, {
                            header: i18n._("Source port"),
                            width: Ung.Util.portFieldWidth,
                            sortable: true,
                            dataIndex: 'source_port',
                            filter: {
                                type: 'numeric'
                            },
                            renderer: function(value, metaData, record, row, col, store, gridView){
                                if( record.get("protocol") == 1 ){
                                    return "";
                                }
                                return value;
                            }
                        }, {
                            header: i18n._("Destination Address"),
                            width: Ung.Util.ipFieldWidth,
                            sortable: true,
                            dataIndex: 'dest_addr'
                        }, {
                            header: i18n._("Destination port"),
                            width: Ung.Util.portFieldWidth,
                            sortable: true,
                            dataIndex: 'dest_port',
                            filter: {
                                type: 'numeric'
                            },
                            renderer: function(value, metaData, record, row, col, store, gridView){
                                if( record.get("protocol") == 1 ){
                                    return "";
                                }
                                return value;
                            }
                        }, {
                            header: i18n._("Protocol"),
                            width: 70,
                            sortable: true,
                            dataIndex: 'protocol',
                            renderer: function(value, metaData, record, row, col, store, gridView){
                                switch(value){
                                    case 1:
                                        return i18n._("ICMP");
                                    case 17:
                                        return i18n._("UDP");
                                    case 6:
                                        return i18n._("TCP");
                                }
                                return value;
                            }
                        }, {
                            header: i18n._("Blocked"),
                            width: Ung.Util.booleanFieldWidth,
                            sortable: true,
                            dataIndex: 'blocked',
                            filter: {
                                type: 'boolean',
                                yesText: 'true',
                                noText: 'false'
                            }
                        }, {
                            header: i18n._("Category"),
                            width: 200,
                            sortable: true,
                            dataIndex: 'category'
                        }, {
                            header: i18n._("Classtype"),
                            width: 200,
                            sortable: true,
                            dataIndex: 'classtype'
                        }, {
                            header: i18n._("Msg"),
                            width: 200,
                            sortable: true,
                            dataIndex: 'msg'
                        }]
                    },
                    openvpn_events: {
                        fields: [{
                            name: 'time_stamp',
                            sortType: 'asTimestamp'
                        }, {
                            name: 'type'
                        }, {
                            name: 'client_name'
                        }, {
                            name: 'remote_address',
                            sortType: 'asIp'
                        }, {
                            name: 'pool_address',
                            sortType: 'asIp'
                        }],
                        columns: [{
                            header: i18n._("Timestamp"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: 'time_stamp',
                            renderer: Ext.bind(function(value) {
                                return i18n.timestampFormat(value);
                            }, this )
                        }, {
                            header: i18n._("Type"),
                            sortable: true,
                            dataIndex: 'type'
                        }, {
                            header: i18n._("Client Name"),
                            sortable: true,
                            dataIndex: 'client_name'
                        }, {
                            header: i18n._("Client Address"),
                            sortable: true,
                            dataIndex: 'remote_address'
                        }, {
                            header: i18n._("Pool Address"),
                            sortable: true,
                            dataIndex: 'pool_address'
                        }]
                    },
                    alerts: {
                        fields: [{
                            name: "time_stamp",
                            sortType: 'asTimestamp'
                        },{
                            name: "description"
                        },{
                            name: "summary_text"
                        },{
                            name: "json"
                        }],
                        // the list of columns
                        columns: [{
                            header: i18n._("Timestamp"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: 'time_stamp',
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        },{
                            header: i18n._("Description"),
                            width: 200,
                            sortable: true,
                            dataIndex: "description"
                        },{
                            header: i18n._("Summary Text"),
                            flex: 1,
                            width: 500,
                            sortable: true,
                            dataIndex: "summary_text"
                        },{
                            header: i18n._("JSON"),
                            width: 500,
                            sortable: true,
                            dataIndex: "json"
                        }]
                    },
                    ftp_events: {
                        fields: [{
                            name: 'time_stamp',
                            sortType: 'asTimestamp'
                        }, {
                            name: 'c_client_addr',
                            sortType: 'asIp'
                        }, {
                            name: 'username'
                        }, {
                            name: 'c_server_addr',
                            sortType: 'asIp'
                        }, {
                            name: 'uri'
                        }, {
                            name: 'location'
                        }, {
                            name: 'virus_blocker_lite_name'
                        }, {
                            name: 'virus_blocker_name'
                        }],
                        // the list of columns
                        columns: [{
                            header: i18n._("Timestamp"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: 'time_stamp',
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        }, {
                            header: i18n._("Client"),
                            width: Ung.Util.ipFieldWidth,
                            sortable: true,
                            dataIndex: 'c_client_addr'
                        }, {
                            header: i18n._("Username"),
                            width: Ung.Util.usernameFieldWidth,
                            sortable: true,
                            dataIndex: 'username'
                        }, {
                            header: i18n._("File Name"),
                            flex:1,
                            width: Ung.Util.uriFieldWidth,
                            dataIndex: 'uri'
                        }, {
                            header: 'Virus Blocker Lite ' + i18n._('Name'),
                            width: 140,
                            sortable: true,
                            dataIndex: 'virus_blocker_lite_name'
                        }, {
                            header: 'Virus Blocker ' + i18n._('Name'),
                            width: 140,
                            sortable: true,
                            dataIndex: 'virus_blocker_name'
                        }, {
                            header: i18n._("Server"),
                            width: Ung.Util.ipFieldWidth,
                            sortable: true,
                            dataIndex: 'c_server_addr'
                        }]
                    },
                    penaltybox: {
                        fields: [{
                            name: 'time_stamp',
                            sortType: 'asTimestamp'
                        }, {
                            name: 'address',
                            sortType: 'asIp'
                        }, {
                            name: 'reason'
                        }, {
                            name: 'start_time',
                            sortType: 'asTimestamp'
                        }, {
                            name: 'end_time',
                            sortType: 'asTimestamp'
                        }],
                        columns: [{
                            header: i18n._("Timestamp"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: 'time_stamp',
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        }, {
                            header: i18n._("Address"),
                            width: Ung.Util.ipFieldWidth,
                            sortable: true,
                            dataIndex: 'address'
                        }, {
                            header: i18n._("Reason"),
                            sortable: true,
                            flex: 1,
                            dataIndex: 'reason'
                        }, {
                            header: i18n._("Start Time"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: 'start_time',
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        }, {
                            header: i18n._("End Time"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: 'end_time',
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        }]
                    },
                    quotas: {
                        fields: [{
                            name: 'time_stamp',
                            sortType: 'asTimestamp'
                        }, {
                            name: 'address',
                            sortType: 'asIp'
                        }, {
                            name: 'action'
                        }, {
                            name: 'size',
                            sortType: 'asInt'
                        }, {
                            name: 'reason'
                        }],
                        columns: [{
                            header: i18n._("Timestamp"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: 'time_stamp',
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        }, {
                            header: i18n._("Address"),
                            width: Ung.Util.ipFieldWidth,
                            sortable: true,
                            dataIndex: 'address'
                        }, {
                            header: i18n._("Action"),
                            sortable: true,
                            dataIndex: 'action'
                        }, {
                            header: i18n._("Size"),
                            sortable: true,
                            dataIndex: 'size'
                        }, {
                            header: i18n._("Reason"),
                            sortable: true,
                            flex: 1,
                            dataIndex: 'reason'
                        }]
                    },
                    settings_changes: {
                        fields: [{
                            name: 'time_stamp',
                            sortType: 'asTimestamp'
                        }, {
                            name: 'username'
                        }, {
                            name: 'hostname'
                        }, {
                            name: 'settings_file'
                        }, {
                            name: 'actions'
                        }],
                        // the list of columns
                        columns: [{
                            header: i18n._("Timestamp"),
                            width: Ung.Util.timestampFieldWidth,
                            sortable: true,
                            dataIndex: 'time_stamp',
                            renderer: function(value) {
                                return i18n.timestampFormat(value);
                            }
                        }, {
                            header: i18n._("Username"),
                            width: Ung.Util.usernameFieldWidth,
                            sortable: true,
                            dataIndex: 'username'
                        }, {
                            header: i18n._("Hostname"),
                            width: Ung.Util.hostnameFieldWidth,
                            sortable: true,
                            dataIndex: 'hostname'
                        }, {
                            header: i18n._("Settings File"),
                            flex:1,
                            width: Ung.Util.uriFieldWidth,
                            dataIndex: 'settings_file',
                            renderer: function( value ){
                                value = value.replace( /^.*\/settings\//, "" );
                                return value;
                            }
                        }, {
                            header: i18n._("Differences"),
                            xtype: 'actioncolumn',
                            align: 'center',
                            dataIndex: 'settings_file',
                            width: 100,
                            items: [{
                                icon: '/skins/default/images/admin/icons/icon_detail.png',
                                tooltip: i18n._("Show difference between previous version"),
                                handler: function(grid, rowIndex, colIndex, item, e, record){
                                    if( !this.diffWindow ){
                                        var columnRenderer = function(value, meta, record){
                                            var action = record.get("action");
                                            if( action == 3){
                                                meta.style = "background-color:#ffff99";
                                            }else if(action == 2){
                                                meta.style = "background-color:#ffdfd9";
                                            }else if(action == 1){
                                                meta.style = "background-color:#d9f5cb";
                                            }
                                            return value;
                                        };
                                        this.diffWindow = Ext.create('Ext.Window',{
                                            layout: 'fit',
                                            width: Ext.getBody().getViewSize().width,
                                            height: Ext.getBody().getViewSize().height,
                                            modal: true,
                                            title: i18n._('Settings Difference'),
                                            closeAction: 'hide',
                                            items: {
                                                xtype: 'grid',
                                                cls: 'diff-grid',
                                                store: Ext.create( 'Ext.data.Store',{
                                                    fields: [ 'line', 'previous', 'current', 'action' ],
                                                    data: []
                                                    }
                                                ),
                                                columns:[{
                                                    text: i18n._("Line"),
                                                    dataIndex: "line",
                                                    renderer: columnRenderer
                                                },{
                                                    text: i18n._("Previous"),
                                                    flex: 1,
                                                    dataIndex: "previous",
                                                    renderer: columnRenderer
                                                },{
                                                    text: i18n._("Current"),
                                                    flex: 1,
                                                    dataIndex: "current",
                                                    renderer: columnRenderer
                                                }]
                                            },
                                            buttons: [{
                                                text: i18n._("Close"),
                                                handler: Ext.bind(function() {
                                                    this.diffWindow.destroy();
                                                    this.diffWindow = null;
                                                }, this)
                                            }],
                                            update: function(fileName){
                                                rpc.reportingManagerNew.getSettingsDiff(Ext.bind(function(result,exception){
                                                    if(Ung.Util.handleException(exception)){
                                                        return;
                                                    }
                                                    var diffData = [];
                                                    var diffLines = result.split("\n");
                                                    var lineNum;
                                                    var action;
                                                    for( var i = 0; i < diffLines.length; i++){
                                                        lineNum = (i + 1);

                                                        previousAction = diffLines[i].substr(0,1);
                                                        previousLine = diffLines[i].substr(1,510);
                                                        currentAction = diffLines[i].substr(511,1);
                                                        currentLine = diffLines[i].substr(512);
                                                        
                                                        if( previousAction != "<" && previousAction != ">"){
                                                            previousLine = previousAction + previousLine;
                                                            previousAction = -1;
                                                        }
                                                        if( currentAction != "<" && currentAction != ">" && currentAction != "|"){
                                                            currentLine = currentAction + currentLine;
                                                            currentAction = -1;
                                                        }

                                                        if( currentAction == "|" ){
                                                            action = 3;
                                                        }else if(currentAction == "<"){
                                                            action = 2;
                                                        }else if(currentAction == ">"){
                                                            action = 1;
                                                        }else{
                                                            action = 0;
                                                        }

                                                        diffData.push({
                                                            line: (i + 1),
                                                            previous: previousLine.replace(/\s+$/,"").replace(/\s/g, "&nbsp;"),
                                                            current: currentLine.replace(/\s+$/,"").replace(/\s/g, "&nbsp;"),
                                                            action: action
                                                        });
                                                    }

                                                    this.down("grid").store.loadData(diffData);
                                                },this), fileName);
                                            }
                                        });
                                    }
                                    this.diffWindow.show();
                                    this.diffWindow.update(record.get("settings_file"));
                                }
                            }]
                        }]
                    }
                };
                var key, columns, i;
                for(key in this.tableConfig) {
                    columns = this.tableConfig[key].columns;
                    for(i=0; i<columns.length; i++) {
                        if(columns[i].dataIndex && !columns[i].renderer && !columns[i].filter) {
                            columns[i].filter = { type: 'string' };
                        }
                    }
                }
            }
            return this.tableConfig[table];
        },
        httpEventConvertReason: function(value) {
            if(Ext.isEmpty(value)) {
                return null;
            }
            switch (value) {
              case 'D': return i18n._("in Categories Block list");
              case 'U': return i18n._("in URLs Block list");
              case 'E': return i18n._("in File Extensions Block list");
              case 'M': return i18n._("in MIME Types Block list");
              case 'H': return i18n._("Hostname is an IP address");
              case 'I': return i18n._("in URLs Pass list");
              case 'R': return i18n._("in URLs Pass list (via referer)");
              case 'C': return i18n._("in Clients Pass list");
              case 'B': return i18n._("Client Bypass");
              default: return i18n._("no rule applied");
            }
        },
        mailEventConvertAction: function(value) {
            if(Ext.isEmpty(value)) {
                return "";
            }
            switch (value) {
                case 'P': return i18n._("pass message");
                case 'M': return i18n._("mark message");
                case 'D': return i18n._("drop message");
                case 'B': return i18n._("block message");
                case 'Q': return i18n._("quarantine message");
                case 'S': return i18n._("pass safelist message");
                case 'Z': return i18n._("pass oversize message");
                case 'O': return i18n._("pass outbound message");
                case 'F': return i18n._("block message (scan failure)");
                case 'G': return i18n._("pass message (scan failure)");
                case 'Y': return i18n._("block message (greylist)");
                default: return i18n._("unknown action");
            }
        }
    }
});



Ext.define("Ung.panel.ExtraConditions", {
    extend: "Ext.panel.Panel",
    title: Ext.String.format( i18n._("Conditions: {0}"), i18n._("None")),
    collapsible: true,
    collapsed: false,
    floatable: false,
    split: true,
    defaultCount: 1,
    autoScroll: true,
    layout: { type: 'vbox'},
    initComponent: function() {
        this.columnsStore = Ext.create('Ext.data.Store', {
            sorters: "displayName",
            fields: ["name", "displayName"],
            data: []
        });
        this.items = [];
        for(var i=0; i<this.defaultCount; i++) {
            this.items.push(this.generateRow());
        }
        var quickAddMenu = Ext.create('Ext.menu.Menu');
        var addQuickCondition = Ext.bind(function(item) {
            this.fillCondition({
                column: item.column,
                operator: "=",
                value: item.value
            });
        }, this);
        rpc.reportingManagerNew.getConditionQuickAddHints(Ext.bind(function(result, exception) {
            if(Ung.Util.handleException(exception)) return;
            var column, hintMenus = [], columnItems, i, text, value;
            for(column in result) {
                var values = result[column];
                if(values.length > 0) {
                    columnItems = [];
                    columnRenderer = Ung.panel.Reports.getColumnRenderer(column);
                    for(i=0; i<values.length; i++) {
                        if(column=="policy_id") {
                            
                        }
                        columnItems.push({
                            text: Ext.isFunction(columnRenderer) ? columnRenderer(values[i]) : values[i],
                            column: column,
                            value: values[i],
                            handler: addQuickCondition
                        });
                    }
                    hintMenus.push({
                        text: Ung.panel.Reports.getColumnHumanReadableName(column),
                        menu: {
                            items: columnItems
                        }
                    });
                }
            }
            quickAddMenu.add(hintMenus);
            
        }, this));
        this.tbar = [{
            text: i18n._("Add Condition"),
            tooltip: i18n._('Add New Condition'),
            iconCls: 'icon-add-row',
            handler: function() {
                this.addRow();
            },
            scope: this
        }, {
            text:'Quick Add',
            iconCls: 'icon-add-row',
            menu: quickAddMenu
        }, '->', {
            text: i18n._("Delete All"),
            tooltip: i18n._('Delete All Conditions'),
            iconCls: 'cancel-icon',
            handler: function() {
                this.deleteConditions();
            },
            scope: this
        }];
        this.callParent(arguments);
    },
    generateRow: function(data) {
        if(!data) {
            data = {column: "", operator:"=", value: ""};
        }
        return {
            xtype: 'container',
            layout: 'column',
            name: 'condition',
            width: '100%',
            defaults: {
                margin: 3
            },
            items: [{
                xtype: 'combo',
                columnWidth: 0.4,
                emptyText: i18n._("[enter column]"),
                dataIndex: "column",
                typeAhead: true,
                valueField: "name",
                displayField: "displayName",
                queryMode: 'local',
                store: this.columnsStore,
                value: data.column,
                listeners: {
                    change: {
                        fn: function(combo, newValue, oldValue, opts) {
                            this.setConditions(true);
                        },
                        scope: this
                    },
                    blur: {
                        fn: function(field, e) {
                            var skipReload = Ext.isEmpty(field.next("[dataIndex=value]").getValue());
                            this.setConditions(skipReload);
                        },
                        scope: this
                    },
                    specialkey: {
                        fn: function(field, e) {
                            if (e.getKey() == e.ENTER) {
                                this.setConditions();
                            }
                            
                        },
                        scope: this
                    }
                }
            }, {
                xtype: 'combo',
                width: 100,
                dataIndex: "operator",
                editable: false,
                valueField: "name",
                displayField: "name",
                queryMode: 'local',
                value: data.operator,
                disabled: Ext.isEmpty(data.column),
                store: ["=", "!=", "<>", ">", "<", ">=", "<=", "between", "like", "in", "is"],
                listeners: {
                    change: {
                        fn: function(combo, newValue, oldValue, opts) {
                            var skipReload = Ext.isEmpty(combo.next("[dataIndex=value]").getValue());
                            this.setConditions(skipReload);
                        },
                        scope: this
                    }
                }
            }, {
                xtype: 'textfield',
                dataIndex: "value",
                columnWidth: 0.6,
                disabled: Ext.isEmpty(data.column),
                emptyText: i18n._("[no value]"),
                value: data.value,
                listeners: {
                    blur: {
                        fn: function(field, e) {
                            this.setConditions();
                        },
                        scope: this
                    },
                    specialkey: {
                        fn: function(field, e) {
                            if (e.getKey() == e.ENTER) {
                                this.setConditions();
                            }
                            
                        },
                        scope: this
                    }
                }
            }, {
                xtype: 'button',
                name: "delete",
                text: i18n._("Delete"),
                handler: Ext.bind(function(button) {
                    var skipReload = Ext.isEmpty(button.prev("[dataIndex=column]").getValue());
                    this.remove(button.up("container"));
                    this.setConditions(skipReload);
                }, this)
            }]
        };
    },
    addRow: function(data) {
      this.add(this.generateRow(data));
    },
    fillCondition: function(data) {
        var added = false;
        this.bulkOperation = true;
        Ext.Array.each(this.query("container[name=condition]"), function(item, index, len) {
            if(Ext.isEmpty(item.down("[dataIndex=column]").getValue())) {
                item.down("[dataIndex=column]").setValue(data.column);
                item.down("[dataIndex=operator]").setValue(data.operator);
                item.down("[dataIndex=value]").setValue(data.value);
                added = true;
                return false;
            }
        });
        if(!added) {
            this.addRow(data);
        }
        this.bulkOperation = false;
        this.setConditions();
    },
    deleteConditions: function() {
        var me = this;
        this.bulkOperation = true;
        Ext.Array.each(this.query("container[name=condition]"), function(item, index, len) {
            if(index < me.defaultCount) {
                item.down("[dataIndex=column]").setValue("");
                item.down("[dataIndex=operator]").setValue("=");
                item.down("[dataIndex=value]").setValue("");
            } else {
                me.remove(item);
            }
        });
        this.bulkOperation = false;
        var skipReload = !this.parentPanel.extraConditions || this.parentPanel.extraConditions.length==0;
        this.setConditions(skipReload);
    },
    setConditions: function(skipReload) {
        if(this.bulkOperation) {
            return;
        }
        var conditions = [], columnValue, operator, value, isEmptyColumn;
        Ext.Array.each(this.query("container[name=condition]"), function(item, index, len) {
            columnValue = item.down("[dataIndex=column]").getValue();
            operator = item.down("[dataIndex=operator]");
            value = item.down("[dataIndex=value]");
            isEmptyColumn = Ext.isEmpty(columnValue);
            if(!isEmptyColumn) {
                conditions.push({
                    "javaClass": "com.untangle.node.reporting.SqlCondition",
                    "column": columnValue,
                    "operator": operator.getValue(),
                    "value": value.getValue()
                });
            }
            operator.setDisabled(isEmptyColumn);
            value.setDisabled(isEmptyColumn);
        });
        if(!skipReload) {
            var encodedConditions = Ext.encode(conditions);
            if(this.currentConditions != encodedConditions) {
                this.currentConditions = encodedConditions;
                this.parentPanel.extraConditions = (conditions.length>0)?conditions:null;
                this.setTitle(Ext.String.format( i18n._("Conditions: {0}"), (conditions.length>0)?conditions.length:i18n._("None")));
                this.parentPanel.refreshHandler();
            }
        }

    },
    setValue: function(extraConditions) {
        var me = this, i;
        this.bulkOperation = true;
        Ext.Array.each(this.query("container[name=condition]"), function(item, index, len) {
            me.remove(item);
        });
        if(!extraConditions) {
            for(i=0; i<this.defaultCount; i++) {
                this.addRow();
            }
        } else {
            for(i=0; i<extraConditions.length; i++) {
                this.addRow(extraConditions[i]);
            }
        }
        this.bulkOperation = false;
    }
    
});





Ext.define("Ung.grid.feature.GlobalFilter", {
    extend: "Ext.grid.feature.Feature",
    useVisibleColumns: true,
    useFields: null,
    init: function (grid) {
        this.grid=grid;

        this.globalFilter = Ext.create('Ext.util.Filter', {
            regExpProtect: /\\|\/|\+|\\|\.|\[|\]|\{|\}|\?|\$|\*|\^|\|/gm,
            disabled: true,
            regExpMode: false,
            caseSensitive: false,
            regExp: null,
            stateId: 'globalFilter',
            searchFields: {},
            filterFn: function(record) {
                if(!this.regExp) {
                    return true;
                }
                var datas = record.getData(), key, val;
                for(key in this.searchFields) {
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
            buildSearch: function(value, caseSensitive, searchFields) {
                this.searchFields = searchFields;
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
        var searchFields = {}, i, col;
        if(this.useVisibleColumns) {
            var visibleColumns = this.grid.getVisibleColumns(); 
            for(i=0; i<visibleColumns.length; i++) {
                col = visibleColumns[i];
                if(col.dataIndex) {
                    searchFields[col.dataIndex] = true;
                }
            }
        } else if(this.searchFields!=null) {
            for(i=0; i<this.searchFields.length; i++) {
                searchFields[this.searchFields[i]] = true;
            }
        }
        this.globalFilter.buildSearch(value, caseSensitive, searchFields);
        this.grid.getStore().getFilters().notify('endupdate');
    }
});

Ext.define("Ung.window.SelectDateTime", {
    extend: "Ext.window.Window",
    date: null,
    buttonObj: null,
    modal:true,
    closeAction: 'hide',
    initComponent: function() {
        this.items = [{
            xtype: 'textfield',
            name: 'dateAndTime',
            readOnly: true,
            hideLabel: true,
            width: 180,
            emptyText: this.dateTimeEmptyText
        }, {
            xtype: 'datepicker',
            name: 'date',
            handler: function(picker, date) {
                var timeValue = this.down("timefield[name=time]").getValue();
                if(timeValue != null) {
                    date.setHours(timeValue.getHours());
                    date.setMinutes(timeValue.getMinutes());
                }
                this.setDate(date);
            },
            scope: this
        }, {
            xtype: 'timefield',
            name: 'time',
            hideLabel: true,
            margin: '5px 0 0 0',
            increment: 30,
            width: 180,
            emptyText: i18n._('Time'),
            value: Ext.Date.parse('12:00 AM','h:i A'),
            listeners: {
                change: {
                    fn: function(combo, newValue, oldValue, opts) {
                        if(!this.buttonObj) {
                            return;
                        }
                        if (combo.getValue()!=null) {
                            if(!this.date) {
                                var selDate=this.down("datepicker[name=date]").getValue();
                                if(!selDate) {
                                    selDate=new Date();
                                    selDate.setHours(0,0,0,0);
                                }
                                this.date = new Date(selDate.getTime()+i18n.timeoffset);
                            }
                            this.date.setHours(combo.getValue().getHours());
                            this.date.setMinutes(combo.getValue().getMinutes());
                            this.setDate(this.date);
                        }
                    },
                    scope: this
                }
            }
        }];
        this.buttons = [{
            text: i18n._("Done"),
            handler: function() {
                this.hide();
            },
            scope: this
        }, '->', {
            name: 'Clear',
            text: i18n._("Clear Value"),
            handler: function() {
                this.setDate(null);
                this.hide();
                },
            scope: this
        }];
        this.callParent(arguments);
    },
    setDate: function(date) {
        this.date = date;
        var dateStr ="";
        var buttonLabel = null;
        if(this.date) {
            this.date.setTime(this.date.getTime()-i18n.timeoffset);
            dateStr = i18n.timestampFormat({time: this.date.getTime()});
            buttonLabel = i18n.timestampFormat({time: this.date.getTime()});
        }
        this.down("textfield[name=dateAndTime]").setValue(dateStr);
        if(this.buttonObj) {
            this.buttonObj.setText(buttonLabel!=null?buttonLabel:this.buttonObj.initialLabel);
        }
    }
});