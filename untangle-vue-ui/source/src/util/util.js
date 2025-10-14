import {
  addressTypeOptions,
  interfaceTypeOptions,
  ruleOps,
  protocols,
  portProtocols,
  priorities,
  limitExceedActions,
} from 'vuntangle/constants'

import { cloneDeep } from 'lodash'
import * as ipaddr from 'ipaddr.js'
import axios from 'axios'
import i18n from '@/plugins/vue-i18n'
import http from '@/plugins/http'
import store from '@/store'

export const hourInMilliseconds = 60 * 60 * 1000

const util = {
  async addressChecker(cidr) {
    let response
    try {
      response = await http.post('/api/netspace/check', { cidr })
    } catch (ex) {
      return i18n.t('address_conflict_detect_fail')
    }

    try {
      const details = response?.data ? JSON.parse(response.data) : null
      return details?.error || null
    } catch (ex) {
      return null
    }
  },

  /**
   * checks if box is reachable while rebooting or upgrading
   * using a 3s interval to avoid flooding with calls
   */
  async checkOnlineStatus() {
    try {
      await http.get('/account/status', {
        timeout: 3000,
      })
    } catch (err) {
      /**
       * After manual reboot or reboot triggered by upgrade process
       * in case of Bad Request or Forbidden means the box is up online
       * A fresh reload of the app is required redirecting user to login
       *
       * Otherwise, check again for online status
       */
      if (err.response?.status === 400 || err.response?.status === 403) {
        document.location.reload()
      } else {
        setTimeout(util.checkOnlineStatus, 3000)
      }
    }
  },
  formatRuleSummary(rule) {
    const conditionsArr = []
    let actionStr = ''

    rule.conditions?.forEach(c => {
      const cond = i18n.t(c.type.toLowerCase())
      const op = i18n.t(ruleOps[c.op])
      let value = c.value

      if (c.type.includes('_INTERFACE_TYPE') && c.value !== null) {
        value = i18n.t(interfaceTypeOptions.find(o => o.value === parseInt(value))?.text)
      }
      if (c.type.includes('_ADDRESS_TYPE') && c.value !== null) {
        value = i18n.t(addressTypeOptions.find(o => o.value === value)?.text)
      }
      if (c.type.includes('_INTERFACE_ZONE') && c.value !== null) {
        value = store.getters['settings/interfaceById'](parseInt(value))?.name
      }
      if (c.type === 'IP_PROTOCOL' && c.value !== null) {
        const strVal = c.value + '' // make sure it's a string
        const arr = []
        strVal.split(',').forEach(v => {
          arr.push(protocols[v])
        })
        value = arr.join(', ')
      }

      if ((c.type.endsWith('_ADDRESS') || c.type.endsWith('_ADDRESS_V6')) && c.value !== null) {
        // v4 and v6 addresses are expressions, just add a space after commas when rendering
        value = c.value.replace(/ /g, '').replace(/,/g, ', ')
      }

      /**
       * DESTINATION_PORT and SOURCE_PORT contains an extra `port_protocol` prop
       * this port_protocol can be a single int (for a single protocol)
       * or an array of ints for multiple protocols
       *     6: 'TCP',
       *    17: 'UDP',
       *    33: 'DCCP',
       *   132: 'SCTP',
       *   136: 'UDPLite',
       *   e.g. summary: "TCP or UDP or DCCP Destination Port Is 56"
       */
      if (c.type === 'DESTINATION_PORT' || c.type === 'SOURCE_PORT') {
        let protocols = ''
        if (Array.isArray(c.port_protocol)) {
          // array
          protocols = c.port_protocol.map(protocol => portProtocols[protocol]).join(` ${i18n.t('or')} `)
        } else {
          // single
          protocols = portProtocols[c.port_protocol]
        }

        conditionsArr.push(
          `${i18n.t('is')} <strong>${protocols || '?'}</strong>
          ${i18n.t('and')}
          <strong>${cond}</strong> ${op} <strong>${value || '?'}</strong>`,
        )
        return
      }

      /**
       * DESTINED_LOCAL (boolean) custom summary string
       * eg.: "is Destined Local"
       */
      if (c.type === 'DESTINED_LOCAL') {
        value = `${c.value ? i18n.t('is') : i18n.t('is_not')} <strong>${i18n.t('destined_local')}</strong>`
        conditionsArr.push(`${value || '?'}`)
        return
      }

      // just use translations for: 'established', 'invalid', 'new' and 'related' states
      // value matches the translation string
      if (c.type === 'CT_STATE') {
        value = i18n.t(value)
      }

      conditionsArr.push(`<strong>${cond}</strong> ${op} <strong>${value || '?'}</strong>`)
    })

    switch (rule.action?.type) {
      case 'DNAT':
        actionStr = `<span class="primary--text font-weight-bold">
        ${i18n.t('action_new_destination_is')}
        ${rule.action.dnat_address || '?'}${rule.action.dnat_port ? ':' + rule.action.dnat_port : ''}
        </span>`
        break
      case 'SNAT':
        actionStr = `<span class="primary--text font-weight-bold">
        ${i18n.t('action_new_source_is')}
        ${rule.action.snat_address}
        </span>`
        break
      case 'SET_PRIORITY': {
        const priorityDescription = i18n.t('action_str_set_priority', [priorities[rule.action.priority]])
        actionStr = `<span class="primary--text font-weight-bold">${priorityDescription}</span>`
        break
      }
      case 'LIMIT_EXCEED_ACTION': {
        const limitExceedAction = i18n.t('action_str_limit_exceed_action', [
          limitExceedActions[rule.action.limit_exceed_action],
        ])
        actionStr = `<span class="primary--text font-weight-bold">${limitExceedAction}</span>`
        break
      }
      case 'WAN_POLICY': {
        const policy = store.getters['settings/policyById'](rule.action?.policy)
        actionStr = `<span class="primary--text font-weight-bold">
          ${i18n.t('action_wan_policy_is')} ${policy?.description || '?'}</span>`
        break
      }
      case 'ACCEPT':
        actionStr = `<span class="primary--text font-weight-bold">${i18n.t('action_accept')}</span>`
        break
      case 'DROP':
        actionStr = `<span class="red--text font-weight-bold">${i18n.t('action_drop')}</span>`
        break
      case 'REJECT':
        actionStr = `<span class="red--text font-weight-bold">${i18n.t('action_reject')}</span>`
        break
      case 'MASQUERADE':
        actionStr = `<span class="primary--text font-weight-bold">${i18n.t('action_masquerade')}</span>`
        break
    }

    if (!conditionsArr.length) {
      return i18n.t('rule_summary_any_packet', [actionStr])
    }
    return (
      '<span class="text--secondary">' +
      i18n.t('rule_summary_if_packet', [`${conditionsArr.join(' ' + i18n.t('and') + ' ')}`, actionStr || '?']) +
      '</span>'
    )
  },

  /**
   * based on query string and local storage
   * @returns {boolean} true/false if debugging is enabled
   */
  langDebug() {
    // add langdebug to local storage
    if (location.search.includes('langdebug=true')) {
      window.localStorage.setItem('langdebug', true)
    }
    // remove langdebug from local storage
    if (location.search.includes('langdebug=false')) {
      window.localStorage.removeItem('langdebug')
    }
    // return langdebug
    return window.localStorage.getItem('langdebug')
  },

  uuidv4() {
    return ([1e7] + -1e3 + -4e3 + -8e3 + -1e11).replace(/[018]/g, c =>
      (c ^ (crypto.getRandomValues(new Uint8Array(1))[0] & (15 >> (c / 4)))).toString(16),
    )
  },

  /**
   * Convert an ip6 address to a javascript BigInt type.
   *
   * @param address
   * @returns {bigint}
   */
  // ipv6ToBigInt(address) {
  //   let binaryString = '0b'
  //   ip6
  //     .normalize(address)
  //     .split(':')
  //     .forEach(hextet => (binaryString += parseInt(hextet, 16).toString(2).padStart(16, '0')))

  //   return BigInt(binaryString)
  // },

  /**
   * Convert any ip address (ipv4 or ipv6) to a javascript BigInt type.
   *
   * @param address
   * @returns {bigint}
   */
  ipAnyToBigInt(address) {
    // try to convert ip4
    if (this.isIPv4AddressValid(address)) {
      return BigInt(this.ipv4ToLong(address))
    }

    // try to convert ip6, normalize first
    if (this.isIPv6AddressValid(address)) {
      return this.ipv6ToBigInt(address)
    }

    return BigInt(0)
  },

  /**
   * Fetch list of interfaces (options) for condition autocompleteItems
   */
  baseInterfaceList: null,
  baseInterfaceMap: null,
  fetchInterfaceData(networkSettings) {
    const data = []
    const map = {}

    // Physical interfaces
    networkSettings.interfaces.forEach(intf => {
      const key = intf.interfaceId.toString()
      const label = intf.name
      const item = { value: key, text: label }
      data.push(item)
      map[key] = label
    })

    // Virtual interfaces
    networkSettings.virtualInterfaces.forEach(intf => {
      const key = intf.interfaceId.toString()
      const label = intf.name
      const item = { value: key, text: label }
      data.push(item)
      map[key] = label
    })

    // Static IPsec entry
    const ipsecItem = { value: 'ipsec', text: i18n.t('ipsec_vpn') }
    data.push(ipsecItem)
    map.ipsec = ipsecItem.text

    // Store base list and map
    this.baseInterfaceList = data
    this.baseInterfaceMap = map
  },

  getInterfaceList(networkSettings, wanMatchers, anyMatcher) {
    try {
      this.fetchInterfaceData(networkSettings)
      const interfaces = cloneDeep(this.baseInterfaceList)

      if (wanMatchers) {
        interfaces.unshift({ value: 'wan', text: i18n.t('any_wan') })
        interfaces.unshift({ value: 'non_wan', text: i18n.t('any_non_wan') })
      }
      if (anyMatcher) {
        interfaces.unshift({ value: 'any', text: i18n.t('any') })
      }

      return interfaces
    } catch (error) {}
  },

  getInterfaceMap(networkSettings, wanMatchers, anyMatcher) {
    try {
      this.fetchInterfaceData(networkSettings)
      const map = { ...this.baseInterfaceMap }

      map.ipsec = 'ipsec_vpn'
      if (wanMatchers) {
        map.wan = 'any_wan'
        map.non_wan = 'any_non_wan'
      }
      if (anyMatcher) {
        map.any = 'any'
      }

      return map
    } catch (error) {}
  },

  /**
   * Gets the list of LAN IPv4 addresses from network settings
   * @param {NetworkSettings} networkSettings
   * @returns LAN IPv4 address List
   */
  getLanIpAddrs(networkSettings) {
    const baseLans =
      networkSettings?.interfaces
        ?.filter(intf => !intf.isWan && intf.v4StaticAddress)
        ?.map(intf => intf.v4StaticAddress) || []

    const virtualLans =
      networkSettings?.virtualInterfaces
        ?.filter(intf => !intf.isWan && intf.v4StaticAddress)
        ?.map(intf => intf.v4StaticAddress) || []
    return [...baseLans, ...virtualLans]
  },

  /**
   * Checks whether a given IP address lies within a specified inclusive range.
   *
   * @param {string} ip - The target IP address (e.g., "192.168.1.15").
   * @param {string} range - The range in "start-end" format
   *                         (e.g., "192.168.1.10-192.168.1.20").
   * @returns {boolean} - True if the IP lies within the range, false otherwise.
   *
   * @example
   * isIpInRange("192.168.1.15", "192.168.1.10-192.168.1.20") // => true
   * isIpInRange("192.168.1.25", "192.168.1.10-192.168.1.20") // => false
   */
  isIpInRange(ip, range) {
    const [startStr, endStr] = range.split('-').map(s => s.trim())
    const start = ipaddr.parse(startStr).toByteArray()
    const end = ipaddr.parse(endStr).toByteArray()
    const target = ipaddr.parse(ip.trim()).toByteArray()

    return this.compareBytes(target, start) >= 0 && this.compareBytes(target, end) <= 0
  },

  /**
   * Compares two byte arrays (representing IPv4/IPv6 addresses).
   *
   * @param {number[]} a - First IP address as a byte array.
   * @param {number[]} b - Second IP address as a byte array.
   * @returns {number} - Returns:
   *   -1 if `a < b`,
   *    0 if `a === b`,
   *    1 if `a > b`.
   *
   * @example
   * compareBytes([192,168,1,1], [192,168,1,2]) // => -1
   */
  compareBytes(a, b) {
    for (let i = 0; i < a.length; i++) {
      if (a[i] < b[i]) return -1
      if (a[i] > b[i]) return 1
    }
    return 0
  },

  /**
   * Download a file from the server via POST request.
   *
   * @param {string} url - API endpoint (e.g. '/admin/download')
   * @param {Object} params - Key/value pairs for form data
   * @param {string} filename - Suggested filename for saving
   * @returns {Promise<void>}
   */
  async downloadFile(url, params, filename) {
    const response = await axios.post(url, new URLSearchParams(params), {
      responseType: 'blob',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      withCredentials: true,
    })

    // Try to get filename from Content-Disposition
    const disposition = response.headers['content-disposition']
    if (!filename && disposition && disposition.includes('filename=')) {
      const matches = disposition.match(/filename="?([^"]+)"?/)
      if (matches != null && matches[1]) {
        filename = matches[1]
      }
    }

    const blob = new Blob([response.data])
    const link = document.createElement('a')
    link.href = URL.createObjectURL(blob)
    link.download = filename
    document.body.appendChild(link)
    link.click()
    link.remove()
    return true
  },

  /**
   * Upload a file on the input endpoint.
   *
   * @param {string} url - API endpoint
   * @param {Object} params - Key/value pairs for form data, must contain 'file' param consisting of base64 file contents
   * @returns {Promise<void>}
   */
  async uploadFile(url, params) {
    const formData = new FormData()
    for (const key in params) {
      formData.append(key, params[key])
    }

    const response = await axios.post(url, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
      withCredentials: true,
    })
    return response.data
  },

  /**
   * Checks if a given IP address belongs to a specific network.
   *
   * @param {string} ip - The IP address to check
   * @param {string} network - The base network address
   * @param {number|string} netmask - The network mask. Can be:
   *                                  - A number for CIDR notation (e.g., 24)
   *                                  - A string for dotted-decimal format (e.g., "255.255.255.0")
   * @returns {boolean} True if the IP belongs to the network, false otherwise.
   */
  ipMatchesNetwork(ip, network, netmask) {
    let dots
    let netmaskInteger = 0

    if (Number.isInteger(netmask)) {
      // CIDR notation like /24
      netmaskInteger = Math.pow(2, 32) - Math.pow(2, 32 - netmask)
    } else {
      // Dotted-decimal mask like 255.255.255.0
      dots = netmask.split('.')
      netmaskInteger = ((+dots[0] * 256 + +dots[1]) * 256 + +dots[2]) * 256 + +dots[3]
    }

    dots = network.split('.')
    const networkInteger = ((+dots[0] * 256 + +dots[1]) * 256 + +dots[2]) * 256 + +dots[3]

    dots = ip.split('.')
    const ipInteger = ((+dots[0] * 256 + +dots[1]) * 256 + +dots[2]) * 256 + +dots[3]

    return (ipInteger & netmaskInteger) === (networkInteger & netmaskInteger)
  },
}

export default util
