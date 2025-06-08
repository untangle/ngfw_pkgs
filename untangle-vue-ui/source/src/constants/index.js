/**
 * Possible address types values used for `SOURCE_ADDRESS_TYPE`, `DESTINATION_ADDRESS_TYPE` conditions
 */
const addressTypes = {
  unspec: 'unspec',
  unicast: 'unicast',
  local: 'local',
  broadcast: 'broadcast',
  anycast: 'anycast',
  multi: 'multicast',
  blackhole: 'blackhole',
  unreachable: 'unreachable',
  prohibit: 'prohibit',
}

/**
 * ISO-3166 alpha2 country codes as listed on http://www.geonames.org/countries/
 * used in all country selectors, lists etc
 */
const countryCodes = {
  'AD': 'Andorra',
  'AE': 'United Arab Emirates',
  'AF': 'Afghanistan',
  'AG': 'Antigua and Barbuda',
  'AI': 'Anguilla',
  'AL': 'Albania',
  'AM': 'Armenia',
  'AO': 'Angola',
  'AQ': 'Antarctica',
  'AR': 'Argentina',
  'AS': 'American Samoa',
  'AT': 'Austria',
  'AU': 'Australia',
  'AW': 'Aruba',
  'AX': 'Åland',
  'AZ': 'Azerbaijan',
  'BA': 'Bosnia and Herzegovina',
  'BB': 'Barbados',
  'BD': 'Bangladesh',
  'BE': 'Belgium',
  'BF': 'Burkina Faso',
  'BG': 'Bulgaria',
  'BH': 'Bahrain',
  'BI': 'Burundi',
  'BJ': 'Benin',
  'BL': 'Saint Barthélemy',
  'BM': 'Bermuda',
  'BN': 'Brunei',
  'BO': 'Bolivia',
  'BQ': 'Bonaire, Sint Eustatius, and Saba',
  'BR': 'Brazil',
  'BS': 'Bahamas',
  'BT': 'Bhutan',
  'BV': 'Bouvet Island',
  'BW': 'Botswana',
  'BY': 'Belarus',
  'BZ': 'Belize',
  'CA': 'Canada',
  'CC': 'Cocos (Keeling) Islands',
  'CD': 'DR Congo',
  'CF': 'Central African Republic',
  'CG': 'Congo Republic',
  'CH': 'Switzerland',
  'CI': 'Ivory Coast',
  'CK': 'Cook Islands',
  'CL': 'Chile',
  'CM': 'Cameroon',
  'CN': 'China',
  'CO': 'Colombia',
  'CR': 'Costa Rica',
  'CU': 'Cuba',
  'CV': 'Cabo Verde',
  'CW': 'Curaçao',
  'CX': 'Christmas Island',
  'CY': 'Cyprus',
  'CZ': 'Czechia',
  'DE': 'Germany',
  'DJ': 'Djibouti',
  'DK': 'Denmark',
  'DM': 'Dominica',
  'DO': 'Dominican Republic',
  'DZ': 'Algeria',
  'EC': 'Ecuador',
  'EE': 'Estonia',
  'EG': 'Egypt',
  'EH': 'Western Sahara',
  'ER': 'Eritrea',
  'ES': 'Spain',
  'ET': 'Ethiopia',
  'FI': 'Finland',
  'FJ': 'Fiji',
  'FK': 'Falkland Islands',
  'FM': 'Micronesia',
  'FO': 'Faroe Islands',
  'FR': 'France',
  'GA': 'Gabon',
  'GB': 'United Kingdom',
  'GD': 'Grenada',
  'GE': 'Georgia',
  'GF': 'French Guiana',
  'GG': 'Guernsey',
  'GH': 'Ghana',
  'GI': 'Gibraltar',
  'GL': 'Greenland',
  'GM': 'The Gambia',
  'GN': 'Guinea',
  'GP': 'Guadeloupe',
  'GQ': 'Equatorial Guinea',
  'GR': 'Greece',
  'GS': 'South Georgia and South Sandwich Islands',
  'GT': 'Guatemala',
  'GU': 'Guam',
  'GW': 'Guinea-Bissau',
  'GY': 'Guyana',
  'HK': 'Hong Kong',
  'HM': 'Heard and McDonald Islands',
  'HN': 'Honduras',
  'HR': 'Croatia',
  'HT': 'Haiti',
  'HU': 'Hungary',
  'ID': 'Indonesia',
  'IE': 'Ireland',
  'IL': 'Israel',
  'IM': 'Isle of Man',
  'IN': 'India',
  'IO': 'British Indian Ocean Territory',
  'IQ': 'Iraq',
  'IR': 'Iran',
  'IS': 'Iceland',
  'IT': 'Italy',
  'JE': 'Jersey',
  'JM': 'Jamaica',
  'JO': 'Jordan',
  'JP': 'Japan',
  'KE': 'Kenya',
  'KG': 'Kyrgyzstan',
  'KH': 'Cambodia',
  'KI': 'Kiribati',
  'KM': 'Comoros',
  'KN': 'St Kitts and Nevis',
  'KP': 'North Korea',
  'KR': 'South Korea',
  'KW': 'Kuwait',
  'KY': 'Cayman Islands',
  'KZ': 'Kazakhstan',
  'LA': 'Laos',
  'LB': 'Lebanon',
  'LC': 'Saint Lucia',
  'LI': 'Liechtenstein',
  'LK': 'Sri Lanka',
  'LR': 'Liberia',
  'LS': 'Lesotho',
  'LT': 'Lithuania',
  'LU': 'Luxembourg',
  'LV': 'Latvia',
  'LY': 'Libya',
  'MA': 'Morocco',
  'MC': 'Monaco',
  'MD': 'Moldova',
  'ME': 'Montenegro',
  'MF': 'Saint Martin',
  'MG': 'Madagascar',
  'MH': 'Marshall Islands',
  'MK': 'North Macedonia',
  'ML': 'Mali',
  'MM': 'Myanmar',
  'MN': 'Mongolia',
  'MO': 'Macao',
  'MP': 'Northern Mariana Islands',
  'MQ': 'Martinique',
  'MR': 'Mauritania',
  'MS': 'Montserrat',
  'MT': 'Malta',
  'MU': 'Mauritius',
  'MV': 'Maldives',
  'MW': 'Malawi',
  'MX': 'Mexico',
  'MY': 'Malaysia',
  'MZ': 'Mozambique',
  'NA': 'Namibia',
  'NC': 'New Caledonia',
  'NE': 'Niger',
  'NF': 'Norfolk Island',
  'NG': 'Nigeria',
  'NI': 'Nicaragua',
  'NL': 'Netherlands',
  'NO': 'Norway',
  'NP': 'Nepal',
  'NR': 'Nauru',
  'NU': 'Niue',
  'NZ': 'New Zealand',
  'OM': 'Oman',
  'PA': 'Panama',
  'PE': 'Peru',
  'PF': 'French Polynesia',
  'PG': 'Papua New Guinea',
  'PH': 'Philippines',
  'PK': 'Pakistan',
  'PL': 'Poland',
  'PM': 'Saint Pierre and Miquelon',
  'PN': 'Pitcairn Islands',
  'PR': 'Puerto Rico',
  'PS': 'Palestine',
  'PT': 'Portugal',
  'PW': 'Palau',
  'PY': 'Paraguay',
  'QA': 'Qatar',
  'RE': 'Réunion',
  'RO': 'Romania',
  'RS': 'Serbia',
  'RU': 'Russia',
  'RW': 'Rwanda',
  'SA': 'Saudi Arabia',
  'SB': 'Solomon Islands',
  'SC': 'Seychelles',
  'SD': 'Sudan',
  'SE': 'Sweden',
  'SG': 'Singapore',
  'SH': 'Saint Helena',
  'SI': 'Slovenia',
  'SJ': 'Svalbard and Jan Mayen',
  'SK': 'Slovakia',
  'SL': 'Sierra Leone',
  'SM': 'San Marino',
  'SN': 'Senegal',
  'SO': 'Somalia',
  'SR': 'Suriname',
  'SS': 'South Sudan',
  'ST': 'São Tomé and Príncipe',
  'SV': 'El Salvador',
  'SX': 'Sint Maarten',
  'SY': 'Syria',
  'SZ': 'Eswatini',
  'TC': 'Turks and Caicos Islands',
  'TD': 'Chad',
  'TF': 'French Southern Territories',
  'TG': 'Togo',
  'TH': 'Thailand',
  'TJ': 'Tajikistan',
  'TK': 'Tokelau',
  'TL': 'Timor-Leste',
  'TM': 'Turkmenistan',
  'TN': 'Tunisia',
  'TO': 'Tonga',
  'TR': 'Turkey',
  'TT': 'Trinidad and Tobago',
  'TV': 'Tuvalu',
  'TW': 'Taiwan',
  'TZ': 'Tanzania',
  'UA': 'Ukraine',
  'UG': 'Uganda',
  'UM': 'U.S. Outlying Islands',
  'US': 'United States',
  'UY': 'Uruguay',
  'UZ': 'Uzbekistan',
  'VA': 'Vatican City',
  'VC': 'St Vincent and Grenadines',
  'VE': 'Venezuela',
  'VG': 'British Virgin Islands',
  'VI': 'U.S. Virgin Islands',
  'VN': 'Vietnam',
  'VU': 'Vanuatu',
  'WF': 'Wallis and Futuna',
  'WS': 'Samoa',
  'XK': 'Kosovo',
  'YE': 'Yemen',
  'YT': 'Mayotte',
  'ZA': 'South Africa',
  'ZM': 'Zambia',
  'ZW': 'Zimbabwe',
  'XL': 'Local',
  'XU': 'Unknown',
}

/**
 * IP family used in renderers
 */
const families = {
  2: 'IPv4',
  10: 'IPv6',
}

/**
 * Threat Prevention lookup incoming threat levels
 */
const incomingThreatLevels = {
  1: 'high_risk',
  20: 'suspicious',
  40: 'moderate_risk',
  60: 'low_risk',
  80: 'trustworthy',
}

/**
 * Interface Types used for rendering & options
 */
const interfaceTypes = {
  '0': 'unset',
  '1': 'wan',
  '2': 'lan',
  '3': 'management',
}

/**
 * Interface Zones used in Policy Manager Objects
 */
const interfaceZones = [
  'WAN',
  'LAN',
  'LTE',
  'WIREGUARD',
  'IPSEC',
  'VLAN',
  'LAN1',
  'LAN2',
  'WAN0',
  'WAN1',
  'WAN2',
  'WAN3',
  'WAN4',
  'WAN5',
  'WAN6',
  'WAN7',
  'WAN8',
  'WAN9',
  'WAN10',
  'WAN11',
  'WAN12',
  'WAN13',
  'WAN14',
  'WAN15',
  'WAN16',
  'WAN17',
]

/**
 * Limit rate burst units used for Shaping Limit Rate conditions
 */
const limitBurstUnits = {
  'PACKETS': 'packets',
  'BYTES': 'bytes',
  'KBYTES': 'kbytes',
  'MBYTES': 'mbytes',
}

/**
 * Rule actions upon exceeding
 * used for `LIMIT_EXCEED_ACTION` actions & renderers
 */
const limitExceedActions = {
  ACCEPT: 'action_accept',
  DROP: 'action_drop',
  REJECT: 'action_reject',
  PRIORITY: 'action_priority',
}

/**
 * Limit rate units used for `LIMIT_RATE` conditions renderers & selectors
 */
const limitRateUnits = {
  'PACKETS_PER_SECOND': 'packets_per_second',
  'PACKETS_PER_MINUTE': 'packets_per_minute',
  'PACKETS_PER_HOUR': 'packets_per_hour',
  'PACKETS_PER_DAY': 'packets_per_day',
  'PACKETS_PER_WEEK': 'packets_per_week',
  'BYTES_PER_SECOND': 'bytes_per_second',
  'KBYTES_PER_SECOND': 'kbytes_per_second',
  'MBYTES_PER_SECOND': 'mbytes_per_second',
}

/**
 * Threat Prevention outgoing threat levels used for rendering
 */
const outgoingThreatLevels = {
  0: 'trustworthy',
  1: 'high_risk',
}

/**
 * Protocols used only for CLIENT_PORT & SERVER_PORT conditions
 */
const portProtocols = {
  'TCP': 'TCP',
  'UDP': 'UDP',
  'ICMP': 'ICMP',
  'GRE': 'GRE',
  'ESP': 'ESP',
  'AH': 'AH',
  'SCTP': 'SCTP',
  'OSPF': 'OSPF',
}

// Denial of service protocols
const dosProtocol = {
  '0': 'ALL',
  '1': 'TCP',
  '2': 'UDP',
  '3': 'ICMP',
}

/**
 * Priorities used for `SET_PRIORITY` actions for Shaping Rules renderers & selectors
 */
const priorities = {
  '1': 'highest_priority',
  '2': 'network_control',
  '3': 'telephony',
  '4': 'signaling',
  '5': 'multimedia_conferencing_af43',
  '6': 'multimedia_conferencing_af42',
  '7': 'multimedia_conferencing_af41',
  '8': 'real_time_interactive',
  '9': 'multimedia_streaming_af33',
  '10': 'multimedia_streaming_af32',
  '11': 'multimedia_streaming_af31',
  '12': 'broadcast_video',
  '13': 'low_latency_data_af23',
  '14': 'low_latency_data_af22',
  '15': 'low_latency_data_af21',
  '16': 'oam',
  '17': 'high_throughput_data_af13',
  '18': 'high_throughput_data_af12',
  '19': 'high_throughput_data_af11',
  '20': 'standard_priority',
  '21': 'lowest_priority',
}

/**
 * Productivity levels for Applications, used for rendering
 */
const productivityLevels = {
  '1': 'level_very_low',
  '2': 'level_low',
  '3': 'level_medium',
  '4': 'level_high',
  '5': 'level_very_high',
}

/**
 * Protocols for IP_PROTOCOL condition used in renderers ans selectors
 */
const protocols = {
  '0': 'HOPOPT',
  '1': 'ICMP',
  '2': 'IGMP',
  '3': 'GGP',
  '4': 'IP-in-IP',
  '5': 'ST',
  '6': 'TCP',
  '7': 'CBT',
  '8': 'EGP',
  '9': 'IGP',
  '10': 'BBN-RCC-MON',
  '11': 'NVP-II',
  '12': 'PUP',
  '13': 'ARGUS',
  '14': 'EMCON',
  '15': 'XNET',
  '16': 'CHAOS',
  '17': 'UDP',
  '18': 'MUX',
  '19': 'DCN-MEAS',
  '20': 'HMP',
  '21': 'PRM',
  '22': 'XNS-IDP',
  '23': 'TRUNK-1',
  '24': 'TRUNK-2',
  '25': 'LEAF-1',
  '26': 'LEAF-2',
  '27': 'RDP',
  '28': 'IRTP',
  '29': 'ISO-TP4',
  '30': 'NETBLT',
  '31': 'MFE-NSP',
  '32': 'MERIT-INP',
  '33': 'DCCP',
  '34': '3PC',
  '35': 'IDPR',
  '36': 'XTP',
  '37': 'DDP',
  '38': 'IDPR-CMTP',
  '39': 'TP++',
  '40': 'IL',
  '41': 'IPv6',
  '42': 'SDRP',
  '43': 'IPv6-Route',
  '44': 'IPv6-Frag',
  '45': 'IDRP',
  '46': 'RSVP',
  '47': 'GRE',
  '48': 'MHRP',
  '49': 'BNA',
  '50': 'ESP',
  '51': 'AH',
  '52': 'I-NLSP',
  '53': 'SWIPE',
  '54': 'NARP',
  '55': 'MOBILE',
  '56': 'TLSP',
  '57': 'SKIP',
  '58': 'IPv6-ICMP',
  '59': 'IPv6-NoNxt',
  '60': 'IPv6-Opts',
  '62': 'CFTP',
  '64': 'SAT-EXPAK',
  '65': 'KRYPTOLAN',
  '66': 'RVD',
  '67': 'IPPC',
  '69': 'SAT-MON',
  '70': 'VISA',
  '71': 'IPCU',
  '72': 'CPNX',
  '73': 'CPHB',
  '74': 'WSN',
  '75': 'PVP',
  '76': 'BR-SAT-MON',
  '77': 'SUN-ND',
  '78': 'WB-MON',
  '79': 'WB-EXPAK',
  '80': 'ISO-IP',
  '81': 'VMTP',
  '82': 'SECURE-VMTP',
  '83': 'VINES',
  '84': 'TTP',
  '85': 'NSFNET-IGP',
  '86': 'DGP',
  '87': 'TCF',
  '88': 'EIGRP',
  '89': 'OSPF',
  '90': 'Sprite-RPC',
  '91': 'LARP',
  '92': 'MTP',
  '93': 'AX.25',
  '94': 'IPIP',
  '95': 'MICP',
  '96': 'SCC-SP',
  '97': 'ETHERIP',
  '98': 'ENCAP',
  '100': 'GMTP',
  '101': 'IFMP',
  '102': 'PNNI',
  '103': 'PIM',
  '104': 'ARIS',
  '105': 'SCPS',
  '106': 'QNX',
  '107': 'A/N',
  '108': 'IPComp',
  '109': 'SNP',
  '110': 'Compaq-Peer',
  '111': 'IPX-in-IP',
  '112': 'VRRP',
  '113': 'PGM',
  '115': 'L2TP',
  '116': 'DDX',
  '117': 'IATP',
  '118': 'STP',
  '119': 'SRP',
  '120': 'UTI',
  '121': 'SMP',
  '122': 'SM',
  '123': 'PTP',
  '124': 'IS-IS',
  '125': 'FIRE',
  '126': 'CRTP',
  '127': 'CRUDP',
  '128': 'SSCOPMCE',
  '129': 'IPLT',
  '130': 'SPS',
  '131': 'PIPE',
  '132': 'SCTP',
  '133': 'FC',
  '134': 'RSVP-E2E-IGNORE',
  '135': 'Mobility',
  '136': 'UDPLite',
  '137': 'MPLS-in-IP',
  '138': 'manet',
  '139': 'HIP',
  '140': 'Shim6',
  '141': 'WESP',
  '142': 'ROHC',
}

/**
 * Risk levels for Applications, used for rendering
 */
const riskLevels = {
  '1': 'level_very_low',
  '2': 'level_low',
  '3': 'level_medium',
  '4': 'level_high',
  '5': 'level_very_high',
}

/**
 * This are conditions operators used in MFW local UI rules
 * for translation purposes in selectors
 */
const ruleOps = {
  '==': 'is',
  '!=': 'is_not',
  '>': 'greater_than',
  '<': 'less_than',
  '>=': 'greater_or_equal',
  '<=': 'less_or_equal',
}

/**
 * Days of Week as strings
 */
const daysOfWeek = {
  'sun': 'sunday',
  'mon': 'monday',
  'tue': 'tuesday',
  'wed': 'wednesday',
  'thu': 'thursday',
  'fri': 'friday',
  'sat': 'saturday',
}

const daysOfWeekOrder = {
  'sun': 0,
  'mon': 1,
  'tue': 2,
  'wed': 3,
  'thu': 4,
  'fri': 5,
  'sat': 6,
}

/**
 * Below are options wich are represented as arrays of { text, value } used on UI selectors
 * which some are generated from above defined constants
 */

const addressTypeOptions = Object.entries(addressTypes).map(([k, v]) => ({ text: v, value: k }))

const countryOptionsUnsorted = Object.entries(countryCodes).map(([k, v]) => ({ text: v, value: k }))
const countryOptions = countryOptionsUnsorted.sort((a, b) => {
  if (a.text < b.text) return -1
  if (a.text > b.text) return 1
  return 0
})

const connectionsStates = ['established', 'invalid', 'new', 'related']
const connectionStateOptions = connectionsStates.map(cs => ({ text: cs, value: cs }))

const interfaceTypeOptions = Object.entries(interfaceTypes).map(([k, v]) => ({ text: v, value: parseInt(k) }))
const interfaceTypeOptionsAsString = Object.entries(interfaceTypes).map(([k, v]) => ({ text: v, value: k }))

const limitRateOperators = { '>': 'greater_than', '<': 'less_than' }
const limitBurstOperators = { '==': 'equals' }

const limitRateOperatorOptions = Object.entries(limitRateOperators).map(([k, v]) => ({ text: v, value: k }))
const limitBurstUnitOptions = Object.entries(limitBurstUnits).map(([k, v]) => ({ text: v, value: k }))
const limitBurstOperatorOptions = Object.entries(limitBurstOperators).map(([k, v]) => ({ text: v, value: k }))
const limitExceedActionOptions = Object.entries(limitExceedActions).map(([k, v]) => ({ text: v, value: k }))
const limitRateUnitOptions = Object.entries(limitRateUnits).map(([k, v]) => ({ text: v, value: k }))

const portProtocolOptions = Object.entries(portProtocols).map(([k, v]) => ({ text: v, value: k }))
const portProtocolOptionsAsString = Object.entries(portProtocols).map(([k, v]) => ({ text: v, value: k }))

const priorityOptions = Object.entries(priorities).map(([k, v]) => ({ text: v, value: parseInt(k) }))
const priorityOptionsAsString = Object.entries(priorities).map(([k, v]) => ({ text: v, value: k }))

const productivityLevelOptions = Object.entries(productivityLevels).map(([k, v]) => ({ text: v, value: k }))

const protocolOptions = Object.entries(protocols)
  .map(([k, v]) => ({ text: v, value: k }))
  .sort((a, b) => {
    if (a.text < b.text) return -1
    if (a.text > b.text) return 1
    return 0
  })
const protocolOptionsAsString = Object.entries(protocols)
  .map(([k, v]) => ({ text: v, value: k }))
  .sort((a, b) => {
    if (a.text < b.text) return -1
    if (a.text > b.text) return 1
    return 0
  })

const riskLevelOptions = Object.entries(riskLevels).map(([k, v]) => ({ text: v, value: k }))

const daysOfWeekOptions = Object.entries(daysOfWeek).map(([k, v]) => ({ text: v, value: k }))

const isOperators = { '==': 'is', '!=': 'is_not' }
const allOperators = {
  '==': 'equals',
  '!=': 'not_equals',
  '>': 'greater_than',
  '<': 'less_than',
  '>=': 'greater_or_equal',
  '<=': 'less_or_equal',
}
// op => invert
const opToInvert = {
  '==': false,
  '!=': true,
}
// invert => op (reverse map)
const invertToOp = Object.entries(opToInvert).reduce((acc, [op, invert]) => {
  acc[invert] = op
  return acc
}, {})
const isOperatorOptions = Object.entries(isOperators).map(([k, v]) => ({ text: v, value: k }))
const onlyIsOperatorOptions = isOperatorOptions.filter(({ value }) => value === '==')
const allOperatorOptions = Object.entries(allOperators).map(([k, v]) => ({ text: v, value: k }))

export {
  addressTypes,
  countryCodes,
  families,
  incomingThreatLevels,
  interfaceTypes,
  interfaceZones,
  limitBurstUnits,
  limitExceedActions,
  limitRateUnits,
  outgoingThreatLevels,
  portProtocols,
  priorities,
  productivityLevels,
  protocols,
  riskLevels,
  ruleOps,
  daysOfWeek,
  daysOfWeekOrder,
  dosProtocol,

  // options used in selects
  addressTypeOptions,
  connectionStateOptions,
  countryOptions,
  interfaceTypeOptions,
  interfaceTypeOptionsAsString,
  limitExceedActionOptions,
  limitRateOperatorOptions,
  limitRateUnitOptions,
  limitBurstOperatorOptions,
  limitBurstUnitOptions,
  portProtocolOptions,
  portProtocolOptionsAsString,
  priorityOptions,
  priorityOptionsAsString,
  productivityLevelOptions,
  protocolOptions,
  protocolOptionsAsString,
  riskLevelOptions,
  daysOfWeekOptions,

  // mfw local ui conditions operators
  isOperatorOptions,
  allOperatorOptions,
  onlyIsOperatorOptions,
  opToInvert,
  invertToOp,
}
