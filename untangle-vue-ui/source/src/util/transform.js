/**
 * utility used to normalize data used in vuntangle components
 * each specific settings has a getter/setter
 * get - extracts required data from NGFW network settings and prepares it for vuntangle component
 * set - takes new data coming from component and applies it on the NGFW network setting structure
 */

import { cloneDeep } from 'lodash'
import store from '@/store'

/**
 * Adds specified `javaClass` for each item
 * New items that are added via vue components are not having the javaClass set
 * @param {Object[]} items - items in a list
 * @param {String} javaClass - java class to be set on each
 *
 * @returns all itemes having javaClass set
 */
const applyJavaClass = function (items, javaClass) {
  const filter = items.filter(item => !item.javaClass)
  filter.forEach(item => (item.javaClass = `com.untangle.uvm.network.${javaClass}`))
  return items
}

const dns = {
  get: () => {
    /** @type {NetworkSettings} */
    const ns = store.getters['settings/networkSettings']
    return {
      staticEntries: ns?.dnsSettings?.staticEntries.list,
      localServers: ns?.dnsSettings?.localServers.list,
    }
  },
  set: dnsSettings => {
    const ns = cloneDeep(store.getters['settings/networkSettings'])
    ns.dnsSettings.staticEntries.list = applyJavaClass(dnsSettings.staticEntries, 'DnsStaticEntry')
    ns.dnsSettings.localServers.list = applyJavaClass(dnsSettings.localServers, 'DnsLocalServer')

    return ns
  },
}

const dhcp = {
  get: () => {
    const ns = store.getters['settings/networkSettings']
    return {
      dhcpAuthoritative: ns?.dhcpAuthoritative,
      staticDhcpEntries: ns?.staticDhcpEntries.list,
    }
  },
  set: dhcpSettings => {
    const ns = cloneDeep(store.getters['settings/networkSettings'])
    ns.dhcpAuthoritative = dhcpSettings.dhcpAuthoritative
    ns.staticDhcpEntries.list = applyJavaClass(dhcpSettings.staticDhcpEntries, 'DhcpStaticEntry')
    return ns
  },
}

const staticRoutes = {
  get: () => {
    const ns = store.getters['settings/networkSettings']
    return ns?.staticRoutes.list
  },
  set: staticRoutes => {
    const ns = cloneDeep(store.getters['settings/networkSettings'])
    ns.staticRoutes.list = applyJavaClass(staticRoutes, 'StaticRoute')
    return ns
  },
}

export default { dns, dhcp, staticRoutes }
