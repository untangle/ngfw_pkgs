export default {
  vlan: {
    name: '',
    type: 'VLAN',
    configType: 'ADDRESSED',
    enabled: true,
    wan: false,
    v4ConfigType: 'DISABLED',
    v6ConfigType: 'DISABLED',
  },

  bridge: {
    name: '',
    type: 'BRIDGE',
    configType: 'BRIDGED',
    enabled: true,
    wan: false,
    v4ConfigType: 'STATIC',
    v6ConfigType: 'DISABLED',
  },

  openvpn: {
    name: '',
    type: 'OPENVPN',
    configType: 'ADDRESSED',
    boundInterfaceId: 0, // any WAN
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
    boundInterfaceId: 0, // any WAN
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
    boundInterfaceId: 0,
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
    description: '[no description]',
    javaClass: 'com.untangle.uvm.network.DhcpOption',
  },
}
