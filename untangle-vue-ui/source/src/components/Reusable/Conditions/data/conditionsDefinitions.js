import {
  allOperatorOptions,
  connectionStateOptions,
  limitRateOperatorOptions,
  limitBurstOperatorOptions,
  protocolOptions,
  riskLevelOptions,
  productivityLevelOptions,
  countryOptions,
  onlyIsOperatorOptions,
  addressTypeOptions,
  interfaceTypeOptions,
} from 'vuntangle'

import { portProtocolOptions } from '@/constants/index'
import util from '@/util/util'

export const conditionDefs = {
  APPLICATION_NAME: {
    field: 'autocomplete',
    ops: onlyIsOperatorOptions,
    layer3: false,
    category: 'application',
  },
  APPLICATION_NAME_INFERRED: {
    field: 'autocomplete',
    ops: onlyIsOperatorOptions,
    layer3: false,
    category: 'application',
  },
  APPLICATION_CATEGORY: {
    field: 'autocomplete',
    ops: onlyIsOperatorOptions,
    layer3: false,
    category: 'application',
  },
  APPLICATION_CATEGORY_INFERRED: {
    field: 'autocomplete',
    ops: onlyIsOperatorOptions,
    layer3: false,
    category: 'application',
  },
  APPLICATION_PRODUCTIVITY: {
    field: 'select',
    ops: allOperatorOptions,
    selectItems: productivityLevelOptions,
    layer3: false,
    category: 'application',
  },
  APPLICATION_PRODUCTIVITY_INFERRED: {
    field: 'select',
    ops: allOperatorOptions,
    selectItems: productivityLevelOptions,
    layer3: false,
    category: 'application',
  },
  APPLICATION_RISK: {
    field: 'select',
    ops: allOperatorOptions,
    selectItems: riskLevelOptions,
    layer3: false,
    category: 'application',
  },
  APPLICATION_RISK_INFERRED: {
    field: 'select',
    ops: allOperatorOptions,
    selectItems: riskLevelOptions,
    layer3: false,
    category: 'application',
  },
  APPLICATION_CONFIDENCE: {
    ops: allOperatorOptions,
    layer3: false,
    category: 'application',
  },
  APPLICATION_PROTOCHAIN: {
    layer3: false,
    category: 'application',
  },

  // the CLIENT ones are not longer used, kept only for backward compatibility
  CLIENT_TAGGED: {
    layer3: true,
    extraRules: 'required',
    category: 'other',
  },
  CLIENT_ADDRESS: {
    extraRules: 'ip_expression',
    layer3: true,
    category: 'other',
  },
  CLIENT_ADDRESS_V6: {
    extraRules: 'ip_v6_expression',
    layer3: true,
    category: 'other',
  },
  CLIENT_PORT: {
    ops: allOperatorOptions,
    extraRules: 'port',
    layer3: true,
    category: 'other',
  },
  CLIENT_INTERFACE_TYPE: {
    field: 'select',
    selectItems: interfaceTypeOptions,
    layer3: true,
    category: 'other',
  },
  CLIENT_INTERFACE_ZONE: {
    field: 'select',
    layer3: true,
    category: 'other',
  },

  // the SERVER ones are not used except SERVER_DNS_HINT as Server DNS Cache in other category
  SERVER_TAGGED: {
    layer3: true,
    extraRules: 'required',
    category: 'other',
  },
  SERVER_ADDRESS: {
    extraRules: 'ip_expression',
    layer3: true,
    category: 'other',
  },
  SERVER_ADDRESS_V6: {
    extraRules: 'ip_v6_expression',
    layer3: true,
    category: 'other',
  },
  SERVER_PORT: {
    ops: allOperatorOptions,
    extraRules: 'port',
    layer3: true,
    category: 'other',
  },
  SERVER_DNS_HINT: {
    layer3: true,
    category: 'other',
  },
  SERVER_INTERFACE_TYPE: {
    field: 'select',
    selectItems: interfaceTypeOptions,
    layer3: true,
    category: 'other',
  },
  SERVER_INTERFACE_ZONE: {
    field: 'select',
    layer3: true,
    category: 'other',
  },

  SRC_ADDR: {
    extraRules: 'ip_expression',
    layer3: true,
    category: 'source',
  },
  SOURCE_ADDRESS_V6: {
    extraRules: 'ip_v6_expression',
    layer3: true,
    category: 'source',
  },
  SOURCE_ADDRESS_TYPE: {
    field: 'select',
    selectItems: addressTypeOptions,
    layer3: true,
    category: 'source',
  },
  SOURCE_PORT: {
    defaults: { op: '==', value: '', port_protocol: '6' },
    extraRules: 'port_expression',
    layer3: true,
    category: 'source',
  },
  SRC_INTF: {
    field: 'autocomplete',
    multiple: true,
    autocompleteItems: util.getInterfaceList(true, true),
    category: 'source',
  },
  SOURCE_INTERFACE_NAME: {
    category: 'source',
  },
  SOURCE_INTERFACE_TYPE: {
    field: 'select',
    selectItems: interfaceTypeOptions,
    layer3: true,
    category: 'source',
  },
  SOURCE_INTERFACE_ZONE: {
    field: 'select',
    layer3: true,
    category: 'source',
  },

  DST_ADDR: {
    extraRules: 'ip_expression',
    layer3: true,
    category: 'destination',
  },
  DESTINATION_ADDRESS_V6: {
    extraRules: 'ip_v6_expression',
    layer3: true,
    category: 'destination',
  },
  DESTINATION_ADDRESS_TYPE: {
    field: 'select',
    selectItems: addressTypeOptions,
    layer3: true,
    category: 'destination',
  },
  DESTINATION_PORT: {
    defaults: { op: '==', value: '', port_protocol: '6' },
    extraRules: 'port_expression',
    layer3: true,
    category: 'destination',
  },
  DST_PORT: {
    defaults: { op: '==', value: '' },
    extraRules: 'port_expression',
    layer3: true,
    category: 'destination',
  },
  DESTINATION_INTERFACE_NAME: {
    category: 'destination',
  },
  DESTINATION_INTERFACE_TYPE: {
    field: 'select',
    selectItems: interfaceTypeOptions,
    layer3: true,
    category: 'destination',
  },
  DESTINATION_INTERFACE_ZONE: {
    field: 'select',
    layer3: true,
    category: 'destination',
  },

  DESTINED_LOCAL: {
    field: 'boolean',
    defaults: { op: '==', value: true },
    layer3: true,
    category: 'other',
  },
  DST_LOCAL: {
    defaults: { op: '==', value: true, isObsolete: true },
    layer3: true,
    category: 'other',
  },
  PROTOCOL: {
    field: 'autocomplete',
    multiple: true,
    autocompleteItems: portProtocolOptions,
    layer3: true,
    category: 'other',
  },
  IP_PROTOCOL: {
    field: 'autocomplete',
    multiple: true,
    autocompleteItems: protocolOptions,
    layer3: true,
    category: 'other',
  },
  LIMIT_RATE: {
    ops: limitRateOperatorOptions,
    defaults: { op: '<', value: '', rate_unit: 'PACKETS_PER_SECOND' },
    extraRules: 'integer|min_value:1',
    layer3: true,
    category: 'other',
    required: true,
  },
  BURST_SIZE: {
    ops: limitBurstOperatorOptions,
    defaults: { op: '==', value: '', burst_unit: 'PACKETS' },
    extraRules: 'integer|min_value:0',
    layer3: true,
    category: 'other',
  },
  GEOIP: {
    field: 'autocomplete',
    autocompleteItems: countryOptions,
    layer3: false,
    category: 'other',
  },
  CT_STATE: {
    field: 'select',
    selectItems: connectionStateOptions,
    layer3: false,
    category: 'other',
  },
  MAC_ADDRESS: {
    layer3: false,
    category: 'other',
    extraRules: 'mac_address',
  },
}

export const conditionTypes = Object.keys(conditionDefs)
