{
    "version": 3,
    "categories": [{
        "category" : "preprocessor_portscan",
        "description": "Portscan detection.",
        "ids":[
            "5_122",
            "9_122",
            "13_122",
            "2_122",
            "20_122",
            "10_122",
            "6_122",
            "18_122",
            "4_122",
            "14_122",
            "12_122",
            "21_122",
            "1_122",
            "22_122",
            "17_122",
            "24_122",
            "16_122",
            "8_122"
        ]
    }],
    "rules": [{
        "enabled":false,
        "id": "reserved_default_1",
        "description":"Low memory",
        "action":"default",
        "conditions":{
            "javaClass":"java.util.LinkedList",
            "list":[{
                "javaClass":"",
                "type":"SYSTEM_MEMORY",
                "comparator":">=",
                "value":1073741824
            },{
                "javaClass":"",
                "type":"CLASSTYPE",
                "comparator":"=",
                "value":"attempted-admin,attempted-user,inappropriate-content,policy-violation,shellcode-detect,successful-admin,successful-user,trojan-activity,nsuccessful-user,web-application-attack"
            }]
        }
    },{
        "enabled":false, 
        "id": "reserved_default_2",
        "description":"Medium memory",
        "action":"default",
        "conditions":{
            "javaClass":"java.util.LinkedList",
            "list":[{
                "javaClass":"",
                "type":"SYSTEM_MEMORY",
                "comparator":"<",
                "value":2147483648
            },{
                "javaClass":"",
                "type":"CLASSTYPE",
                "comparator":"=",
                "value":"attempted-admin,attempted-user,inappropriate-content,policy-violation,shellcode-detect,successful-admin,successful-user,trojan-activity,nsuccessful-user,web-application-attack,attempted-dos,attempted-recon,bad-unknown,default-login-attempt,denial-of-service,misc-attack,non-standard-protocol,rpc-portmap-decode,successful-dos,successful-recon-largescale,successful-recon-limited,suspicious-ﬁlename-detect,suspicious-login,system-call-detect,unusual-client-port-connection,web-application-activity"
            }]
        }
    },{
        "enabled":false, 
        "id": "reserved_default_3",
        "description":"High memory",
        "action":"default",
        "conditions":{
            "javaClass":"java.util.LinkedList",
            "list":[{
                "javaClass":"",
                "type":"SYSTEM_MEMORY",
                "comparator":">=",
                "value":2147483648
            },{
                "javaClass":"",
                "type":"CLASSTYPE",
                "comparator":"=",
                "value":"attempted-admin,attempted-user,inappropriate-content,policy-violation,shellcode-detect,successful-admin,successful-user,trojan-activity,nsuccessful-user,web-application-attack,attempted-dos,attempted-recon,bad-unknown,default-login-attempt,denial-of-service,misc-attack,non-standard-protocol,rpc-portmap-decode,successful-dos,successful-recon-largescale,successful-recon-limited,suspicious-ﬁlename-detect,suspicious-login,system-call-detect,unusual-client-port-connection,web-application-activity,icmp-event,misc-activity,network-scan,not-suspicious,protocol-command-decode,string-detect,unknown,tcp-connection"
            }]
        }
    },{
        "enabled":false, 
        "id": "reserved_default_4",
        "description":"Standard",
        "action":"default",
        "conditions":{
            "javaClass":"java.util.LinkedList",
            "list":[{
                "javaClass":"",
                "type":"CATEGORY",
                "comparator":"=",
                "value":"preprocessor_portscan"
            }]
        }
    }],
    "profiles": [{
        "profileId":   "low_32",
        "systemStats": {
            "MemTotal": "1073741824",
            "architecture": "32"
        },
        "activeGroups" : {
            "classtypes": "recommended",
            "classtypesSelected": [ 
                "+attempted-admin",
                "+attempted-user",
                "+inappropriate-content",
                "+policy-violation",
                "+shellcode-detect",
                "+successful-admin",
                "+successful-user",
                "+trojan-activity",
                "+unsuccessful-user",
                "+web-application-attack"
            ],
            "categories": "recommended",
            "categoriesSelected": [
                "preprocessor_portscan"
            ]
        }
    },{
        "profileId":   "medium_32",
        "systemStats": {
            "MemTotal": "2147483648",
            "architecture": "32"
        },
        "activeGroups" : {
            "classtypes": "recommended",
            "classtypesSelected": [ 
                "+attempted-admin",
                "+attempted-user",
                "+inappropriate-content",
                "+policy-violation",
                "+shellcode-detect",
                "+successful-admin",
                "+successful-user",
                "+trojan-activity",
                "+unsuccessful-user",
                "+web-application-attack",
                "+attempted-dos",
                "+attempted-recon",
                "+bad-unknown",
                "+default-login-attempt",
                "+denial-of-service",
                "+misc-attack",
                "+non-standard-protocol",
                "+rpc-portmap-decode",
                "+successful-dos",
                "+successful-recon-largescale",
                "+successful-recon-limited",
                "+suspicious-ﬁlename-detect",
                "+suspicious-login",
                "+system-call-detect",
                "+unusual-client-port-connection",
                "+web-application-activity"
            ],
            "categories": "recommended",
            "categoriesSelected": [
                "preprocessor_portscan"
            ]
        }
    },{
        "profileId":   "high_32",
        "systemStats": {
            "MemTotal": "",
            "architecture": "32"
        },
        "activeGroups" : {
            "classtypes": "recommended",
            "classtypesSelected": [ 
                "+attempted-admin",
                "+attempted-user",
                "+inappropriate-content",
                "+policy-violation",
                "+shellcode-detect",
                "+successful-admin",
                "+successful-user",
                "+trojan-activity",
                "+unsuccessful-user",
                "+web-application-attack",
                "+attempted-dos",
                "+attempted-recon",
                "+bad-unknown",
                "+default-login-attempt",
                "+denial-of-service",
                "+misc-attack",
                "+non-standard-protocol",
                "+rpc-portmap-decode",
                "+successful-dos",
                "+successful-recon-largescale",
                "+successful-recon-limited",
                "+suspicious-ﬁlename-detect",
                "+suspicious-login",
                "+system-call-detect",
                "+unusual-client-port-connection",
                "+web-application-activity",
                "+icmp-event",
                "+misc-activity",
                "+network-scan",
                "+not-suspicious",
                "+protocol-command-decode",
                "+string-detect",
                "+unknown",
                "+tcp-connection"
            ],
            "categories": "recommended",
            "categoriesSelected": [
                "preprocessor_portscan"
            ]
        }
    },{
        "profileId":   "low_64",
        "systemStats": {
            "MemTotal": "1073741824",
            "architecture": "64"
        },
        "activeGroups" : {
            "classtypes": "recommended",
            "classtypesSelected": [ 
                "+attempted-admin",
                "+attempted-user",
                "+inappropriate-content",
                "+policy-violation",
                "+shellcode-detect",
                "+successful-admin",
                "+successful-user",
                "+trojan-activity",
                "+unsuccessful-user",
                "+web-application-attack"
            ],
            "categories": "recommended",
            "categoriesSelected": [
                "preprocessor_portscan"
            ]
        }
    },{
        "profileId":   "medium_64",
        "systemStats": {
            "MemTotal": "2147483648",
            "architecture": "64"
        },
        "activeGroups" : {
            "classtypes": "recommended",
            "classtypesSelected": [ 
                "+attempted-admin",
                "+attempted-user",
                "+inappropriate-content",
                "+policy-violation",
                "+shellcode-detect",
                "+successful-admin",
                "+successful-user",
                "+trojan-activity",
                "+unsuccessful-user",
                "+web-application-attack",
                "+attempted-dos",
                "+attempted-recon",
                "+bad-unknown",
                "+default-login-attempt",
                "+denial-of-service",
                "+misc-attack",
                "+non-standard-protocol",
                "+rpc-portmap-decode",
                "+successful-dos",
                "+successful-recon-largescale",
                "+successful-recon-limited",
                "+suspicious-ﬁlename-detect",
                "+suspicious-login",
                "+system-call-detect",
                "+unusual-client-port-connection",
                "+web-application-activity"
            ],
            "categories": "recommended",
            "categoriesSelected": [
                "preprocessor_portscan"
            ]
        }
    },{
        "profileId":   "high_64",
        "systemStats": {
            "MemTotal": "",
            "architecture": "64"
        },
        "activeGroups" : {
            "classtypes": "recommended",
            "classtypesSelected": [ 
                "+attempted-admin",
                "+attempted-user",
                "+inappropriate-content",
                "+policy-violation",
                "+shellcode-detect",
                "+successful-admin",
                "+successful-user",
                "+trojan-activity",
                "+unsuccessful-user",
                "+web-application-attack",
                "+attempted-dos",
                "+attempted-recon",
                "+bad-unknown",
                "+default-login-attempt",
                "+denial-of-service",
                "+misc-attack",
                "+non-standard-protocol",
                "+rpc-portmap-decode",
                "+successful-dos",
                "+successful-recon-largescale",
                "+successful-recon-limited",
                "+suspicious-ﬁlename-detect",
                "+suspicious-login",
                "+system-call-detect",
                "+unusual-client-port-connection",
                "+web-application-activity",
                "+icmp-event",
                "+misc-activity",
                "+network-scan",
                "+not-suspicious",
                "+protocol-command-decode",
                "+string-detect",
                "+unknown",
                "+tcp-connection"
            ],
            "categories": "recommended",
            "categoriesSelected": [
                "preprocessor_portscan"
            ]
        }
    },{
        "profileId":   "low_unknown",
        "systemStats": {
            "MemTotal": "1073741824",
            "architecture": ""
        },
        "activeGroups" : {
            "classtypes": "recommended",
            "classtypesSelected": [ 
                "+attempted-admin",
                "+attempted-user",
                "+inappropriate-content",
                "+policy-violation",
                "+shellcode-detect",
                "+successful-admin",
                "+successful-user",
                "+trojan-activity",
                "+unsuccessful-user",
                "+web-application-attack"
            ],
            "categories": "recommended",
            "categoriesSelected": [
                "preprocessor_portscan"
            ]
        }
    },{
        "profileId":   "medium_unknown",
        "systemStats": {
            "MemTotal": "2147483648",
            "architecture": ""
        },
        "activeGroups" : {
            "classtypes": "recommended",
            "classtypesSelected": [ 
                "+attempted-admin",
                "+attempted-user",
                "+inappropriate-content",
                "+policy-violation",
                "+shellcode-detect",
                "+successful-admin",
                "+successful-user",
                "+trojan-activity",
                "+unsuccessful-user",
                "+web-application-attack",
                "+attempted-dos",
                "+attempted-recon",
                "+bad-unknown",
                "+default-login-attempt",
                "+denial-of-service",
                "+misc-attack",
                "+non-standard-protocol",
                "+rpc-portmap-decode",
                "+successful-dos",
                "+successful-recon-largescale",
                "+successful-recon-limited",
                "+suspicious-ﬁlename-detect",
                "+suspicious-login",
                "+system-call-detect",
                "+unusual-client-port-connection",
                "+web-application-activity"
            ],
            "categories": "recommended",
            "categoriesSelected": [
                "preprocessor_portscan"
            ]
        }
    },{
        "profileId":   "high_unknown",
        "systemStats": {
            "MemTotal": "",
            "architecture": ""
        },
        "activeGroups" : {
            "classtypes": "recommended",
            "classtypesSelected": [ 
                "+attempted-admin",
                "+attempted-user",
                "+inappropriate-content",
                "+policy-violation",
                "+shellcode-detect",
                "+successful-admin",
                "+successful-user",
                "+trojan-activity",
                "+unsuccessful-user",
                "+web-application-attack",
                "+attempted-dos",
                "+attempted-recon",
                "+bad-unknown",
                "+default-login-attempt",
                "+denial-of-service",
                "+misc-attack",
                "+non-standard-protocol",
                "+rpc-portmap-decode",
                "+successful-dos",
                "+successful-recon-largescale",
                "+successful-recon-limited",
                "+suspicious-ﬁlename-detect",
                "+suspicious-login",
                "+system-call-detect",
                "+unusual-client-port-connection",
                "+web-application-activity",
                "+icmp-event",
                "+misc-activity",
                "+network-scan",
                "+not-suspicious",
                "+protocol-command-decode",
                "+string-detect",
                "+unknown",
                "+tcp-connection"
            ],
            "categories": "recommended",
            "categoriesSelected": [
                "preprocessor_portscan"
            ]
        }
    }]
}
