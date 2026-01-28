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
import Rpc from '@/util/Rpc'
import { VTypes } from '@/util/VTypes'

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
        value = store.getters['config/interfaceById'](parseInt(value))?.name
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
        const policy = store.getters['config/policyById'](rule.action?.policy)
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

  /**
   * Extracts and normalizes a JSON array string from a raw RPC response.
   * Handles cases where the response includes extra logs or single-quoted JSON.
   *
   * @param {string} rawResult - The raw RPC result string.
   * @returns {string|null} - A cleaned JSON string (ready for JSON.parse), or null if not found.
   */
  extractJsonArrayString(rawResult) {
    if (!rawResult) return null

    const jsonMatch = rawResult.match(/\[[\s\S]*\]/)
    if (!jsonMatch) return null

    // Normalize single-quoted JSON into valid JSON
    const jsonString = jsonMatch[0]
      .replace(/([{,]\s*)'([^']+?)'\s*:/g, '$1"$2":') // convert single-quoted keys
      .replace(/:\s*'([^']+?)'/g, ':"$1"') // convert single-quoted values

    return jsonString
  },

  /**
   * filters the rules array to find a rule by description.
   * returns the enabled status of the rule.
   * @param {*} rules
   * @param {*} description
   * @returns
   */
  getRuleEnabledStatus(rules, description) {
    if (!Array.isArray(rules)) return

    const filteredRule = rules.find(rule => rule.description === description)
    const isEnabled = filteredRule ? !!filteredRule.enabled : false

    return isEnabled
  },

  /**
   * Retrieves the store URL by replacing the API version path.
   * @returns {Promise<string>} The formatted store URL.
   */
  async getStoreUrl() {
    const url = await window.rpc.storeUrl.replace('/api/v1', '/store/open.php')
    return url
  },

  /**
   * Reloads licenses by making a direct RPC call.
   * @returns {Promise<void>}
   */
  async reloadLicenses() {
    await Rpc.directData('rpc.UvmContext.licenseManager.reloadLicenses', true)
  },

  /**
   * Fetches account information from the store.
   * @param {string} uid - The user ID.
   * @returns {Promise<Object>} A promise that resolves with the account data.
   */
  async fetchAccountInfo(uid) {
    const storeUrl = await this.getStoreUrl()

    return new Promise((resolve, reject) => {
      const script = document.createElement('script')
      const callbackName = `jsonpCallback_${Date.now()}`

      window[callbackName] = data => {
        resolve(data)
        delete window[callbackName]
        document.body.removeChild(script)
      }

      script.src = `${storeUrl}?action=find_account&uid=${encodeURIComponent(uid)}&callback=${callbackName}`
      script.onerror = reject
      document.body.appendChild(script)
    })
  },

  /**
   * Constructs the certificate subject string from certificate details.
   * @param {Object} details - Object containing certificate details like commonName, country, etc.
   * @returns {string} The formatted certificate subject string.
   */
  createCertSubject(details) {
    const certSubject = [
      '/CN=' + details.commonName,
      '/C=' + details.country,
      '/ST=' + details.state,
      '/L=' + details.locality,
      '/O=' + details.organization,
    ]

    if (details.organizationalUnit && details.organizationalUnit.length > 0) {
      certSubject.push('/OU=' + details.organizationalUnit)
    }

    return certSubject.join('')
  },

  /**
   * Creates a comma-separated string of Subject Alternative Names (SANs).
   * @param {string} altNames - A string of comma-separated alternative names.
   * @returns {string} A formatted string of SANs for use in certificate generation.
   */
  createAltNames(altNames) {
    if (!altNames || altNames.length === 0) {
      return ''
    }

    const hostnameRegex =
      /^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9-]*[A-Za-z0-9])$/
    const altNameTokens = altNames.split(',')
    const altNamesArray = []

    for (let i = 0; i < altNameTokens.length; i++) {
      const altName = altNameTokens[i].trim()
      if (VTypes.ipAddress.validate(altName)) {
        altNamesArray.push('IP:' + altName + ',DNS:' + altName)
      } else if (hostnameRegex.test(altName)) {
        altNamesArray.push('DNS:' + altName)
      } else {
        altNamesArray.push(altName)
      }
    }
    return altNamesArray.join(',')
  },

  /**
   * Determines if a certificate can be deleted based on certain conditions.
   * A certificate cannot be deleted if it's the system's Apache certificate ('apache.pem')
   * or if it is assigned to one or more services (HTTPS, SMTPS, IPsec, RADIUS).
   *
   * @param {object} data - The certificate data object.
   * @param {string} data.fileName - The file name of the certificate.
   * @returns {{allowed: boolean, message?: string}} An object indicating if deletion is allowed and an optional error message.
   */
  canDeleteCertificate(data) {
    if (data.fileName === 'apache.pem') {
      return {
        allowed: false,
        message: 'system_certificate_cannot_removed_error_message',
      }
    }

    if (data.httpsServer || data.smtpsServer || data.ipsecServer || data.radiusServer) {
      return {
        allowed: false,
        message: 'certificate_assigned_to_one_or_more_services_error_message',
      }
    }

    return { allowed: true }
  },

  /**
   *
   * @returns
   */
  isPolicyManagerInstalled() {
    return Rpc.directData('rpc.appManager.app', 'policy-manager')
  },
}

export default util
