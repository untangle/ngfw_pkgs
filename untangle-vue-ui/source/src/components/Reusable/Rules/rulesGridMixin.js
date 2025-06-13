import {
  protocols,
  limitRateUnits,
  limitBurstUnits,
  productivityLevels,
  addressTypes,
  interfaceTypes,
  priorities,
  limitExceedActions,
  invertToOp,
} from '../../../constants'
import actionsConfig from '../../../config/actionsConfig'
import util from '../../../util/util'

import i18n from '@/plugins/vue-i18n'

export default {
  inject: ['$remoteData', '$features', '$readOnly'],
  computed: {
    remoteData: ({ $remoteData }) => $remoteData(),
    interfacesMap: ({ remoteData }) =>
      remoteData?.interfaces.reduce((res, intf) => {
        return { ...res, [intf.value]: intf.text }
      }, {}),
    wanPoliciesMap: ({ remoteData }) =>
      remoteData?.wanPolicies.reduce((res, policy) => {
        return { ...res, [policy.value]: policy.text }
      }, {}),
    etmNetworksUri: ({ remoteData }) => remoteData?.etmNetworksUri,
  },
  methods: {
    getConditionValue(cond) {
      let value = ''
      let interfaceMap = {}
      const type = cond.conditionType.replace('_INFERRED', '')

      switch (type) {
        /**
         * app category is in english and retrieved via apps classify (e.g. `Streaming Media`)
         * translations are still applied to them
         */
        case 'APPLICATION_CATEGORY':
          value = i18n.t(cond.value.replace(/ /g, '_').toLowerCase())
          break

        case 'DESTINATION_INTERFACE_ZONE':
        case 'CLIENT_INTERFACE_ZONE':
        case 'SERVER_INTERFACE_ZONE':
          value = this.interfacesMap[cond.value]
          break

        case 'CLIENT_INTERFACE_TYPE':
        case 'SERVER_INTERFACE_TYPE':
        case 'SOURCE_INTERFACE_TYPE':
        case 'DESTINATION_INTERFACE_TYPE':
          value = i18n.t(interfaceTypes[cond.value])
          break

        case 'SRC_INTF':
          interfaceMap = util.getInterfaceMap(true, true)
          value = cond.value
            .split(',')
            .map(id => i18n.t(interfaceMap[id] || id))
            .join(', ')
          break

        case 'APPLICATION_PRODUCTIVITY':
        case 'APPLICATION_RISK':
          value = i18n.t(productivityLevels[cond.value])
          break

        case 'SOURCE_ADDRESS_TYPE':
        case 'DESTINATION_ADDRESS_TYPE':
          value = i18n.t(addressTypes[cond.value])
          break

        case 'SOURCE_PORT':
        case 'DESTINATION_PORT':
          if (Array.isArray(cond.port_protocol)) {
            value = []
            cond.port_protocol.forEach(p => value.push(protocols[p]))
            value = value.join(', ')
          } else {
            value = protocols[cond.port_protocol]
          }
          value = `${cond.value} (${value})`
          break

        case 'GEOIP':
          value = util.country_codes[cond.value]
          break

        case 'CT_STATE':
          value = i18n.t(cond.value)
          break

        case 'IP_PROTOCOL':
          value = []
          cond.value = cond.value.toString()
          cond.value.split(',').forEach(protocol => value.push(protocols[protocol]))
          value = value.join(', ')
          break

        case 'LIMIT_RATE':
          value = i18n.t(limitRateUnits[cond.rate_unit])
          value = `${cond.value} ${value}`
          break

        case 'BURST_SIZE':
          value = i18n.t(limitBurstUnits[cond.burst_unit])
          value = `${cond.value} ${value}`
          break

        default:
          value = cond.value
      }
      return value
    },

    conditionsValue(conditions) {
      return conditions.list.map(cond => ({
        type: i18n.t(cond.conditionType.toLowerCase()),
        op: invertToOp[cond.invert],
        value: i18n.t(this.getConditionValue(cond)),
      }))
    },

    actionValue(data) {
      if (data.newDestination) {
        data.action = { type: 'DNAT' }
      }
      const action = data.action
      const out = {
        text: undefined,
        icon: actionsConfig[action.type].icon,
        iconColor: actionsConfig[action.type].iconColor,
      }

      switch (action.type) {
        case 'ACCEPT':
        case 'REJECT':
        case 'DROP':
        case 'MASQUERADE':
        case 'RETURN':
        case 'BYPASS':
          out.text = i18n.t(actionsConfig[action.type].text)
          break
        case 'SNAT':
          out.text = `${i18n.t('new_source')}: ${action.snat_address}`
          break
        case 'DNAT':
          out.text = `${i18n.t('new_destination')}: ${data.newDestination}${data.newPort ? ':' + data.newPort : ''}`
          data.action.newDestination = data.newDestination
          data.action.newPort = data.newPort
          break
        case 'SET_PRIORITY':
          out.text = `${i18n.t('priority')}: ${i18n.t(priorities[action.priority])}`
          break
        case 'WAN_POLICY':
          out.text = `${i18n.t('wan_policy')}: ${this.wanPoliciesMap[action.policy]}`
          break
        case 'LIMIT_EXCEED_ACTION':
          out.text = i18n.t(limitExceedActions[action.limit_exceed_action])
          switch (action.limit_exceed_action) {
            case 'DROP':
              out.icon = 'mdi-arrow-down'
              out.iconColor = 'red'
              break
            case 'ACCEPT':
              out.icon = 'mdi-check'
              out.iconColor = 'green'
              break
            case 'REJECT':
              out.icon = 'mdi-close'
              out.iconColor = 'orange'
              break
            case 'PRIORITY':
              out.icon = 'mdi-sort'
              out.text = `${i18n.t('priority')}: ${i18n.t(priorities[action.priority])}`
              break
          }
          break
      }

      return out
    },
  },
}
