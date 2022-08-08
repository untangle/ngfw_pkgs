{
    "suricataSettings":{
        "default-rule-path": "/etc/suricata",
        "rule-files": [
            "ngfw.rules"
        ],
        "nfq": {
            "mode": "accept",
            "fail-open": true
        },
        "app-layer": {
            "protocols": {
                "modbus": {
                    "enabled": true
                }
            }
        },
        "outputs": {
            "eve-log": {
                "enabled": false
            },
            "fast": {
                "enabled": true
            },
            "stats": {
                "enabled": false
            }
        },
        "logging": {
            "outputs": {
                "file": {
                    "enabled": false
                },
                "syslog":{
                    "enabled": true
                }
            }
        }
    },
    "rules": {
        "javaClass": "java.util.LinkedList",
        "list": [{
            "javaClass": "com.untangle.app.intrusion_prevention.IntrusionPreventionRule",
            "enabled": true,
            "id": "reserved_default_1",
            "description":"Low memory",
            "action":"default",
            "conditions":{
                "javaClass":"java.util.LinkedList",
                "list":[{
                    "javaClass":"com.untangle.app.intrusion_prevention.IntrusionPreventionRuleCondition",
                    "type":"SYSTEM_MEMORY",
                    "comparator":">=",
                    "value":"1073741824"
                },{
                    "javaClass":"com.untangle.app.intrusion_prevention.IntrusionPreventionRuleCondition",
                    "type":"CLASSTYPE",
                    "comparator":"=",
                    "value":"attempted-admin,attempted-user,inappropriate-content,policy-violation,shellcode-detect,successful-admin,successful-user,trojan-activity,nsuccessful-user,web-application-attack"
                }]
            }
        },{
            "javaClass": "com.untangle.app.intrusion_prevention.IntrusionPreventionRule",
            "enabled": true,
            "id": "reserved_default_2",
            "description":"Medium memory",
            "action":"default",
            "conditions":{
                "javaClass":"java.util.LinkedList",
                "list":[{
                    "javaClass":"com.untangle.app.intrusion_prevention.IntrusionPreventionRuleCondition",
                    "type":"SYSTEM_MEMORY",
                    "comparator":">=",
                    "value":"1610612736"
                },{
                    "javaClass":"com.untangle.app.intrusion_prevention.IntrusionPreventionRuleCondition",
                    "type":"CLASSTYPE",
                    "comparator":"=",
                    "value":"attempted-dos,attempted-recon,bad-unknown,default-login-attempt,denial-of-service,misc-attack,non-standard-protocol,rpc-portmap-decode,successful-dos,successful-recon-largescale,successful-recon-limited,suspicious-ﬁlename-detect,suspicious-login,system-call-detect,unusual-client-port-connection,web-application-activity"
                }]
            }
        },{
            "javaClass": "com.untangle.app.intrusion_prevention.IntrusionPreventionRule",
            "enabled": true,
            "id": "reserved_default_3",
            "description":"High memory",
            "action":"default",
            "conditions":{
                "javaClass":"java.util.LinkedList",
                "list":[{
                    "javaClass":"com.untangle.app.intrusion_prevention.IntrusionPreventionRuleCondition",
                    "type":"SYSTEM_MEMORY",
                    "comparator":">=",
                    "value":"2147483648"
                },{
                    "javaClass":"com.untangle.app.intrusion_prevention.IntrusionPreventionRuleCondition",
                    "type":"CLASSTYPE",
                    "comparator":"=",
                    "value":"web-application-attack,attempted-dos,attempted-recon,bad-unknown,default-login-attempt,denial-of-service,misc-attack,non-standard-protocol,rpc-portmap-decode,successful-dos,successful-recon-largescale,successful-recon-limited,suspicious-ﬁlename-detect,suspicious-login,system-call-detect,unusual-client-port-connection,web-application-activity,icmp-event,misc-activity,network-scan,not-suspicious,protocol-command-decode,string-detect,unknown,tcp-connection"
                }]
            }
        }]
    }
}
