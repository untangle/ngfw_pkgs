{
    "accessRules": {
        "javaClass": "java.util.LinkedList",
        "list": [
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "22"
                        },
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "TCP"
                        }
                    ]
                },
                "description": "Allow SSH",
                "enabled": false,
                "ipv6Enabled": false,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 1
            },
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "443"
                        },
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "TCP"
                        },
                        {
                            "conditionType": "SRC_INTF",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "wan"
                        }
                    ]
                },
                "description": "Allow HTTPS on WANs",
                "enabled": false,
                "ipv6Enabled": false,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 2
            },
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "443"
                        },
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "TCP"
                        },
                        {
                            "conditionType": "SRC_INTF",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "non_wan"
                        }
                    ]
                },
                "description": "Allow HTTPS on non-WANs",
                "enabled": true,
                "ipv6Enabled": true,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 3
            },
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "1812, 1813"
                        },
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "UDP"
                        },
                        {
                            "conditionType": "SRC_INTF",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "wan"
                        }
                    ]
                },
                "description": "Allow RADIUS on WANs",
                "enabled": false,
                "ipv6Enabled": false,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 4
            },
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "1812, 1813"
                        },
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "UDP"
                        },
                        {
                            "conditionType": "SRC_INTF",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "non_wan"
                        }
                    ]
                },
                "description": "Allow RADIUS on non-WANs",
                "enabled": true,
                "ipv6Enabled": true,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 5
            },
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "ICMP"
                        }
                    ]
                },
                "description": "Allow PING",
                "enabled": true,
                "ipv6Enabled": true,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 6
            },
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "53"
                        },
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "TCP,UDP"
                        },
                        {
                            "conditionType": "SRC_INTF",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "non_wan"
                        }
                    ]
                },
                "description": "Allow DNS on non-WANs",
                "enabled": true,
                "ipv6Enabled": true,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 7
            },
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "67"
                        },
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "UDP"
                        },
                        {
                            "conditionType": "SRC_INTF",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "non_wan"
                        }
                    ]
                },
                "description": "Allow DHCP on non-WANs",
                "enabled": true,
                "ipv6Enabled": true,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 8
            },
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "80"
                        },
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "TCP"
                        },
                        {
                            "conditionType": "SRC_INTF",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "non_wan"
                        }
                    ]
                },
                "description": "Allow HTTP on non-WANs",
                "enabled": true,
                "ipv6Enabled": true,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 9
            },
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "161"
                        },
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "UDP"
                        },
                        {
                            "conditionType": "SRC_INTF",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "non_wan"
                        }
                    ]
                },
                "description": "Allow SNMP on non-WANs",
                "enabled": true,
                "ipv6Enabled": true,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 10
            },
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "1900"
                        },
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "UDP"
                        },
                        {
                            "conditionType": "SRC_INTF",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "non_wan"
                        }
                    ]
                },
                "description": "Allow UPnP (UDP/1900) on non-WANs",
                "enabled": true,
                "ipv6Enabled": true,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 11
            },
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "5000"
                        },
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "TCP"
                        },
                        {
                            "conditionType": "SRC_INTF",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "non_wan"
                        }
                    ]
                },
                "description": "Allow UPnP (TCP/5000) on non-WANs",
                "enabled": true,
                "ipv6Enabled": true,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 12
            },
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "5351"
                        },
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "UDP"
                        },
                        {
                            "conditionType": "SRC_INTF",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "non_wan"
                        }
                    ]
                },
                "description": "Allow UPnP (UDP/5351) on non-WANs",
                "enabled": true,
                "ipv6Enabled": true,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 13
            },
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "179"
                        },
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "TCP"
                        }
                    ]
                },
                "description": "Allow Dynamic Routing BGP (TCP/179)",
                "enabled": true,
                "ipv6Enabled": true,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 14
            },
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "OSPF"
                        }
                    ]
                },
                "description": "Allow Dynamic Routing OSPF",
                "enabled": true,
                "ipv6Enabled": true,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 15
            },
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "AH,ESP"
                        }
                    ]
                },
                "description": "Allow AH/ESP for IPsec",
                "enabled": true,
                "ipv6Enabled": true,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 16
            },
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "UDP"
                        },
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "500"
                        }
                    ]
                },
                "description": "Allow IKE for IPsec",
                "enabled": true,
                "ipv6Enabled": true,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 17
            },
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "UDP"
                        },
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "4500"
                        }
                    ]
                },
                "description": "Allow NAT-T for IPsec",
                "enabled": true,
                "ipv6Enabled": true,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 18
            },
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "UDP"
                        },
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "1701"
                        }
                    ]
                },
                "description": "Allow L2TP",
                "enabled": true,
                "ipv6Enabled": true,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 19
            },
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "UDP"
                        },
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "1194"
                        },
                        {
                            "conditionType": "SRC_INTF",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "wan"
                        }
                    ]
                },
                "description": "Allow OpenVPN",
                "enabled": true,
                "ipv6Enabled": true,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 20
            },
            {
                "blocked": false,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "UDP"
                        },
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "51820"
                        },
                        {
                            "conditionType": "SRC_INTF",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.FilterRuleCondition",
                            "value": "wan"
                        }
                    ]
                },
                "description": "Allow WireGuard",
                "enabled": true,
                "ipv6Enabled": true,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 21
            },
            {
                "blocked": true,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "description": "Block All",
                "enabled": true,
                "ipv6Enabled": true,
                "javaClass": "com.untangle.uvm.network.FilterRule",
                "readOnly": true,
                "ruleId": 22
            }
        ]
    },
    "blockDuringRestarts": false,
    "blockInvalidPackets": true,
    "blockReplayPackets": false,
    "bypassRules": {
        "javaClass": "java.util.LinkedList",
        "list": [
            {
                "bypass": true,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.BypassRuleCondition",
                            "value": "53"
                        }
                    ]
                },
                "description": "Bypass DNS Sessions",
                "enabled": false,
                "javaClass": "com.untangle.uvm.network.BypassRule",
                "ruleId": 1
            },
            {
                "bypass": true,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.BypassRuleCondition",
                            "value": "5060"
                        }
                    ]
                },
                "description": "Bypass VoIP (SIP) Sessions",
                "enabled": true,
                "javaClass": "com.untangle.uvm.network.BypassRule",
                "ruleId": 2
            },
            {
                "bypass": true,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.BypassRuleCondition",
                            "value": "4569"
                        }
                    ]
                },
                "description": "Bypass VoIP (IAX2) Sessions",
                "enabled": true,
                "javaClass": "com.untangle.uvm.network.BypassRule",
                "ruleId": 3
            },
            {
                "bypass": true,
                "conditions": {
                    "javaClass": "java.util.LinkedList",
                    "list": [
                        {
                            "conditionType": "DST_PORT",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.BypassRuleCondition",
                            "value": "1723"
                        },
                        {
                            "conditionType": "PROTOCOL",
                            "invert": false,
                            "javaClass": "com.untangle.uvm.network.BypassRuleCondition",
                            "value": "TCP"
                        }
                    ]
                },
                "description": "Bypass PPTP Sessions",
                "enabled": true,
                "javaClass": "com.untangle.uvm.network.BypassRule",
                "ruleId": 4
            }
        ]
    },
    "devices": {
        "javaClass": "java.util.LinkedList",
        "list": [
            {
                "deviceName": "eth0",
                "duplex": "AUTO",
                "javaClass": "com.untangle.uvm.network.DeviceSettings"
            },
            {
                "deviceName": "eth1",
                "duplex": "AUTO",
                "javaClass": "com.untangle.uvm.network.DeviceSettings"
            },
            {
                "deviceName": "eth2",
                "duplex": "AUTO",
                "javaClass": "com.untangle.uvm.network.DeviceSettings"
            },
            {
                "deviceName": "eth3",
                "duplex": "AUTO",
                "javaClass": "com.untangle.uvm.network.DeviceSettings"
            },
            {
                "deviceName": "eth4",
                "duplex": "AUTO",
                "javaClass": "com.untangle.uvm.network.DeviceSettings"
            },
            {
                "deviceName": "eth5",
                "duplex": "AUTO",
                "javaClass": "com.untangle.uvm.network.DeviceSettings"
            },
            {
                "deviceName": "eth6",
                "duplex": "AUTO",
                "javaClass": "com.untangle.uvm.network.DeviceSettings"
            },
            {
                "deviceName": "eth7",
                "duplex": "AUTO",
                "javaClass": "com.untangle.uvm.network.DeviceSettings"
            }
        ]
    },
    "dhcpAuthoritative": true,
    "dnsSettings": {
        "javaClass": "com.untangle.uvm.network.DnsSettings",
        "localServers": {
            "javaClass": "java.util.LinkedList",
            "list": []
        },
        "staticEntries": {
            "javaClass": "java.util.LinkedList",
            "list": []
        }
    },
    "domainName": "example.com",
    "dynamicDnsServiceEnabled": false,
    "dynamicRoutingSettings": {
        "bgpEnabled": false,
        "bgpNeighbors": {
            "javaClass": "java.util.LinkedList",
            "list": []
        },
        "bgpNetworks": {
            "javaClass": "java.util.LinkedList",
            "list": []
        },
        "bgpRouterAs": "",
        "bgpRouterId": "",
        "enabled": false,
        "javaClass": "com.untangle.uvm.network.DynamicRoutingSettings",
        "ospfAbrType": 0,
        "ospfAreas": {
            "javaClass": "java.util.LinkedList",
            "list": [
                {
                    "area": "0.0.0.0",
                    "authentication": 0,
                    "description": "Backbone",
                    "javaClass": "com.untangle.uvm.network.DynamicRouteOspfArea",
                    "ruleId": 1,
                    "type": 0,
                    "virtualLinks": {
                        "javaClass": "java.util.LinkedList",
                        "list": []
                    }
                }
            ]
        },
        "ospfAutoCost": 0,
        "ospfDefaultInformationOriginateExternalType": 1,
        "ospfDefaultInformationOriginateMetric": 0,
        "ospfDefaultInformationOriginateType": 0,
        "ospfDefaultMetric": 0,
        "ospfEnabled": false,
        "ospfInterfaces": {
            "javaClass": "java.util.LinkedList",
            "list": []
        },
        "ospfNetworks": {
            "javaClass": "java.util.LinkedList",
            "list": []
        },
        "ospfRedistBgpEnabled": false,
        "ospfRedistBgpExternalType": 1,
        "ospfRedistBgpMetric": 0,
        "ospfRedistConnectedEnabled": false,
        "ospfRedistConnectedExternalType": 1,
        "ospfRedistConnectedMetric": 0,
        "ospfRedistStaticEnabled": false,
        "ospfRedistStaticExternalType": 1,
        "ospfRedistStaticMetric": 0,
        "ospfRouterId": "",
        "ospfUseDefaultMetricEnabled": false
    },
    "enableSipNatHelper": false,
    "filterRules": {
        "javaClass": "java.util.LinkedList",
        "list": []
    },
    "hostName": "untangle",
    "httpPort": 80,
    "httpsPort": 443,
    "interfaces": {
        "javaClass": "java.util.LinkedList",
        "list": [
            {
                "configType": "ADDRESSED",
                "dhcpDnsOverride": "",
                "dhcpEnabled": false,
                "dhcpLeaseDuration": 0,
                "dhcpOptions": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "downloadBandwidthKbps": 0,
                "hidden": false,
                "imqDev": "imq0",
                "interfaceId": 1,
                "isVirtualInterface": false,
                "isVlanInterface": false,
                "isWan": true,
                "isWirelessInterface": false,
                "javaClass": "com.untangle.uvm.network.InterfaceSettings",
                "name": "INTERNET",
                "physicalDev": "eth0",
                "symbolicDev": "eth0",
                "systemDev": "eth0",
                "uploadBandwidthKbps": 0,
                "v4Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v4ConfigType": "AUTO",
                "v4NatEgressTraffic": true,
                "v4NatIngressTraffic": false,
                "v4PPPoEPassword": "",
                "v4PPPoERootDev": "",
                "v4PPPoEUsePeerDns": false,
                "v4PPPoEUsername": "",
                "v6Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v6ConfigType": "DISABLED",
                "vlanParent": 0,
                "vlanTag": 0,
                "vrrpAliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "vrrpEnabled": false,
                "wirelessMode": "AP",
                "wirelessPassword": "",
                "wirelessSsid": "",
                "wirelessVisibility": 0
            },
            {
                "bridgedTo": 1,
                "configType": "ADDRESSED",
                "dhcpDnsOverride": "",
                "dhcpEnabled": true,
                "dhcpLeaseDuration": 3600,
                "dhcpOptions": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "dhcpRangeEnd": "192.168.2.200",
                "dhcpRangeStart": "192.168.2.100",
                "downloadBandwidthKbps": 0,
                "hidden": false,
                "interfaceId": 2,
                "isVirtualInterface": false,
                "isVlanInterface": false,
                "isWan": false,
                "isWirelessInterface": false,
                "javaClass": "com.untangle.uvm.network.InterfaceSettings",
                "name": "Interface 2",
                "physicalDev": "eth1",
                "symbolicDev": "br.eth1",
                "systemDev": "eth1",
                "uploadBandwidthKbps": 0,
                "v4Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v4ConfigType": "STATIC",
                "v4NatEgressTraffic": false,
                "v4NatIngressTraffic": false,
                "v4PPPoEPassword": "",
                "v4PPPoERootDev": "",
                "v4PPPoEUsePeerDns": false,
                "v4PPPoEUsername": "",
                "v4StaticAddress": "192.168.2.1",
                "v4StaticNetmask": "255.255.255.0",
                "v4StaticPrefix": 24,
                "v6Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v6ConfigType": "STATIC",
                "v6StaticPrefixLength": 64,
                "vlanParent": 0,
                "vlanTag": 0,
                "vrrpAliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "vrrpEnabled": false,
                "wirelessMode": "AP",
                "wirelessPassword": "",
                "wirelessSsid": "",
                "wirelessVisibility": 0
            },
            {
                "bridgedTo": 2,
                "configType": "BRIDGED",
                "dhcpDnsOverride": "",
                "dhcpEnabled": false,
                "dhcpLeaseDuration": 0,
                "dhcpOptions": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "downloadBandwidthKbps": 0,
                "hidden": false,
                "interfaceId": 3,
                "isVirtualInterface": false,
                "isVlanInterface": false,
                "isWan": false,
                "isWirelessInterface": false,
                "javaClass": "com.untangle.uvm.network.InterfaceSettings",
                "name": "Interface 3",
                "physicalDev": "eth2",
                "symbolicDev": "br.eth1",
                "systemDev": "eth2",
                "uploadBandwidthKbps": 0,
                "v4Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v4ConfigType": "STATIC",
                "v4NatEgressTraffic": false,
                "v4NatIngressTraffic": false,
                "v4PPPoEPassword": "",
                "v4PPPoERootDev": "",
                "v4PPPoEUsePeerDns": false,
                "v4PPPoEUsername": "",
                "v6Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v6ConfigType": "STATIC",
                "vlanParent": 0,
                "vlanTag": 0,
                "vrrpAliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "vrrpEnabled": false,
                "wirelessMode": "AP",
                "wirelessPassword": "",
                "wirelessSsid": "",
                "wirelessVisibility": 0
            },
            {
                "bridgedTo": 2,
                "configType": "BRIDGED",
                "dhcpDnsOverride": "",
                "dhcpEnabled": false,
                "dhcpLeaseDuration": 0,
                "dhcpOptions": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "downloadBandwidthKbps": 0,
                "hidden": false,
                "interfaceId": 4,
                "isVirtualInterface": false,
                "isVlanInterface": false,
                "isWan": false,
                "isWirelessInterface": false,
                "javaClass": "com.untangle.uvm.network.InterfaceSettings",
                "name": "Interface 4",
                "physicalDev": "eth3",
                "symbolicDev": "br.eth1",
                "systemDev": "eth3",
                "uploadBandwidthKbps": 0,
                "v4Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v4ConfigType": "STATIC",
                "v4NatEgressTraffic": false,
                "v4NatIngressTraffic": false,
                "v4PPPoEPassword": "",
                "v4PPPoERootDev": "",
                "v4PPPoEUsePeerDns": false,
                "v4PPPoEUsername": "",
                "v6Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v6ConfigType": "STATIC",
                "vlanParent": 0,
                "vlanTag": 0,
                "vrrpAliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "vrrpEnabled": false,
                "wirelessMode": "AP",
                "wirelessPassword": "",
                "wirelessSsid": "",
                "wirelessVisibility": 0
            },
            {
                "bridgedTo": 2,
                "configType": "BRIDGED",
                "dhcpDnsOverride": "",
                "dhcpEnabled": false,
                "dhcpLeaseDuration": 0,
                "dhcpOptions": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "downloadBandwidthKbps": 0,
                "hidden": false,
                "interfaceId": 5,
                "isVirtualInterface": false,
                "isVlanInterface": false,
                "isWan": false,
                "isWirelessInterface": false,
                "javaClass": "com.untangle.uvm.network.InterfaceSettings",
                "name": "Interface 5",
                "physicalDev": "eth4",
                "symbolicDev": "br.eth1",
                "systemDev": "eth4",
                "uploadBandwidthKbps": 0,
                "v4Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v4ConfigType": "STATIC",
                "v4NatEgressTraffic": false,
                "v4NatIngressTraffic": false,
                "v4PPPoEPassword": "",
                "v4PPPoERootDev": "",
                "v4PPPoEUsePeerDns": false,
                "v4PPPoEUsername": "",
                "v6Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v6ConfigType": "STATIC",
                "vlanParent": 0,
                "vlanTag": 0,
                "vrrpAliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "vrrpEnabled": false,
                "wirelessMode": "AP",
                "wirelessPassword": "",
                "wirelessSsid": "",
                "wirelessVisibility": 0
            },
            {
                "bridgedTo": 2,
                "configType": "BRIDGED",
                "dhcpDnsOverride": "",
                "dhcpEnabled": false,
                "dhcpLeaseDuration": 0,
                "dhcpOptions": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "downloadBandwidthKbps": 0,
                "hidden": false,
                "interfaceId": 6,
                "isVirtualInterface": false,
                "isVlanInterface": false,
                "isWan": false,
                "isWirelessInterface": false,
                "javaClass": "com.untangle.uvm.network.InterfaceSettings",
                "name": "Interface 6",
                "physicalDev": "eth5",
                "symbolicDev": "br.eth1",
                "systemDev": "eth5",
                "uploadBandwidthKbps": 0,
                "v4Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v4ConfigType": "STATIC",
                "v4NatEgressTraffic": false,
                "v4NatIngressTraffic": false,
                "v4PPPoEPassword": "",
                "v4PPPoERootDev": "",
                "v4PPPoEUsePeerDns": false,
                "v4PPPoEUsername": "",
                "v6Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v6ConfigType": "STATIC",
                "vlanParent": 0,
                "vlanTag": 0,
                "vrrpAliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "vrrpEnabled": false,
                "wirelessMode": "AP",
                "wirelessPassword": "",
                "wirelessSsid": "",
                "wirelessVisibility": 0
            },
            {
                "bridgedTo": 2,
                "configType": "BRIDGED",
                "dhcpDnsOverride": "",
                "dhcpEnabled": false,
                "dhcpLeaseDuration": 0,
                "dhcpOptions": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "downloadBandwidthKbps": 0,
                "hidden": false,
                "interfaceId": 7,
                "isVirtualInterface": false,
                "isVlanInterface": false,
                "isWan": false,
                "isWirelessInterface": false,
                "javaClass": "com.untangle.uvm.network.InterfaceSettings",
                "name": "Interface 7",
                "physicalDev": "eth6",
                "symbolicDev": "br.eth1",
                "systemDev": "eth6",
                "uploadBandwidthKbps": 0,
                "v4Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v4ConfigType": "STATIC",
                "v4NatEgressTraffic": false,
                "v4NatIngressTraffic": false,
                "v4PPPoEPassword": "",
                "v4PPPoERootDev": "",
                "v4PPPoEUsePeerDns": false,
                "v4PPPoEUsername": "",
                "v6Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v6ConfigType": "STATIC",
                "vlanParent": 0,
                "vlanTag": 0,
                "vrrpAliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "vrrpEnabled": false,
                "wirelessMode": "AP",
                "wirelessPassword": "",
                "wirelessSsid": "",
                "wirelessVisibility": 0
            },
            {
                "bridgedTo": 2,
                "configType": "BRIDGED",
                "dhcpDnsOverride": "",
                "dhcpEnabled": false,
                "dhcpLeaseDuration": 0,
                "dhcpOptions": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "downloadBandwidthKbps": 0,
                "hidden": false,
                "interfaceId": 8,
                "isVirtualInterface": false,
                "isVlanInterface": false,
                "isWan": false,
                "isWirelessInterface": false,
                "javaClass": "com.untangle.uvm.network.InterfaceSettings",
                "name": "Interface 8",
                "physicalDev": "eth7",
                "symbolicDev": "br.eth1",
                "systemDev": "eth7",
                "uploadBandwidthKbps": 0,
                "v4Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v4ConfigType": "STATIC",
                "v4NatEgressTraffic": false,
                "v4NatIngressTraffic": false,
                "v4PPPoEPassword": "",
                "v4PPPoERootDev": "",
                "v4PPPoEUsePeerDns": false,
                "v4PPPoEUsername": "",
                "v6Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v6ConfigType": "STATIC",
                "vlanParent": 0,
                "vlanTag": 0,
                "vrrpAliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "vrrpEnabled": false,
                "wirelessMode": "AP",
                "wirelessPassword": "",
                "wirelessSsid": "",
                "wirelessVisibility": 0
            }
        ]
    },
    "javaClass": "com.untangle.uvm.network.NetworkSettings",
    "logBlockedSessions": false,
    "logBypassedSessions": true,
    "logLocalInboundSessions": false,
    "logLocalOutboundSessions": true,
    "lxcInterfaceId": 0,
    "natRules": {
        "javaClass": "java.util.LinkedList",
        "list": []
    },
    "netflowSettings": {
        "enabled": false,
        "host": "1.2.3.4",
        "javaClass": "com.untangle.uvm.network.NetflowSettings",
        "port": 2055,
        "version": 9
    },
    "portForwardRules": {
        "javaClass": "java.util.LinkedList",
        "list": []
    },
    "publicUrlAddress": "hostname.example.com",
    "publicUrlMethod": "external",
    "publicUrlPort": 443,
    "qosSettings": {
        "defaultPriority": 3,
        "dnsPriority": 1,
        "javaClass": "com.untangle.uvm.network.QosSettings",
        "openvpnPriority": 0,
        "pingPriority": 1,
        "qosEnabled": false,
        "qosPriorities": {
            "javaClass": "java.util.LinkedList",
            "list": [
                {
                    "downloadLimit": 100,
                    "downloadReservation": 50,
                    "javaClass": "com.untangle.uvm.network.QosPriority",
                    "priorityId": 1,
                    "priorityName": "Very High",
                    "uploadLimit": 100,
                    "uploadReservation": 50
                },
                {
                    "downloadLimit": 100,
                    "downloadReservation": 25,
                    "javaClass": "com.untangle.uvm.network.QosPriority",
                    "priorityId": 2,
                    "priorityName": "High",
                    "uploadLimit": 100,
                    "uploadReservation": 25
                },
                {
                    "downloadLimit": 100,
                    "downloadReservation": 12,
                    "javaClass": "com.untangle.uvm.network.QosPriority",
                    "priorityId": 3,
                    "priorityName": "Medium",
                    "uploadLimit": 100,
                    "uploadReservation": 12
                },
                {
                    "downloadLimit": 100,
                    "downloadReservation": 6,
                    "javaClass": "com.untangle.uvm.network.QosPriority",
                    "priorityId": 4,
                    "priorityName": "Low",
                    "uploadLimit": 100,
                    "uploadReservation": 6
                },
                {
                    "downloadLimit": 75,
                    "downloadReservation": 3,
                    "javaClass": "com.untangle.uvm.network.QosPriority",
                    "priorityId": 5,
                    "priorityName": "Limited",
                    "uploadLimit": 75,
                    "uploadReservation": 3
                },
                {
                    "downloadLimit": 50,
                    "downloadReservation": 2,
                    "javaClass": "com.untangle.uvm.network.QosPriority",
                    "priorityId": 6,
                    "priorityName": "Limited More",
                    "uploadLimit": 50,
                    "uploadReservation": 2
                },
                {
                    "downloadLimit": 10,
                    "downloadReservation": 2,
                    "javaClass": "com.untangle.uvm.network.QosPriority",
                    "priorityId": 7,
                    "priorityName": "Limited Severely",
                    "uploadLimit": 10,
                    "uploadReservation": 2
                }
            ]
        },
        "qosRules": {
            "javaClass": "java.util.LinkedList",
            "list": [
                {
                    "conditions": {
                        "javaClass": "java.util.LinkedList",
                        "list": [
                            {
                                "conditionType": "DST_PORT",
                                "invert": false,
                                "javaClass": "com.untangle.uvm.network.QosRuleCondition",
                                "value": "5060,5061"
                            },
                            {
                                "conditionType": "PROTOCOL",
                                "invert": false,
                                "javaClass": "com.untangle.uvm.network.QosRuleCondition",
                                "value": "TCP,UDP"
                            }
                        ]
                    },
                    "description": "VoIP (SIP) Traffic",
                    "enabled": true,
                    "javaClass": "com.untangle.uvm.network.QosRule",
                    "priority": 1,
                    "ruleId": 1
                },
                {
                    "conditions": {
                        "javaClass": "java.util.LinkedList",
                        "list": [
                            {
                                "conditionType": "DST_PORT",
                                "invert": false,
                                "javaClass": "com.untangle.uvm.network.QosRuleCondition",
                                "value": "4569"
                            },
                            {
                                "conditionType": "PROTOCOL",
                                "invert": false,
                                "javaClass": "com.untangle.uvm.network.QosRuleCondition",
                                "value": "TCP,UDP"
                            }
                        ]
                    },
                    "description": "VoIP (IAX) Traffic",
                    "enabled": true,
                    "javaClass": "com.untangle.uvm.network.QosRule",
                    "priority": 1,
                    "ruleId": 2
                }
            ]
        },
        "queueDiscipline": "fq_codel",
        "sshPriority": 0
    },
    "sendIcmpRedirects": true,
    "staticDhcpEntries": {
        "javaClass": "java.util.LinkedList",
        "list": []
    },
    "staticRoutes": {
        "javaClass": "java.util.LinkedList",
        "list": []
    },
    "stpEnabled": false,
    "strictArpMode": true,
    "upnpSettings": {
        "javaClass": "com.untangle.uvm.network.UpnpSettings",
        "listenPort": 5000,
        "secureMode": true,
        "upnpEnabled": false,
        "upnpRules": {
            "javaClass": "java.util.LinkedList",
            "list": [
                {
                    "allow": true,
                    "conditions": {
                        "javaClass": "java.util.LinkedList",
                        "list": [
                            {
                                "conditionType": "SRC_ADDR",
                                "invert": false,
                                "javaClass": "com.untangle.uvm.network.UpnpRuleCondition",
                                "value": "0.0.0.0/0"
                            },
                            {
                                "conditionType": "DST_PORT",
                                "invert": false,
                                "javaClass": "com.untangle.uvm.network.UpnpRuleCondition",
                                "value": "1024-65535"
                            },
                            {
                                "conditionType": "SRC_PORT",
                                "invert": false,
                                "javaClass": "com.untangle.uvm.network.UpnpRuleCondition",
                                "value": "1024-65535"
                            }
                        ]
                    },
                    "description": "Allow all",
                    "enabled": true,
                    "javaClass": "com.untangle.uvm.network.UpnpRule",
                    "ruleId": 1
                },
                {
                    "allow": false,
                    "conditions": {
                        "javaClass": "java.util.LinkedList",
                        "list": [
                            {
                                "conditionType": "SRC_ADDR",
                                "invert": false,
                                "javaClass": "com.untangle.uvm.network.UpnpRuleCondition",
                                "value": "0.0.0.0/0"
                            },
                            {
                                "conditionType": "DST_PORT",
                                "invert": false,
                                "javaClass": "com.untangle.uvm.network.UpnpRuleCondition",
                                "value": "0-65535"
                            },
                            {
                                "conditionType": "SRC_PORT",
                                "invert": false,
                                "javaClass": "com.untangle.uvm.network.UpnpRuleCondition",
                                "value": "0-65535"
                            }
                        ]
                    },
                    "description": "Deny all",
                    "enabled": true,
                    "javaClass": "com.untangle.uvm.network.UpnpRule",
                    "ruleId": 2
                }
            ]
        }
    },
    "version": 8,
    "virtualInterfaces": {
        "javaClass": "java.util.LinkedList",
        "list": [
            {
                "configType": "DISABLED",
                "interfaceId": 249,
                "isVirtualInterface": true,
                "isVlanInterface": false,
                "isWan": false,
                "isWirelessInterface": false,
                "javaClass": "com.untangle.uvm.network.InterfaceSettings",
                "name": "WireGuard VPN",
                "v4Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v4ConfigType": "AUTO",
                "v6Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v6ConfigType": "DISABLED",
                "vrrpAliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "wirelessMode": "AP",
                "wirelessVisibility": 0
            },
            {
                "configType": "DISABLED",
                "interfaceId": 250,
                "isVirtualInterface": true,
                "isVlanInterface": false,
                "isWan": false,
                "isWirelessInterface": false,
                "javaClass": "com.untangle.uvm.network.InterfaceSettings",
                "name": "OpenVPN",
                "v4Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v4ConfigType": "AUTO",
                "v6Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v6ConfigType": "DISABLED",
                "vrrpAliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "wirelessMode": "AP",
                "wirelessVisibility": 0
            },
            {
                "configType": "DISABLED",
                "interfaceId": 251,
                "isVirtualInterface": true,
                "isVlanInterface": false,
                "isWan": false,
                "isWirelessInterface": false,
                "javaClass": "com.untangle.uvm.network.InterfaceSettings",
                "name": "L2TP",
                "v4Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v4ConfigType": "AUTO",
                "v6Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v6ConfigType": "DISABLED",
                "vrrpAliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "wirelessMode": "AP",
                "wirelessVisibility": 0
            },
            {
                "configType": "DISABLED",
                "interfaceId": 252,
                "isVirtualInterface": true,
                "isVlanInterface": false,
                "isWan": false,
                "isWirelessInterface": false,
                "javaClass": "com.untangle.uvm.network.InterfaceSettings",
                "name": "XAUTH",
                "v4Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v4ConfigType": "AUTO",
                "v6Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v6ConfigType": "DISABLED",
                "vrrpAliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "wirelessMode": "AP",
                "wirelessVisibility": 0
            },
            {
                "configType": "DISABLED",
                "interfaceId": 253,
                "isVirtualInterface": true,
                "isVlanInterface": false,
                "isWan": false,
                "isWirelessInterface": false,
                "javaClass": "com.untangle.uvm.network.InterfaceSettings",
                "name": "GRE",
                "v4Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v4ConfigType": "AUTO",
                "v6Aliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "v6ConfigType": "DISABLED",
                "vrrpAliases": {
                    "javaClass": "java.util.LinkedList",
                    "list": []
                },
                "wirelessMode": "AP",
                "wirelessVisibility": 0
            }
        ]
    },
    "vlansEnabled": true
}
