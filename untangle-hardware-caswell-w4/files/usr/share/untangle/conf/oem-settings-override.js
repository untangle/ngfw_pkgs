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
      }]
    },
  }
}
