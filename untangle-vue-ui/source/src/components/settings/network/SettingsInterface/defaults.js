export default {
  vlan: {
    name: '',
    type: 'VLAN',
    javaClass: 'com.untangle.uvm.network.InterfaceSettings',
    configType: 'ADDRESSED',
    enabled: true,
    disabled: false,
    wan: false,
    addressed: true,
    bridged: false,
    bridgedTo: null,
    symbolicDev: null,
    physicalDev: null,
    systemDev: null,
    interfaceId: -1,
    isVlanInterface: true,
    isWan: false,
    isWirelessInterface: false,
    hidden: null,
    reEnabled: false,
    supportedConfigTypes: [],
    imqDev: null,
    vlanParent: null,
    vlanTag: null,

    // IPv4
    v4ConfigType: 'STATIC',
    v4NatEgressTraffic: true,
    v4NatIngressTraffic: false,
    v4StaticAddress: null,
    v4StaticDns1: null,
    v4StaticDns2: null,
    v4StaticGateway: null,
    v4StaticNetmask: null,
    v4StaticPrefix: null,
    v4AutoAddressOverride: null,
    v4AutoDns1Override: null,
    v4AutoDns2Override: null,
    v4AutoGatewayOverride: null,
    v4AutoNetmaskOverride: null,
    v4AutoPrefixOverride: null,
    v4PPPoEUsername: '',
    v4PPPoEPassword: '',
    v4PPPoEDns1: null,
    v4PPPoEDns2: null,
    v4PPPoERootDev: null,
    v4PPPoEUsePeerDns: false,
    v4Aliases: { javaClass: 'java.util.LinkedList', list: [] },

    // IPv6
    v6ConfigType: 'STATIC',
    v6StaticAddress: null,
    v6StaticDns1: null,
    v6StaticDns2: null,
    v6StaticGateway: null,
    v6StaticPrefixLength: null,
    v6Aliases: { javaClass: 'java.util.LinkedList', list: [] },

    // DHCP
    dhcpType: 'DISABLED',
    dhcpDnsOverride: '',
    dhcpGatewayOverride: null,
    dhcpLeaseDuration: null,
    dhcpNetmaskDuration: null,
    dhcpOptions: { javaClass: 'java.util.LinkedList', list: [] },
    dhcpPrefixOverride: null,
    dhcpRangeStart: null,
    dhcpRangeEnd: null,

    // VRRP
    vrrpEnabled: false,
    vrrpId: null,
    vrrpPriority: null,
    vrrpAliases: { javaClass: 'java.util.LinkedList', list: [] },

    // Bandwidth
    uploadBandwidthKbps: null,
    downloadBandwidthKbps: null,

    // Wireless (not applicable but included for completeness)
    wirelessChannel: null,
    wirelessEncryption: null,
    wirelessPassword: '',
    wirelessSsid: '',

    // Status fields
    v4Address: null,
    v4Dns1: null,
    v4Dns2: null,
    v4Gateway: null,
    v4Netmask: null,
    v4PrefixLength: null,
    v6Address: null,
    v6Gateway: null,
    v6PrefixLength: null,

    // Device info
    connected: null,
    deviceName: null,
    duplex: null,
    macAddress: null,
    mbit: null,
    vendor: null,
  },
  bridge: {
    name: '',
    type: 'BRIDGE',
    configType: 'BRIDGED',
    enabled: true,
    wan: false,
    v4ConfigType: 'STATIC',
    v6ConfigType: 'DISABLED',
    v4NatEgressTraffic: true,
    v4NatIngressTraffic: false,
    v4Aliases: { javaClass: 'java.util.LinkedList', list: [] },
    v6Aliases: { javaClass: 'java.util.LinkedList', list: [] },
    dhcpOptions: { javaClass: 'java.util.LinkedList', list: [] },
  },

  openvpn: {
    name: '',
    type: 'OPENVPN',
    configType: 'ADDRESSED',
    vlanParent: 0, // any WAN
    enabled: true,
    wan: true,
    natEgress: true,
    new: true,
    openvpnConfFile: { contents: null, encoding: 'base64' },
    openvpnUsernamePasswordEnabled: false,
    openvpnUsername: null,
    openvpnPasswordBase64: null,
    openvpnPeerDns: false,
  },

  wireguard: {
    name: '',
    type: 'WIREGUARD',
    configType: 'ADDRESSED',
    vlanParent: 0, // any WAN
    enabled: true,
    wan: true,
    natEgress: true,
    new: true,
    wireguardType: 'ROAMING',
    wireguardAddresses: [{ address: '172.31.229.1', prefix: '24' }],
    wireguardPort: 51820,
    wireguardPeers: [
      {
        publicKey: null,
        host: null,
        port: null,
        allowedIps: [{ address: '0.0.0.0', prefix: 0 }],
        // peer 'presharedKey' is not implemented and used yet
        presharedKey: null,
        // peer 'keepalive' defaults to 60 seconds (not shown and not changeable)
        keepalive: 60,
        // peer 'routeAllowedIps' always true (not shown and not changeable)
        routeAllowedIps: true,
      },
    ],
    wireguardPrivateKey: null,
    wireguardPublicKey: null,
  },

  ipsec: {
    name: '',
    type: 'IPSEC',
    configType: 'ADDRESSED',
    vlanParent: 0,
    enabled: true,
    wan: true,
    natEgress: false,
    new: true,
    mtu: 1500,
    routeMtu: true,
    ipsec: {
      authentication: {
        shared_secret: '',
        type: 'shared_secret',
      },
      debug: 2,
      keyexchange: 'ikev2',
      local: {
        gateway: '%any',
        networks: [],
      },
      remote: {
        gateway: '',
        networks: [],
      },
      singleSubnetNegotiation: true,
      phase1: [
        {
          encryption: 'aes256',
          hash: 'sha1',
          group: 'modp2048',
        },
      ],
      phase2: [
        {
          encryption: 'aes256gcm128',
          hash: 'sha1',
          group: 'modp2048',
        },
      ],
      phase1Lifetime: '28800', // default p1 lifetime
      phase2Lifetime: '3600', // default p2 lifetime
    },
  },
  ipsec_network: {
    network: '0.0.0.0',
    prefix: 0,
  },
  v4_alias: {
    staticAddress: '',
    staticPrefix: 24, // use 24 as default
    markedForDelete: false,
    markedForNew: false,
    javaClass: 'com.untangle.uvm.network.InterfaceSettings$InterfaceAlias',
  },
  v6_alias: {
    staticAddress: '::1',
    staticPrefix: 64,
    staticNetmask: '',
    markedForDelete: false,
    markedForNew: false,
    javaClass: 'com.untangle.uvm.network.InterfaceSettings$InterfaceAlias',
  },
  vrrp_alias: {
    staticAddress: '1.2.3.4',
    staticPrefix: 24,
    javaClass: 'com.untangle.uvm.network.InterfaceSettings$InterfaceAlias',
  },
  dhcp_options: {
    enabled: true,
    value: '66,1.2.3.4',
    description: '',
    javaClass: 'com.untangle.uvm.network.DhcpOption',
  },
}
