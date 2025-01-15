const CONFIG_TYPE = {
  DHCP: 'DHCP', // v4, v6 - WAN
  STATIC: 'STATIC', // v4, v6 - both WAN/non-WAN
  PPPOE: 'PPPOE', // v4 - WAN
  SLAAC: 'SLAAC', // v6 - WAN
  ASSIGN: 'ASSIGN', // v6 - non-WAN
  DISABLED: 'DISABLED', // v6 - both WAN/non-WAN
}

const MTU_VALUES = {
  DEFAULT: 1500,
  MIN: 68,
  MAX: 65535,
}

export { CONFIG_TYPE, MTU_VALUES }
