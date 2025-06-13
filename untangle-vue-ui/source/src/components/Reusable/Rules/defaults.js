/**
 * Default filter rules
 */
export const filterDefaultRules = [
  {
    'action': {
      'type': 'DROP',
    },
    'conditions': [
      {
        'op': '==',
        'type': 'CT_STATE',
        'value': 'invalid',
      },
    ],
    'description': 'Drop packets not related to any session',
    'enabled': true,
    'ruleId': '5f0cbc6f-72b7-4fdd-80d1-1f63f1bbfe31',
  },
]

/**
 * Default access rules
 */
export const accessDefaultRules = [
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'type': 'SOURCE_INTERFACE_TYPE',
        'value': '1',
      },
      {
        'op': '==',
        'type': 'IP_PROTOCOL',
        'value': '50,51',
      },
    ],
    'description': 'Accept IPsec Authentication Header, Encap Security Payload (AH, ESP)',
    'enabled': false,
    'ruleId': '1953c304-94db-4a43-853a-a480a56b7b6d',
  },
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'type': 'SOURCE_INTERFACE_TYPE',
        'value': '1',
      },
      {
        'op': '==',
        'port_protocol': 17,
        'type': 'DESTINATION_PORT',
        'value': 500,
      },
    ],
    'description': 'Accept IPsec IKE (UDP/500)',
    'enabled': false,
    'ruleId': '1953c74b-1cc4-4b1d-8895-21ddf662061f',
  },
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'type': 'SOURCE_INTERFACE_TYPE',
        'value': '1',
      },
      {
        'op': '==',
        'port_protocol': 17,
        'type': 'DESTINATION_PORT',
        'value': 4500,
      },
    ],
    'description': 'Accept IPsec NAT-T (UDP/4500)',
    'enabled': false,
    'ruleId': '1953ce84-9dcd-48b6-a80c-b56543492d41',
  },
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'type': 'CT_STATE',
        'value': 'established',
      },
    ],
    'description': 'Accept established',
    'enabled': true,
    'ruleId': '95cad93e-07ca-427e-b401-00d3610a1aaf',
  },
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'type': 'CT_STATE',
        'value': 'related',
      },
    ],
    'description': 'Accept related',
    'enabled': true,
    'ruleId': '6c7990fc-b8c6-4f62-92fe-6dc992ac69e9',
  },
  {
    'action': {
      'type': 'DROP',
    },
    'conditions': [
      {
        'op': '==',
        'type': 'CT_STATE',
        'value': 'invalid',
      },
    ],
    'description': 'Drop invalid',
    'enabled': true,
    'ruleId': 'ada03aa3-eae6-421a-b27c-41c66577fdf4',
  },
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'type': 'SOURCE_INTERFACE_NAME',
        'value': 'lo',
      },
    ],
    'description': 'Accept loopback',
    'enabled': true,
    'ruleId': 'fe27f73f-5ea2-4a4e-a7fb-c37c3132ab16',
  },
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'port_protocol': 6,
        'type': 'DESTINATION_PORT',
        'value': '80',
      },
      {
        'op': '==',
        'type': 'SOURCE_INTERFACE_TYPE',
        'value': 2,
      },
    ],
    'description': 'Accept HTTP on LANs (TCP/80)',
    'enabled': true,
    'ruleId': 'cb6a0ac6-f47a-46a6-8a14-a5bb47ee4b2b',
  },
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'port_protocol': 6,
        'type': 'DESTINATION_PORT',
        'value': '80',
      },
      {
        'op': '==',
        'type': 'SOURCE_INTERFACE_TYPE',
        'value': 1,
      },
    ],
    'description': 'Accept HTTP on WANs (TCP/80)',
    'enabled': false,
    'ruleId': '4c1e0f19-6844-4688-ae3c-b2f75f2509d4',
  },
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'port_protocol': 6,
        'type': 'DESTINATION_PORT',
        'value': '443',
      },
      {
        'op': '==',
        'type': 'SOURCE_INTERFACE_TYPE',
        'value': 2,
      },
    ],
    'description': 'Accept HTTPS on LANs (TCP/443)',
    'enabled': true,
    'ruleId': '43b73e91-4cbc-458e-bad2-1558d1abf4a1',
  },
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'port_protocol': 6,
        'type': 'DESTINATION_PORT',
        'value': '443',
      },
      {
        'op': '==',
        'type': 'SOURCE_INTERFACE_TYPE',
        'value': 1,
      },
    ],
    'description': 'Accept HTTPS on WANs (TCP/443)',
    'enabled': false,
    'ruleId': 'a0fbd82a-ff0f-4fc0-9b43-d723b5e07288',
  },
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'port_protocol': 6,
        'type': 'DESTINATION_PORT',
        'value': '22',
      },
      {
        'op': '==',
        'type': 'SOURCE_INTERFACE_TYPE',
        'value': 2,
      },
    ],
    'description': 'Accept SSH on LANs (TCP/22)',
    'enabled': true,
    'ruleId': '691b4ef3-28f8-43d8-95db-c4274aa9e901',
  },
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'port_protocol': 6,
        'type': 'DESTINATION_PORT',
        'value': '22',
      },
      {
        'op': '==',
        'type': 'SOURCE_INTERFACE_TYPE',
        'value': 1,
      },
    ],
    'description': 'Accept SSH on WANs (TCP/22)',
    'enabled': false,
    'ruleId': '6fdedc33-cf55-4049-aeaa-050362d50709',
  },
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'port_protocol': 6,
        'type': 'DESTINATION_PORT',
        'value': '53',
      },
      {
        'op': '==',
        'type': 'SOURCE_INTERFACE_TYPE',
        'value': 2,
      },
    ],
    'description': 'Accept DNS on LANs (TCP/53)',
    'enabled': true,
    'ruleId': '303a9693-868a-4a74-b01d-db21f5d3e70c',
  },
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'port_protocol': 17,
        'type': 'DESTINATION_PORT',
        'value': '53',
      },
      {
        'op': '==',
        'type': 'SOURCE_INTERFACE_TYPE',
        'value': 2,
      },
    ],
    'description': 'Accept DNS on LANs (UDP/53)',
    'enabled': true,
    'ruleId': 'db3f20b9-dea6-463b-8796-5f78723a4b0f',
  },
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'type': 'IP_PROTOCOL',
        'value': '1',
      },
    ],
    'description': 'Accept ICMP',
    'enabled': true,
    'ruleId': '3b4521e8-fd2a-44df-a411-9b3b0c49a588',
  },
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'type': 'IP_PROTOCOL',
        'value': '58',
      },
    ],
    'description': 'Accept ICMPv6',
    'enabled': true,
    'ruleId': 'eb1f0240-059a-42b9-9124-fbd9d32919a0',
  },
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'port_protocol': 17,
        'type': 'DESTINATION_PORT',
        'value': '67',
      },
      {
        'op': '==',
        'type': 'SOURCE_INTERFACE_TYPE',
        'value': 2,
      },
    ],
    'description': 'Accept DHCP on LANs (UDP/67)',
    'enabled': true,
    'ruleId': '9d320d93-c656-4c45-b1ac-216a1b4f1a66',
  },
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'port_protocol': 17,
        'type': 'DESTINATION_PORT',
        'value': '547',
      },
      {
        'op': '==',
        'type': 'SOURCE_INTERFACE_TYPE',
        'value': 2,
      },
    ],
    'description': 'Accept DHCPv6 on LANs (UDP/547)',
    'enabled': true,
    'ruleId': '1ed7a68a-da9c-4b81-bc34-7585d498e174',
  },
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'port_protocol': 17,
        'type': 'DESTINATION_PORT',
        'value': '546',
      },
    ],
    'description': 'Accept DHCPv6 Replies (UDP/546)',
    'enabled': true,
    'ruleId': '0d9d065f-547f-4ed7-9fc3-9f12081cebbe',
  },
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'port_protocol': 6,
        'type': 'DESTINATION_PORT',
        'value': '8485',
      },
      {
        'op': '==',
        'type': 'SOURCE_INTERFACE_TYPE',
        'value': 2,
      },
    ],
    'description': 'Accept HTTP 8485 threat prevention on LANs (TCP/8485)',
    'enabled': false,
    'ruleId': '8e97a6fe-f00f-44f4-8fd5-06bd7d59636a',
  },
  {
    'action': {
      'type': 'ACCEPT',
    },
    'conditions': [
      {
        'op': '==',
        'port_protocol': 6,
        'type': 'DESTINATION_PORT',
        'value': '8486',
      },
      {
        'op': '==',
        'type': 'SOURCE_INTERFACE_TYPE',
        'value': 2,
      },
    ],
    'description': 'Accept HTTPS 8486 threat prevention on LANs (TCP/8486)',
    'enabled': false,
    'ruleId': 'bc72d0af-ae8d-465f-ba1b-0494ebdc4f28',
  },
  {
    'action': {
      'type': 'DROP',
    },
    'conditions': [],
    'description': 'Drop All',
    'enabled': true,
    'ruleId': 'd8fd0110-fd8e-456c-828b-0a7e64933881',
  },
]

/**
 * Default wan rules
 */
export const wanDefaultRules = [
  {
    'action': {
      'policy': '2cde882b-1ee5-20d6-079f-a70b9d4b2d04',
      'type': 'WAN_POLICY',
    },
    'conditions': [],
    'description': 'Send all traffic to wan policy 1',
    'enabled': true,
    'ruleId': '9c9b22c1-3eb7-4218-ac46-de5d2eb4dc18',
  },
]

/**
 * Default shaping rules
 */
export const shapingDefaultRules = [
  {
    'action': {
      'priority': 20,
      'return_action': true,
      'type': 'SET_PRIORITY',
    },
    'conditions': [
      { 'op': '==', 'type': 'IP_PROTOCOL', 'value': '1' },
      { 'op': '<', 'rate_unit': 'PACKETS_PER_SECOND', 'type': 'LIMIT_RATE', 'value': '100' },
      { 'burst_unit': 'PACKETS', 'op': '==', 'type': 'BURST_SIZE', 'value': '1000' },
    ],
    'description': 'Rate limit ICMP traffic',
    'enabled': false,
    'ruleId': '51295b4d-7747-4da2-b655-3ece6dd4e237',
  },
  {
    'action': {
      'priority': 20,
      'type': 'SET_PRIORITY',
    },
    'conditions': [],
    'description': 'Default priority',
    'enabled': true,
    'ruleId': '5c83caa4-b349-477c-934a-e685b7d9ba2e',
  },
  {
    'action': { 'priority': 1, 'type': 'SET_PRIORITY' },
    'conditions': [
      { 'op': '==', 'type': 'IP_PROTOCOL', 'value': '6' },
      { 'op': '==', 'type': 'SERVER_PORT', 'value': '4569' },
    ],
    'description': 'VoIP (IAX) Traffic',
    'enabled': false,
    'ruleId': '4622cc97-50a8-464d-a5cc-3eccb43a9dee',
  },
  {
    'action': { 'priority': 1, 'type': 'SET_PRIORITY' },
    'conditions': [
      { 'op': '==', 'type': 'IP_PROTOCOL', 'value': '6' },
      { 'op': '==', 'type': 'SERVER_PORT', 'value': '4569' },
    ],
    'description': 'VoIP (IAX) Traffic',
    'enabled': false,
    'ruleId': '0f9655bd-bd19-4e2c-9636-c78ce2551aca',
  },
  {
    'action': { 'priority': 1, 'type': 'SET_PRIORITY' },
    'conditions': [{ 'op': '==', 'type': 'IP_PROTOCOL', 'value': '1' }],
    'description': 'Ping Priority',
    'enabled': true,
    'ruleId': 'fd112e79-12cd-4ba6-9815-8c8ce80608a2',
  },
  {
    'action': { 'priority': 1, 'type': 'SET_PRIORITY' },
    'conditions': [
      { 'op': '==', 'type': 'IP_PROTOCOL', 'value': '17' },
      { 'op': '==', 'type': 'SERVER_PORT', 'value': '53' },
    ],
    'description': 'DNS Priority',
    'enabled': true,
    'ruleId': '66446555-2b15-4faf-8996-f4245045bba3',
  },
  {
    'action': { 'priority': 16, 'type': 'SET_PRIORITY' },
    'conditions': [
      { 'op': '==', 'type': 'IP_PROTOCOL', 'value': '6' },
      { 'op': '==', 'type': 'SERVER_PORT', 'value': '22' },
    ],
    'description': 'SSH Priority',
    'enabled': true,
    'ruleId': 'dbdcd748-f6f2-4cae-83cc-7680590b89e9',
  },
  {
    'action': { 'priority': 20, 'type': 'SET_PRIORITY' },
    'conditions': [
      { 'op': '==', 'type': 'IP_PROTOCOL', 'value': '6' },
      { 'op': '==', 'type': 'SERVER_PORT', 'value': '1194' },
    ],
    'description': 'Openvpn Priority',
    'enabled': true,
    'ruleId': 'f696d32a-4b90-42bf-9e4b-62241a6d2031',
  },
]
