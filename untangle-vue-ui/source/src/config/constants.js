/**
 * Types used as the single source of truth for any mappings
 * They are used in both
 *  - mongo data
 *  - into final Policy Manager that gets pushed to appliances
 *
 * Naming conventions to avoid clashing
 * - templates are prefixed with `mfw-template`
 * - rules are prefixed with `mfw-rule`
 * - objects are prefixed with `mfw-object`
 * - object groups are prefixed with `mfw-object`, and suffixed by `-group`
 *
 * The extra identifier bit after prefix won't have `-` in naming and will be all lowercased
 * e.g. Threat Prevention => `threatprevention`,
 *      Port Forward => `-portforward`
 *      Interface Zone => `-interfacezone`
 */

const Type = Object.freeze({
  Profile: 'mfw-profile',
  Policy: 'mfw-policy',

  ConfigGeoipFilter: 'mfw-config-geoipfilter',
  ConfigWebFilter: 'mfw-config-webfilter',
  ConfigThreatPrevention: 'mfw-config-threatprevention',
  ConfigWanPolicy: 'mfw-config-wanpolicy',
  ConfigApplicationControl: 'mfw-config-applicationcontrol',
  ConfigCaptivePortal: 'mfw-config-captiveportal',

  ConfigGlobalDns: 'mfw-config-global-dns',
  ConfigGlobalStatusAnalyzers: 'mfw-config-global-statusanalyzers',
  ConfigGlobalUpgrade: 'mfw-config-global-upgrade',
  ConfigGlobalDynamicBlocklist: 'mfw-config-global-dynamic-blocklist',
  ConfigGlobalStaticRoutes: 'mfw-config-global-static-routes',
  ConfigGlobalNetworkDiscovery: 'mfw-config-global-networkdiscovery',
  ConfigGlobalDenialOfService: 'mfw-config-global-denialofservice',
  ConfigGlobalDatabase: 'mfw-config-global-database',
  ConfigGlobalBypass: 'mfw-config-global-bypass',

  // rule types used only in Policy Manager prefixed with `mfw-rule-`
  RuleSecurity: 'mfw-rule-security', // aka `filter rule`
  RulePortForward: 'mfw-rule-portforward',
  RuleNat: 'mfw-rule-nat',
  RuleShaping: 'mfw-rule-shaping',
  RuleAccess: 'mfw-rule-access',
  RuleApplicationControl: 'mfw-rule-applicationcontrol',
  RuleGeoipFilter: 'mfw-rule-geoipfilter',
  RuleWebFilter: 'mfw-rule-webfilter',
  RuleThreatPrevention: 'mfw-rule-threatprevention',
  RuleNetworkDiscovery: 'mfw-rule-networkdiscovery',
  RuleWanPolicy: 'mfw-rule-wanpolicy',
  RuleDns: 'mfw-rule-dns',
  RuleCaptivePortal: 'mfw-rule-captiveportal',

  // objects and object groups are prefixed only with `mfw-object-`
  ObjectCondition: 'mfw-object-condition',
  ObjectConditionGroup: 'mfw-object-condition-group',
  ObjectIpAddress: 'mfw-object-ipaddress',
  ObjectIpAddressGroup: 'mfw-object-ipaddress-group',
  ObjectInterfaceZone: 'mfw-object-interfacezone',
  ObjectInterfaceZoneGroup: 'mfw-object-interfacezone-group',
  ObjectGeoip: 'mfw-object-geoip',
  ObjectGeoipGroup: 'mfw-object-geoip-group',
  ObjectService: 'mfw-object-service',
  ObjectServiceGroup: 'mfw-object-service-group',
  ObjectHostname: 'mfw-object-hostname',
  ObjectHostnameGroup: 'mfw-object-hostname-group',
  ObjectUser: 'mfw-object-user',
  ObjectUserGroup: 'mfw-object-user-group',
  ObjectUno: 'mfw-object-uno',
  ObjectUnoGroup: 'mfw-object-uno-group',
  ObjectAgni: 'mfw-object-agni',
  ObjectAgniGroup: 'mfw-object-agni-group',
  ObjectVlanTag: 'mfw-object-vlantag',
  ObjectVlanTagGroup: 'mfw-object-vlantag-group',
  ObjectApplication: 'mfw-object-application',
  ObjectApplicationGroup: 'mfw-object-application-group',
  ObjectApplicationControlList: 'mfw-object-application-control-list',
  ObjectApplicationControlListGroup: 'mfw-object-application-control-list-group',
  ObjectVrfName: 'mfw-object-vrfname',
  ObjectVrfNameGroup: 'mfw-object-vrfname-group',
})

/**
 * the action types used for the rules, matching the expected values on mfw box (schema)
 */
const ActionType = Object.freeze({
  // for security/access rules
  Accept: 'ACCEPT',
  Drop: 'DROP',
  Reject: 'REJECT',
  WanPolicy: 'WAN_POLICY', // for wan-rules
  DestinationAddress: 'DNAT', // for port-forward
  Priority: 'SET_PRIORITY', // for shaping
  Masquerade: 'MASQUERADE', // for nat
  SourceAddress: 'SNAT', // for nat too
  LimitExceed: 'LIMIT_EXCEED_ACTION', // for shaping
  Return: 'RETURN', // for shaping
  Bypass: 'BYPASS', // for bypass rules

  // this is newly introduced for policy types configurations
  Configuration: 'SET_CONFIGURATION',
})

const SyncStatus = Object.freeze({
  Synced: 'synced',
  Syncing: 'syncing',
  NotSynced: 'not_synced',
  Unassigning: 'unassigning',
})

const ConditionType = Object.freeze({
  Application: 'APPLICATION',

  ApplicationName: 'APPLICATION_NAME',
  // ApplicationNameInferred: 'APPLICATION_NAME_INFERRED',
  ApplicationCategory: 'APPLICATION_CATEGORY',
  // ApplicationCategoryInferred: 'APPLICATION_CATEGORY_INFERRED',
  // ApplicationProductivity: 'APPLICATION_PRODUCTIVITY',
  // ApplicationProductivityInferred: 'APPLICATION_PRODUCTIVITY_INFERRED',
  // ApplicationRisk: 'APPLICATION_RISK',
  // ApplicationRiskInferred: 'APPLICATION_RISK_INFERRED',

  ClientAddress: 'CLIENT_ADDRESS',
  ClientApplication: 'CLIENT_APPLICATION',
  ClientDnsHint: 'CLIENT_DNS_HINT',
  ClientGeoIp: 'CLIENT_GEOIP',
  ClientInterfaceType: 'CLIENT_INTERFACE_TYPE',
  ClientPort: 'CLIENT_PORT',
  ClientService: 'CLIENT_SERVICE',

  ServerAddress: 'SERVER_ADDRESS',
  ServerApplication: 'SERVER_APPLICATION',
  ServerDnsHint: 'SERVER_DNS_HINT',
  ServerGeoIp: 'SERVER_GEOIP',
  ServerInterfaceType: 'SERVER_INTERFACE_TYPE',
  ServerPort: 'SERVER_PORT',
  ServerService: 'SERVER_SERVICE',

  // CD-4836: hide Address Type for now
  // SourceAddressType: 'SOURCE_ADDRESS_TYPE',
  SourceInterface: 'SOURCE_INTERFACE',

  // CD-4836: hide Address Type for now
  // DestinationAddressType: 'DESTINATION_ADDRESS_TYPE',
  DestinationInterface: 'DESTINATION_INTERFACE',

  // temporarily removed these conditions part of CD-4814
  /*
  UnoApplicationName: 'UNO_APPLICATION_NAME',
  UnoServiceName: 'UNO_SERVICE_NAME',
  UnoHostname: 'UNO_HOSTNAME',

  AgniUserId: 'AGNI_USER_ID',
  AgniUserGroup: 'AGNI_USER_GROUP',
  */

  IpProtocol: 'IP_PROTOCOL',
  // CD-4834: hide Limit Rate for now
  // LimitRate: 'LIMIT_RATE',

  // new conditions
  // CD-4833: hide Hostname for now
  // Hostname: 'HOSTNAME',
  User: 'USER',
  Service: 'SERVICE',
  VlanTag: 'VLAN_TAG',
  VrfName: 'VRF_NAME',
  DayOfWeek: 'DAY_OF_WEEK',
  TimeOfDay: 'TIME_OF_DAY',
})

const OperatorType = Object.freeze({
  // equality ops for free entry values
  Equal: '==',
  NotEqual: '!=',
  Greater: '>',
  GreaterOrEqual: '>=',
  Less: '<',
  LessOrEqual: '<=',

  // match ops for objects
  Match: 'match',
  NotMatch: 'not_match',

  // in ops for groups
  In: 'in',
  NotIn: 'not_in',
})

const OperatorTypeLiteral = Object.freeze({
  Equal: 'equals',
  NotEqual: 'not_equals',
  Match: 'match',
  NotMatch: 'not_match',
  In: 'in',
  NotIn: 'not_in',
  Greater: 'greater',
  GreaterOrEqual: 'greater_or_equal',
  Less: 'less',
  LessOrEqual: 'less_or_equal',
})

const eqOps = [
  OperatorType.Equal,
  OperatorType.NotEqual,
  OperatorType.Greater,
  OperatorType.GreaterOrEqual,
  OperatorType.Less,
  OperatorType.LessOrEqual,
]
const matchOps = [OperatorType.Match, OperatorType.NotMatch]
const inOps = [OperatorType.In, OperatorType.NotIn]

const sourceConditionTypes = [
  ConditionType.ClientAddress,
  ConditionType.ClientApplication,
  ConditionType.ClientDnsHint,
  ConditionType.ClientGeoIp,
  ConditionType.ClientInterfaceType,
  ConditionType.ClientPort,
  ConditionType.ClientService,
  ConditionType.SourceInterface,
]

const destinationConditionTypes = [
  ConditionType.ServerAddress,
  ConditionType.ServerApplication,
  ConditionType.ServerDnsHint,
  ConditionType.ServerGeoIp,
  ConditionType.ServerInterfaceType,
  ConditionType.ServerPort,
  ConditionType.ServerService,
  ConditionType.DestinationInterface,
]

const otherConditionTypes = [
  ConditionType.ApplicationCategory,
  ConditionType.ApplicationCategoryInferred,
  ConditionType.ApplicationName,
  ConditionType.ApplicationNameInferred,
  ConditionType.ApplicationProductivity,
  ConditionType.ApplicationProductivityInferred,
  ConditionType.ApplicationRisk,
  ConditionType.ApplicationRiskInferred,

  ConditionType.Application,

  ConditionType.IpProtocol,
  ConditionType.Service,
  ConditionType.User,
  ConditionType.VlanTag,
  ConditionType.VrfName,
  ConditionType.DayOfWeek,
  ConditionType.TimeOfDay,
]

const ConditionTarget = Object.freeze({
  Source: 'SOURCE',
  Destination: 'DESTINATION',
  Other: 'OTHER',
})

/**
 * Get literal operator based on type
 * @param operator
 * @returns {*|undefined}
 */
function getLiteralOperator(operator) {
  const key = Object.keys(OperatorType).find(key => OperatorType[key] === operator)
  return key ? OperatorTypeLiteral[key] : undefined
}

export {
  Type,
  ActionType,
  SyncStatus,
  ConditionType,
  OperatorType,
  OperatorTypeLiteral,
  ConditionTarget,
  eqOps,
  matchOps,
  inOps,
  sourceConditionTypes,
  destinationConditionTypes,
  otherConditionTypes,
  getLiteralOperator,
}
