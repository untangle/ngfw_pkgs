const booleanValues = { 'True': 'True', 'False': 'False' }
const booleanValueOptions = Object.entries(booleanValues).map(([k, v]) => ({ text: v, value: k }))

const invert = { true: 'is_not', false: 'is' }
const invertOptions = Object.entries(invert).map(([k, v]) => ({ text: v, value: k }))

const numeric = {
  '=': 'equals',
  '!=': 'not_equals',
  '>': 'greater_than',
  '<': 'less_than',
  '>=': 'greater_or_equal',
  '<=': 'less_or_equal',
}
const numericOptions = Object.entries(numeric).map(([k, v]) => ({ text: v, value: k }))

const textOperators = {
  '=': 'equals',
  '!=': 'not_equals',
  'substr': 'Contains',
  '!substr': 'Does not contain',
}
const textOperatorOptions = Object.entries(textOperators).map(([k, v]) => ({ text: v, value: k }))

const booleanOperators = { '=': 'is', '!=': 'is_not' }
const booleanOperatorOptions = Object.entries(booleanOperators).map(([k, v]) => ({ text: v, value: k }))

const appDescription = {
  'web-filter': 'app_web_filter_description',
  'web-monitor': 'app_web_monitor_description',
  'virus-blocker': 'app_virus_blocker_description',
  'virus-blocker-lite': 'app_virus_blocker_lite_description',
  'spam-blocker': 'app_spam_blocker_description',
  'spam-blocker-lite': 'app_spam_blocker_lite_description',
  'phish-blocker': 'app_phish_blocker_description',
  'web-cache': 'app_web_cache_description',
  'bandwidth-control': 'app_bandwidth_control_description',
  'ssl-inspector': 'app_ssl_inspector_description',
  'application-control': 'app_application_control_description',
  'application-control-lite': 'app_application_control_lite_description',
  'captive-portal': 'app_captive_portal_description',
  'firewall': 'app_firewall_description',
  'threat-prevention': 'app_threat_prevention_description',
  'ad-blocker': 'app_ad_blocker_description',
}

/**
 * IANA protocol number → display name map.
 * Format mirrors ExtJS Renderer.protocolsMap: "TCP [6]"
 * Used to resolve raw protocol numbers returned by PIE_GRAPH reports
 * where pieGroupColumn === 'protocol'. Resolution stays client-side because
 * this is static data already available in the browser — no backend round-trip needed.
 */
const PROTOCOL_NAME_MAP = {
  0: 'HOPOPT [0]',
  1: 'ICMP [1]',
  2: 'IGMP [2]',
  3: 'GGP [3]',
  4: 'IPv4 [4]',
  5: 'ST [5]',
  6: 'TCP [6]',
  7: 'CBT [7]',
  8: 'EGP [8]',
  9: 'IGP [9]',
  10: 'BBN-RCC-MON [10]',
  11: 'NVP-II [11]',
  12: 'PUP [12]',
  17: 'UDP [17]',
  27: 'RDP [27]',
  33: 'DCCP [33]',
  41: 'IPv6 [41]',
  43: 'IPv6-Route [43]',
  44: 'IPv6-Frag [44]',
  46: 'RSVP [46]',
  47: 'GRE [47]',
  50: 'ESP [50]',
  51: 'AH [51]',
  58: 'IPv6-ICMP [58]',
  59: 'IPv6-NoNxt [59]',
  60: 'IPv6-Opts [60]',
  88: 'EIGRP [88]',
  89: 'OSPFIGP [89]',
  94: 'IPIP [94]',
  103: 'PIM [103]',
  108: 'IPComp [108]',
  112: 'VRRP [112]',
  115: 'L2TP [115]',
  132: 'SCTP [132]',
  133: 'FC [133]',
  135: 'Mobility Header [135]',
  136: 'UDPLite [136]',
  137: 'MPLS-in-IP [137]',
  139: 'HIP [139]',
  140: 'Shim6 [140]',
  253: 'Use for experimentation [253]',
  254: 'Use for experimentation [254]',
  255: 'Reserved [255]',
}

export {
  booleanValueOptions,
  invertOptions,
  numericOptions,
  textOperatorOptions,
  booleanOperatorOptions,
  appDescription,
  PROTOCOL_NAME_MAP,
}
