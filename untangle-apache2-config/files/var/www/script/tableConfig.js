Ext.define('Ung.TableConfig', {
    singleton: true,
    
    //Field width constants
    timestampFieldWidth: 135,
    ipFieldWidth: 100,
    portFieldWidth: 70,
    hostnameFieldWidth: 120,
    uriFieldWidth: 200,
    usernameFieldWidth: 120,
    booleanFieldWidth: 60,
    emailFieldWidth: 150,

    getConfig: function(tableName) {
        if(!this.tableConfig) {
            this.buildTableConfig();
        }
        return this.tableConfig[tableName];
    },
    checkHealth: function() {
        if(!rpc.reportingManagerNew) {
            rpc.reportingManagerNew = Ung.Main.getReportingManagerNew();
        }
        if(!this.tableConfig) {
            this.buildTableConfig();
        }
        var i, j, table, column, systemColumns, systemColumnsMap, tableConfigColumns, tableConfigColumnsMap;
        var systemTables = rpc.reportingManagerNew.getTables();
        var systemTablesMap={};
        var missingTables = [];
        for(i=0; i<systemTables.length;i++) {
            systemTablesMap[systemTables[i]] = true;
            
            if(!this.tableConfig[systemTables[i]]) {
                missingTables.push(systemTables[i]);
            }
        }
        if(missingTables.length>0) {
            console.log("Warning: Mising tables: "+missingTables.join(", "));
        }
        var extraTables = [];
        for(table in this.tableConfig) {
            if(!systemTablesMap[table]) {
                extraTables.push(table);
            }
        }
        if(extraTables.length>0) {
            console.log("Warning: Extra tables: "+extraTables.join(", "));
        }
        for(table in this.tableConfig) {
            tableConfigColumns = this.tableConfig[table].columns;
            if(systemTablesMap[table]) {
                systemColumns = rpc.reportingManagerNew.getColumnsForTable(table);
                systemColumnsMap = {};
                tableConfigColumnsMap = {};
                for(i=0;i<tableConfigColumns.length; i++) {
                    tableConfigColumnsMap[tableConfigColumns[i].dataIndex] = true;
                }
                var missingColumns = [];
                for(i=0;i<systemColumns.length; i++) {
                    systemColumnsMap[systemColumns[i]] = true;
                    if(!tableConfigColumnsMap[systemColumns[i]]) {
                        missingColumns.push(systemColumns[i]);
                    }
                }
                if(missingColumns.length>0) {
                    console.log("Warning: Table '"+table+"' Mising columns: "+missingColumns.join(", "));
                }
                
                var extraColumns = [];
                for(column in tableConfigColumnsMap) {
                    if(!systemColumnsMap[column]) {
                        extraColumns.push(column);
                    }
                }
                if(extraColumns.length>0) {
                    console.log("Warning: Table '"+table+"' Extra columns: "+extraColumns.join(", "));
                }
                
            }
        }
        
    },
    buildTableConfig: function() {
        this.tableConfig = {
            sessions: {
                fields: [{
                    name: 'session_id'
                }, {
                    name: 'time_stamp',
                    sortType: 'asTimestamp'
                }, {
                    name: 'end_time',
                    sortType: 'asTimestamp'
                }, {
                    name: 'bypassed',
                    type: 'boolean'
                }, {
                    name: 'protocol'
                }, {
                    name: 'hostname'
                }, {
                    name: 'username'
                }, {
                    name: 'policy_id'
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
                    name: 'client_intf'
                }, {
                    name: 'server_intf'
                }, {
                    name: "c2p_bytes"
                }, {
                    name: "p2c_bytes"
                }, {
                    name: "s2p_bytes"
                }, {
                    name: "p2s_bytes"
                }, {
                    name: 'shield_blocked',
                    type: 'boolean'
                }, {
                    name: 'firewall_blocked'
                }, {
                    name: 'firewall_flagged'
                }, {
                    name: 'firewall_rule_index'
                }, {
                    name: 'application_control_lite_blocked'
                }, {
                    name: 'application_control_lite_protocol',
                    type: 'string'
                }, {
                    name: "captive_portal_rule_index"
                }, {
                    name: "captive_portal_blocked"
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
                    name: 'application_control_ruleid'
                }, {
                    name: 'bandwidth_control_priority'
                }, {
                    name: 'bandwidth_control_rule'
                }, {
                    name: 'ssl_inspector_status'
                }, {
                    name: 'ssl_inspector_detail'
                }, {
                    name: 'ssl_inspector_ruleid'
                }],
                columns: [{
                    header: i18n._("Session ID"),
                    width: Ung.TableConfig.portFieldWidth,
                    sortable: true,
                    dataIndex: 'session_id'
                }, {
                    header: i18n._("Timestamp"),
                    width: Ung.TableConfig.timestampFieldWidth,
                    sortable: true,
                    dataIndex: 'time_stamp',
                    renderer: function(value) {
                        return i18n.timestampFormat(value);
                    }
                }, {
                    header: i18n._("End Timestamp"),
                    width: Ung.TableConfig.timestampFieldWidth,
                    sortable: true,
                    dataIndex: 'end_time',
                    renderer: function(value) {
                        return i18n.timestampFormat(value);
                    }
                }, {
                    header: i18n._('Bypassed'),
                    width: Ung.TableConfig.booleanFieldWidth,
                    sortable: true,
                    dataIndex: 'bypassed',
                    filter: {
                        type: 'boolean',
                        yesText: 'true',
                        noText: 'false'
                    }
                }, {
                    header: i18n._("Protocol"),
                    width: Ung.TableConfig.portFieldWidth,
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
                    width: Ung.TableConfig.portFieldWidth + 40, // +40 for column header
                    sortable: true,
                    dataIndex: 'client_intf'
                }, {
                    header: i18n._("Server Interface") ,
                    width: Ung.TableConfig.portFieldWidth + 40, // +40 for column header
                    sortable: true,
                    dataIndex: 'server_intf'
                }, {
                    header: i18n._("Username"),
                    width: Ung.TableConfig.usernameFieldWidth,
                    sortable: true,
                    dataIndex: 'username'
                }, {
                    header: i18n._("Hostname"),
                    width: Ung.TableConfig.hostnameFieldWidth,
                    sortable: true,
                    dataIndex: 'hostname'
                }, {
                    header: i18n._("Client"),
                    width: Ung.TableConfig.ipFieldWidth,
                    sortable: true,
                    dataIndex: 'c_client_addr'
                }, {
                    header: i18n._("Client Port"),
                    width: Ung.TableConfig.portFieldWidth,
                    sortable: true,
                    dataIndex: 'c_client_port',
                    filter: {
                        type: 'numeric'
                    }
                }, {
                    header: i18n._("New Client"),
                    width: Ung.TableConfig.ipFieldWidth,
                    sortable: true,
                    dataIndex: 's_client_addr'
                }, {
                    header: i18n._("New Client Port"),
                    width: Ung.TableConfig.portFieldWidth,
                    sortable: true,
                    dataIndex: 's_client_port',
                    filter: {
                        type: 'numeric'
                    }
                }, {
                    header: i18n._("Original Server") ,
                    width: Ung.TableConfig.ipFieldWidth + 40, // +40 for column header
                    sortable: true,
                    dataIndex: 'c_server_addr'
                }, {
                    header: i18n._("Original Server Port"),
                    width: Ung.TableConfig.portFieldWidth + 40, // +40 for column header
                    sortable: true,
                    dataIndex: 'c_server_port',
                    filter: {
                        type: 'numeric'
                    }
                }, {
                    header: i18n._("Server") ,
                    width: Ung.TableConfig.ipFieldWidth,
                    sortable: true,
                    dataIndex: 's_server_addr'
                }, {
                    header: i18n._("Server Port"),
                    width: Ung.TableConfig.portFieldWidth,
                    sortable: true,
                    dataIndex: 's_server_port',
                    filter: {
                        type: 'numeric'
                    }
                }, {
                    header: i18n._('Shield Blocked'),
                    width: Ung.TableConfig.booleanFieldWidth,
                    sortable: true,
                    dataIndex: 'shield_blocked',
                    filter: {
                        type: 'boolean',
                        yesText: 'true',
                        noText: 'false'
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
                    width: Ung.TableConfig.booleanFieldWidth,
                    sortable: true,
                    dataIndex: 'application_control_blocked',
                    filter: {
                        type: 'boolean',
                        yesText: 'true',
                        noText: 'false'
                    }
                }, {
                    header: i18n._('Flagged') + ' (Application Control)',
                    width: Ung.TableConfig.booleanFieldWidth,
                    sortable: true,
                    dataIndex: 'application_control_flagged',
                    filter: {
                        type: 'boolean',
                        yesText: 'true',
                        noText: 'false'
                    }
                }, {
                    header: i18n._('Confidence') + ' (Application Control)',
                    width: Ung.TableConfig.portFieldWidth,
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
                    width: Ung.TableConfig.booleanFieldWidth,
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
                    width: Ung.TableConfig.booleanFieldWidth,
                    sortable: true,
                    dataIndex: 'firewall_blocked',
                    filter: {
                        type: 'boolean',
                        yesText: 'true',
                        noText: 'false'
                    }
                }, {
                    header: i18n._('Flagged') + ' (Firewall)',
                    width: Ung.TableConfig.booleanFieldWidth,
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
                    header: i18n._('Captured') + ' (Captive Portal)',
                    width: 100,
                    sortable: true,
                    dataIndex: "captive_portal_blocked",
                    filter: {
                        type: 'boolean',
                        yesText: 'true',
                        noText: 'false'
                    }
                }, {
                    header: i18n._('To-Server Bytes'),
                    width: Ung.TableConfig.portFieldWidth,
                    sortable: true,
                    dataIndex: 'p2s_bytes',
                    filter: {
                        type: 'numeric'
                    }
                }, {
                    header: i18n._('From-Server Bytes'),
                    width: Ung.TableConfig.portFieldWidth,
                    sortable: true,
                    dataIndex: 's2p_bytes',
                    filter: {
                        type: 'numeric'
                    }
                }, {
                    header: i18n._('To-Client Bytes'),
                    width: Ung.TableConfig.portFieldWidth,
                    sortable: true,
                    dataIndex: 'p2c_bytes',
                    filter: {
                        type: 'numeric'
                    }
                }, {
                    header: i18n._('From-Client Bytes'),
                    width: Ung.TableConfig.portFieldWidth,
                    sortable: true,
                    dataIndex: 'c2p_bytes',
                    filter: {
                        type: 'numeric'
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
                    width: Ung.TableConfig.portFieldWidth,
                    sortable: true,
                    dataIndex: 'request_id'
                }, {
                    header: i18n._("Timestamp"),
                    width: Ung.TableConfig.timestampFieldWidth,
                    sortable: true,
                    dataIndex: 'time_stamp',
                    renderer: function(value) {
                        return i18n.timestampFormat(value);
                    }
                }, {
                    header: i18n._("Session ID"),
                    width: Ung.TableConfig.portFieldWidth,
                    sortable: true,
                    dataIndex: 'session_id'
                }, {
                    header: i18n._("Client Interface") ,
                    width: Ung.TableConfig.portFieldWidth + 40, // +40 for column header
                    sortable: true,
                    dataIndex: 'client_intf'
                }, {
                    header: i18n._("Server Interface") ,
                    width: Ung.TableConfig.portFieldWidth + 40, // +40 for column header
                    sortable: true,
                    dataIndex: 'server_intf'
                }, {
                    header: i18n._("Client"),
                    width: Ung.TableConfig.ipFieldWidth,
                    sortable: true,
                    dataIndex: 'c_client_addr'
                }, {
                    header: i18n._("Client Port"),
                    width: Ung.TableConfig.portFieldWidth,
                    sortable: true,
                    dataIndex: 'c_client_port',
                    filter: {
                        type: 'numeric'
                    }
                }, {
                    header: i18n._("New Client"),
                    width: Ung.TableConfig.ipFieldWidth,
                    sortable: true,
                    dataIndex: 's_client_addr'
                }, {
                    header: i18n._("New Client Port"),
                    width: Ung.TableConfig.portFieldWidth,
                    sortable: true,
                    dataIndex: 's_client_port',
                    filter: {
                        type: 'numeric'
                    }
                }, {
                    header: i18n._("Original Server") ,
                    width: Ung.TableConfig.ipFieldWidth + 40, // +40 for column header
                    sortable: true,
                    dataIndex: 'c_server_addr'
                }, {
                    header: i18n._("Original Server Port"),
                    width: Ung.TableConfig.portFieldWidth + 40, // +40 for column header
                    sortable: true,
                    dataIndex: 'c_server_port',
                    filter: {
                        type: 'numeric'
                    }
                }, {
                    header: i18n._("Server") ,
                    width: Ung.TableConfig.ipFieldWidth + 40, // +40 for column header
                    sortable: true,
                    dataIndex: 's_server_addr'
                }, {
                    header: i18n._("Server Port"),
                    width: Ung.TableConfig.portFieldWidth + 40, // +40 for column header
                    sortable: true,
                    dataIndex: 's_server_port',
                    filter: {
                        type: 'numeric'
                    }
                }, {
                    header: i18n._("Hostname"),
                    width: Ung.TableConfig.hostnameFieldWidth,
                    sortable: true,
                    dataIndex: 'hostname'
                }, {
                    header: i18n._("Username"),
                    width: Ung.TableConfig.usernameFieldWidth,
                    sortable: true,
                    dataIndex: 'username'
                }, {
                    header: i18n._("Domain"),
                    width: Ung.TableConfig.hostnameFieldWidth,
                    sortable: true,
                    dataIndex: 'domain'
                }, {
                    header: i18n._("Host"),
                    width: Ung.TableConfig.hostnameFieldWidth,
                    sortable: true,
                    dataIndex: 'host'
                }, {
                    header: i18n._("Uri"),
                    flex:1,
                    width: Ung.TableConfig.uriFieldWidth,
                    sortable: true,
                    dataIndex: 'uri'
                }, {
                    header: i18n._("Method"),
                    width: Ung.TableConfig.portFieldWidth,
                    sortable: true,
                    dataIndex: 'method'
                }, {
                    header: i18n._("Download Content Length"),
                    width: Ung.TableConfig.portFieldWidth,
                    sortable: true,
                    dataIndex: 's2c_content_length'
                }, {
                    header: i18n._("Upload Content Length"),
                    width: Ung.TableConfig.portFieldWidth,
                    sortable: true,
                    dataIndex: 'c2s_content_length'
                }, {
                    header: i18n._("Content Type"),
                    width: 150,
                    sortable: true,
                    dataIndex: 's2c_content_type'
                }, {
                    header: i18n._("Blocked") + " (Web Filter Lite)",
                    width: Ung.TableConfig.booleanFieldWidth,
                    sortable: true,
                    dataIndex: 'web_filter_lite_blocked',
                    filter: {
                        type: 'boolean',
                        yesText: 'true',
                        noText: 'false'
                    }
                }, {
                    header: i18n._("Flagged") + " (Web Filter Lite)",
                    width: Ung.TableConfig.booleanFieldWidth,
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
                    width: Ung.TableConfig.booleanFieldWidth,
                    sortable: true,
                    dataIndex: 'web_filter_blocked',
                    filter: {
                        type: 'boolean',
                        yesText: 'true',
                        noText: 'false'
                    }
                }, {
                    header: i18n._("Flagged") + " (Web Filter)",
                    width: Ung.TableConfig.booleanFieldWidth,
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
                    width: Ung.TableConfig.booleanFieldWidth,
                    sortable: true,
                    dataIndex: 'virus_blocker_lite_clean'
                }, {
                    header: i18n._('Virus Name') + ' (Virus Blocker Lite)',
                    width: 140,
                    sortable: true,
                    dataIndex: 'virus_blocker_lite_name'
                }, {
                    header: i18n._('Clean') + ' (Virus Blocker)',
                    width: Ung.TableConfig.booleanFieldWidth,
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
                    width: Ung.TableConfig.timestampFieldWidth,
                    sortable: true,
                    dataIndex: 'time_stamp',
                    renderer: function(value) {
                        return i18n.timestampFormat(value);
                    }
                }, {
                    header: i18n._("Hostname"),
                    width: Ung.TableConfig.hostnameFieldWidth,
                    sortable: true,
                    dataIndex: 'hostname'
                }, {
                    header: i18n._("Client"),
                    width: Ung.TableConfig.ipFieldWidth,
                    sortable: true,
                    dataIndex: 'c_client_addr'
                }, {
                    header: i18n._("Username"),
                    width: Ung.TableConfig.usernameFieldWidth,
                    sortable: true,
                    dataIndex: 'username'
                }, {
                    header: i18n._("Host"),
                    width: Ung.TableConfig.hostnameFieldWidth,
                    sortable: true,
                    dataIndex: 'host'
                }, {
                    header: i18n._("Uri"),
                    flex:1,
                    width: Ung.TableConfig.uriFieldWidth,
                    sortable: true,
                    dataIndex: 'uri'
                }, {
                    header: i18n._("Query Term"),
                    flex:1,
                    width: Ung.TableConfig.uriFieldWidth,
                    sortable: true,
                    dataIndex: 'term'
                }, {
                    header: i18n._("Server"),
                    width: Ung.TableConfig.ipFieldWidth,
                    sortable: true,
                    dataIndex: 'c_server_addr'
                }, {
                    header: i18n._("Server Port"),
                    width: Ung.TableConfig.portFieldWidth,
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
                    width: Ung.TableConfig.timestampFieldWidth,
                    sortable: true,
                    dataIndex: 'time_stamp',
                    renderer: function(value) {
                        return i18n.timestampFormat(value);
                    }
                }, {
                    header: i18n._("Hostname"),
                    width: Ung.TableConfig.hostnameFieldWidth,
                    sortable: true,
                    dataIndex: 'hostname'
                }, {
                    header: i18n._("Client"),
                    width: Ung.TableConfig.ipFieldWidth,
                    sortable: true,
                    dataIndex: 'c_client_addr'
                }, {
                    header: i18n._("Server"),
                    width: Ung.TableConfig.ipFieldWidth,
                    sortable: true,
                    dataIndex: 'c_server_addr'
                }, {
                    header: i18n._("Server"),
                    width: Ung.TableConfig.ipFieldWidth,
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
                    width: Ung.TableConfig.emailFieldWidth,
                    sortable: true,
                    dataIndex: 'addr'
                }, {
                    header: i18n._("Sender"),
                    width: Ung.TableConfig.emailFieldWidth,
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
                    width: Ung.TableConfig.timestampFieldWidth,
                    sortable: true,
                    dataIndex: 'time_stamp',
                    renderer: function(value) {
                        return i18n.timestampFormat(value);
                    }
                }, {
                    header: i18n._("Client"),
                    width: Ung.TableConfig.ipFieldWidth,
                    sortable: true,
                    dataIndex: 'client_addr'
                }, {
                    header: i18n._("Username"),
                    width: Ung.TableConfig.usernameFieldWidth,
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
                    width: Ung.TableConfig.timestampFieldWidth,
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
                    width: Ung.TableConfig.ipFieldWidth,
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
                    width: Ung.TableConfig.timestampFieldWidth,
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
                    width: Ung.TableConfig.timestampFieldWidth,
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
                    width: Ung.TableConfig.timestampFieldWidth,
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
                    width: Ung.TableConfig.ipFieldWidth,
                    sortable: true,
                    dataIndex: "client_address"
                },{
                    header: i18n._("Username"),
                    width: Ung.TableConfig.usernameFieldWidth,
                    sortable: true,
                    dataIndex: "client_username"
                },{
                    header: i18n._("Protocol"),
                    width: 120,
                    sortable: true,
                    dataIndex: "client_protocol"
                },{
                    header: i18n._("Login Time"),
                    width: Ung.TableConfig.timestampFieldWidth,
                    sortable: true,
                    dataIndex: "connect_stamp",
                    renderer: function(value) {
                        return i18n.timestampFormat(value);
                    }
                },{
                    header: i18n._("Logout Time"),
                    width: Ung.TableConfig.timestampFieldWidth,
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
                    width: Ung.TableConfig.timestampFieldWidth,
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
                    width: Ung.TableConfig.timestampFieldWidth,
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
                    width: Ung.TableConfig.timestampFieldWidth,
                    sortable: true,
                    dataIndex: "time_stamp",
                    renderer: function(value) {
                        return i18n.timestampFormat(value);
                    }
                },{
                    header: i18n._("Client"),
                    width: Ung.TableConfig.ipFieldWidth,
                    sortable: true,
                    dataIndex: "client_addr"
                },{
                    header: i18n._("Username"),
                    width: Ung.TableConfig.usernameFieldWidth,
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
                    width: Ung.TableConfig.timestampFieldWidth,
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
                    width: Ung.TableConfig.ipFieldWidth,
                    sortable: true,
                    dataIndex: 'source_addr'
                }, {
                    header: i18n._("Source port"),
                    width: Ung.TableConfig.portFieldWidth,
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
                    width: Ung.TableConfig.ipFieldWidth,
                    sortable: true,
                    dataIndex: 'dest_addr'
                }, {
                    header: i18n._("Destination port"),
                    width: Ung.TableConfig.portFieldWidth,
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
                    width: Ung.TableConfig.booleanFieldWidth,
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
                    width: Ung.TableConfig.timestampFieldWidth,
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
                    width: Ung.TableConfig.timestampFieldWidth,
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
                    width: Ung.TableConfig.timestampFieldWidth,
                    sortable: true,
                    dataIndex: 'time_stamp',
                    renderer: function(value) {
                        return i18n.timestampFormat(value);
                    }
                }, {
                    header: i18n._("Client"),
                    width: Ung.TableConfig.ipFieldWidth,
                    sortable: true,
                    dataIndex: 'c_client_addr'
                }, {
                    header: i18n._("Username"),
                    width: Ung.TableConfig.usernameFieldWidth,
                    sortable: true,
                    dataIndex: 'username'
                }, {
                    header: i18n._("File Name"),
                    flex:1,
                    width: Ung.TableConfig.uriFieldWidth,
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
                    width: Ung.TableConfig.ipFieldWidth,
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
                    width: Ung.TableConfig.timestampFieldWidth,
                    sortable: true,
                    dataIndex: 'time_stamp',
                    renderer: function(value) {
                        return i18n.timestampFormat(value);
                    }
                }, {
                    header: i18n._("Address"),
                    width: Ung.TableConfig.ipFieldWidth,
                    sortable: true,
                    dataIndex: 'address'
                }, {
                    header: i18n._("Reason"),
                    sortable: true,
                    flex: 1,
                    dataIndex: 'reason'
                }, {
                    header: i18n._("Start Time"),
                    width: Ung.TableConfig.timestampFieldWidth,
                    sortable: true,
                    dataIndex: 'start_time',
                    renderer: function(value) {
                        return i18n.timestampFormat(value);
                    }
                }, {
                    header: i18n._("End Time"),
                    width: Ung.TableConfig.timestampFieldWidth,
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
                    width: Ung.TableConfig.timestampFieldWidth,
                    sortable: true,
                    dataIndex: 'time_stamp',
                    renderer: function(value) {
                        return i18n.timestampFormat(value);
                    }
                }, {
                    header: i18n._("Address"),
                    width: Ung.TableConfig.ipFieldWidth,
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
                    width: Ung.TableConfig.timestampFieldWidth,
                    sortable: true,
                    dataIndex: 'time_stamp',
                    renderer: function(value) {
                        return i18n.timestampFormat(value);
                    }
                }, {
                    header: i18n._("Username"),
                    width: Ung.TableConfig.usernameFieldWidth,
                    sortable: true,
                    dataIndex: 'username'
                }, {
                    header: i18n._("Hostname"),
                    width: Ung.TableConfig.hostnameFieldWidth,
                    sortable: true,
                    dataIndex: 'hostname'
                }, {
                    header: i18n._("Settings File"),
                    flex:1,
                    width: Ung.TableConfig.uriFieldWidth,
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
    
});