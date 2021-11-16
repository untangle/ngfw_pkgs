{
  "NetworkSettings": {
    "interfaces": {
      "list": [{
        "find":
          { "systemDev": "eth0" },
        "change":
          { "name": "INTERNET" }
        },{
        "find":
          { "systemDev": "eth1" },
        "change":
          {
            "name": "Interface 2",
          }
        },{
        "find":
          { "systemDev": "eth2" },
        "change":
          { 
            "name": "Interface 3",
            "configType": "BRIDGED",
            "bridgedTo": 2,
            "v4ConfigType": "STATIC",
            "v6ConfigType": "STATIC"
          }
        },{
        "find":
          { "systemDev": "eth3" },
        "change":
          { 
            "name": "Interface 4",
            "configType": "BRIDGED",
            "bridgedTo": 2,
            "v4ConfigType": "STATIC",
            "v6ConfigType": "STATIC"
          }
        },{
        "find":
          { "systemDev": "eth4" },
        "change":
          { 
            "name": "Interface 5",
            "configType": "BRIDGED",
            "bridgedTo": 2,
            "v4ConfigType": "STATIC",
            "v6ConfigType": "STATIC"
          }
        },{
        "find":
          { "systemDev": "eth5" },
        "change":
          { 
            "name": "Interface 6",
            "configType": "BRIDGED",
            "bridgedTo": 2,
            "v4ConfigType": "STATIC",
            "v6ConfigType": "STATIC"
          }
        },{
        "find":
          { "systemDev": "eth6" },
        "change":
          { 
            "name": "Interface 7",
            "configType": "BRIDGED",
            "bridgedTo": 2,
            "v4ConfigType": "STATIC",
            "v6ConfigType": "STATIC"
          }
        },{
        "find":
          { "systemDev": "eth7" },
        "change":
          { 
            "name": "Interface 8",
	    "configType": "BRIDGED",
            "bridgedTo": 2,
            "v4ConfigType": "STATIC",
            "v6ConfigType": "STATIC"
	  }
      }]
    },
  }
}
