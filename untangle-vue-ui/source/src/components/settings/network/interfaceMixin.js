import { CONFIG_TYPE } from '../../settings/network/SettingsInterface/components/constants'

const datasizeMap = [
  [1125899906842624, 'PB'],
  [1099511627776, 'TB'],
  [1073741824, 'GB'],
  [1048576, 'MB'],
  [1024, 'KB'],
  [1, 'B'],
]
const countMap = [
  [1125899906842624, 'P'], // PB
  [1099511627776, 'T'], // TB
  [1073741824, 'G'], // GB
  [1048576, 'M'], // MB
  [1024, 'K'], // KB
  [1, ''], // B (no unit)
]
export default {
  methods: {
    /**
     * Value formatter for grid device name
     * It guesses the EOS interface display names based on device
     * e.g. `et1_3` => `Ethernet1/3`, `ma1_1` => `Management1/1`
     * For non EOS devices (e.g. OpenWRT) it will use device name as is
     * @param {String} device - the interface device
     * @returns
     */
    deviceValueFormatter(device) {
      const reEt = /^et(\d{1,2})_(\d{1,2})$/
      const reMa = /^ma(\d{1,2})_(\d{1,2})$/

      const match = device.match(reEt) || device.match(reMa)
      if (!match) return device

      let name = ''
      if (match[0].startsWith('et')) name = this.$vuntangle.$t('ethernet')
      if (match[0].startsWith('ma')) name = this.$vuntangle.$t('management')

      return `${name}${match[1]}/${match[2]}`
    },

    /**
     * Returns the interface status, e.g. `Connected (online)`
     * @param {Object} intf - interface settings
     * @param {Object} status - interface status
     * @returns {Object}
     */
    getStatus(intf, status) {
      return {
        intf,
        status,
      }
    },

    /**
     * Value formatter for grid status for proper filtering sorting
     * @param {Object} value
     * @returns {String}
     */
    statusValueFormatter({ intf, status }) {
      let connectionStatus = 'unknown'

      if (!intf || intf.enabled === undefined) {
        connectionStatus = 'missing'
      } else if (!intf.enabled) {
        connectionStatus = 'disabled'
      } else if (status?.connected) {
        connectionStatus = 'connected'
      } else {
        connectionStatus = 'disconnected'
      }

      const connected = this.$t(connectionStatus)
      const online = status?.wan && status?.connected && !status?.offline ? this.$t('online') : this.$t('offline')

      return `${connected} ${online}`
    },

    /**
     * Returns the interface duplex, e.g. `Full Duplex`
     * @param {Object} intf - interface settings
     * @param {Object} status - interface status
     * @returns {String}
     */
    getDuplex(intf, status) {
      const duplex = status?.duplex || intf.duplex

      switch (duplex) {
        case 'FULL_DUPLEX':
          return this.$vuntangle.$t('Full-duplex')
        case 'HALF_DUPLEX':
          return this.$vuntangle.$t('Half-duplex')
        default:
          return this.$vuntangle.$t('Unknown')
      }
    },

    getIsWan(intf, status) {
      const configType = (intf && intf.configType) || (status && status.configType)
      const isWAN = (intf && intf.isWan) || (status && status.isWan)

      if (configType === 'ADDRESSED') {
        return isWAN ? this.$t('true') : this.$t('false')
      } else {
        return ''
      }
    },
    deviceRenderer(intf) {
      if (!intf) return ''

      // If it's a VLAN interface, return systemDev, else return symbolicDev
      return intf.isVlanInterface ? intf.systemDev : intf.symbolicDev
    },

    getConfigAddress(intf = {}, status = {}) {
      const configType = intf.configType || status.configType

      switch (configType) {
        case 'ADDRESSED':
          return this.$t('Addressed')
        case 'BRIDGED':
          return this.$t('Bridged')
        case 'DISABLED':
          return this.$t('Disabled')
        default:
          return configType ? this.$t(configType) : ''
      }
    },

    datasize(value) {
      if (value === null) value = 0
      value = parseInt(value, 10)

      let size = datasizeMap[datasizeMap.length - 1]
      for (let i = 0; i < datasizeMap.length; i++) {
        size = datasizeMap[i]
        if (value >= size[0] || value <= -size[0]) {
          break
        }
      }

      if (value === 0 || size[0] === 1) {
        return `${value} ${size[1]}`
      } else {
        let dividedValue = (value / size[0]).toFixed(2)
        if (dividedValue.endsWith('.00')) {
          dividedValue = dividedValue.slice(0, -3)
        }
        return `${dividedValue} ${size[1]}`
      }
    },

    count(value) {
      if (value === null) value = 0
      value = parseInt(value, 10)

      let size = countMap[countMap.length - 1]
      for (let i = 0; i < countMap.length; i++) {
        size = countMap[i]
        if (value >= size[0] || value <= -size[0]) {
          break
        }
      }

      if (value === 0 || size[0] === 1) {
        return `${value} ${size[1]}`
      } else {
        let formatted = (value / size[0]).toFixed(2)
        if (formatted.endsWith('.00')) {
          formatted = formatted.slice(0, -3)
        }
        return `${formatted} ${size[1]}`
      }
    },

    /**
     * Returns the interface MAC address
     * @param {Object} intf - interface settings
     * @param {Object} status - interface status
     * @returns {String}
     */
    getMac(intf, status) {
      if (intf.virtual) return '-'
      return status?.macAddress || '-'
    },

    /**
     * Returns the interface ETH speed
     * @param {Object} intf - interface settings
     * @param {Object} status - interface status
     * @returns {String}
     */
    getSpeed(intf = {}, status = {}) {
      const speed = status?.mbit > -1 ? status.mbit : intf.mbit

      if (!speed || speed === 0) {
        return ''
      }

      if (speed >= 1000) {
        return speed / 1000 + ' ' + this.$t('Gbit')
      }

      return speed + ' ' + this.$t('Mbit')
    },
    /**
     * Returns the interface type (WAN, LAN, Management / NIC, VLAN, WIREGUARD etc)
     * @param {Object} intf - interface settings
     * @returns {String}
     */
    getType(intf) {
      let type = this.$vuntangle.$t('lan')
      if (intf.management) type = this.$vuntangle.$t('management')
      if (intf.wan) type = this.$vuntangle.$t('wan')
      return `${type} / ${intf.type}`
    },

    /**
     * Returns interface IPv4 Address based on status or fallsback on settings
     * @param {Object} intf - interface settings
     * @param {Object} status - interface status
     * @returns {String}
     */

    getIpv4Address(intf, status) {
      if (!status?.v4Address && !status?.v4StaticAddress && !status?.v4Address && !intf?.v4StaticAddress) {
        return '-'
      }

      let address = ''

      // 1. First priority: status.v4Address
      if (status?.v4Address) {
        address = status.v4Address
        if (status.v4PrefixLength) {
          address += `/${status.v4PrefixLength}`
        }
      }
      // 2. Second priority: status.v4StaticAddress
      else if (status?.v4StaticAddress) {
        address = status.v4StaticAddress
        if (status.v4StaticPrefix) {
          address += `/${status.v4StaticPrefix}`
        }
      }
      // 3. Third priority: status.v4Address
      else if (status?.v4Address) {
        address = status.v4Address
        if (status.v4PrefixLength) {
          address += `/${status.v4PrefixLength}`
        }
      }
      // 4. Fourth priority: intf.v4StaticAddress
      else if (intf?.v4StaticAddress) {
        if (intf.v4ConfigType === CONFIG_TYPE.DISABLED) {
          return this.$vuntangle.$t('disabled')
        }
        address = intf.v4StaticAddress
        if (intf.v4StaticPrefix) {
          address += `/${intf.v4StaticPrefix}`
        }
      }

      return address
    },

    /**
     * Returns interface IPv6 Address based on status or fallsback on settings
     * @param {Object} intf - interface settings
     * @param {Object} status - interface status
     * @returns {String}
     */
    getIpv6Address(intf, status) {
      if (!status?.ip6Addr && !intf.v6StaticAddress) return '-'

      let address = ''
      if (status?.ip6Addr) {
        address = status.ip6Addr.join(', ')
      } else if (intf.v6StaticAddress) {
        if (intf.v6ConfigType === CONFIG_TYPE.DISABLED) {
          return this.$vuntangle.$t('disabled')
        }
        address = intf.v6StaticAddress + (intf.v6StaticPrefix ? `/${intf.v6StaticPrefix}` : '')
      }
      const addressSource = status
        ? this.getAddressSource(status)
        : intf.v6ConfigType?.toLowerCase() || this.$vuntangle.$t('unknown')
      return `${address} (${addressSource})`
    },

    /**
     * Returns interface IPv4 Gateway
     * @param {Object} intf - interface settings
     * @param {Object} status - interface status
     * @returns {String}
     */
    getIpv4Gateway(intf, status) {
      return status?.ip4Gateway || '-'
    },

    /**
     * Returns interface IPv6 Gateway
     * @param {Object} intf - interface settings
     * @param {Object} status - interface status
     * @returns {String}
     */
    getIpv6Gateway(intf, status) {
      return status?.ip6Gateway || '-'
    },

    /**
     * Returns DNS Servers
     * @param {Object} intf - interface settings
     * @param {Object} status - interface status
     * @returns {String}
     */
    getDnsServers(intf, status) {
      const servers = status?.dnsServers
      return servers?.length ? servers.join(', ') : '-'
    },

    /**
     * Returns Download speed
     * @param {Object} intf - interface settings
     * @param {Object} status - interface status
     * @returns {String}
     */
    getDownload(intf, status) {
      // compute download for non bridged
      if (!status || !status.connected || status.offline) return '-'

      let downloadKbps = 0

      // for non bridged interfaces
      if (intf.type !== 'BRIDGE') {
        if (status.wan) {
          downloadKbps = status.rxByteRate / 1000
        }
        downloadKbps = status.txByteRate / 1000
      } else {
        // cummulate download for bridged
        let downloadSpeed = 0
        const bridgedInterfaces = this.interfaces.filter(i => intf.bridgedInterfaces?.includes(i.interfaceId))
        bridgedInterfaces.forEach(i => {
          const devStatus = this.interfacesStatusMap?.[i.device]
          if (devStatus) {
            downloadSpeed += devStatus.txByteRate / 1000
          }
        })
        downloadKbps = Math.round(downloadSpeed * 1000) / 1000
      }

      return `${downloadKbps} ${this.$vuntangle.$t('kbps')}`
    },

    /**
     * Returns Upload speed
     * @param {Object} intf - interface settings
     * @param {Object} status - interface status
     * @returns {String}
     */
    getUpload(intf, status) {
      // compute upload for non bridged
      if (!status || !status.connected || status.offline) return '-'

      let uploadKbps = 0

      // for non bridged interfaces
      if (intf.type !== 'BRIDGE') {
        if (status.wan) {
          uploadKbps = status.txByteRate / 1000
        }
        uploadKbps = status.rxByteRate / 1000
      } else {
        // cummulate upload for bridged
        let uploadSpeed = 0
        const bridgedInterfaces = this.interfaces.filter(i => intf.bridgedInterfaces?.includes(i.interfaceId))
        bridgedInterfaces.forEach(i => {
          const devStatus = this.interfacesStatusMap?.[i.device]
          if (devStatus) {
            uploadSpeed += devStatus.rxByteRate / 1000
          }
        })
        uploadKbps = Math.round(uploadSpeed * 1000) / 1000
      }

      return `${uploadKbps} ${this.$vuntangle.$t('kbps')}`
    },

    /**
     * Returns bridged to interface for bridged interfaces
     * @param {Object} intf - interface settings
     * @returns {String}
     */
    getBridgedTo(intf) {
      if (intf.configType !== 'BRIDGED' && intf.type !== 'BRIDGE') return '-'
      return intf.bridgedInterfaces?.map(intfId => this.interfaces.find(i => i.interfaceId === intfId)?.name)
    },

    /**
     * Returns the parent bridge for the interface
     * @param {Object} intf - interface settings
     * @returns {String}
     */
    getParentBridge(intf) {
      // loop interfaces and see if this interface id is set in any other interface 'bridgedInterfaces' property
      const bridgedInterfaces = this.interfaces.filter(i => i.bridgedInterfaces?.includes(intf.interfaceId))
      // if nothing found, return -
      if (bridgedInterfaces.length === 0) return '-'
      // else, return the name of the bridge
      return bridgedInterfaces[0].name
    },

    /**
     * Returns IPsec local gateway
     * @param {Object} intf - interface settings
     * @returns {String}
     */
    getIpsecLocalGateway(intf) {
      return intf.ipsec?.local.gateway || '-'
    },

    /**
     * Returns IPsec local networks
     * @param {Object} intf - interface settings
     * @returns {String}
     */
    getIpsecLocalNetworks(intf) {
      if (!intf.ipsec?.local?.networks) return '-'
      return intf.ipsec.local.networks.map(ntk => `${ntk.network}/${ntk.prefix}`)
    },

    /**
     * Returns IPsec remote gateway
     * @param {Object} intf - interface settings
     * @returns {String}
     */
    getIpsecRemoteGateway(intf) {
      return intf.ipsec?.remote.gateway || '-'
    },

    /**
     * Returns IPsec remote networks
     * @param {Object} intf - interface settings
     * @returns {String}
     */
    getIpsecRemoteNetworks(intf) {
      if (!intf.ipsec?.remote?.networks) return '-'
      return intf.ipsec.remote.networks.map(ntk => `${ntk.network}/${ntk.prefix}`)
    },

    /**
     * Returns IPsec bound to interface
     * @param {Object} intf - interface settings
     * @returns {String}
     */
    getIpsecBoundTo(intf) {
      if (intf.type !== 'IPSEC') return '-'

      if (intf.boundInterfaceId === 0) {
        return this.$vuntangle.$t('any_wan')
      }

      const boundInterfaceId = intf.boundInterfaceId
      const boundInterfaceStatus = this.interfacesStatus?.find(intf => intf.interfaceId === boundInterfaceId)

      if (boundInterfaceStatus) {
        const name = boundInterfaceStatus.name
        let address = null
        if (boundInterfaceStatus.ip4Addr) {
          if (Array.isArray(boundInterfaceStatus.ip4Addr) && boundInterfaceStatus.ip4Addr[0]) {
            address = boundInterfaceStatus.ip4Addr[0]
          }
        }
        return `${name}${address ? ' (' + address + ')' : ''}`
      }
      return '-'
    },

    /**
     * Returns IPsec authentication type
     * @param {Object} intf - interface settings
     * @returns {String}
     */
    getIpsecAuthType(intf) {
      if (!intf.ipsec?.authentication?.type) return '-'
      if (intf.ipsec.authentication.type === 'shared_secret') return this.$vuntangle.$t('shared_secret')
      return this.$vuntangle.$t('public_key')
    },

    // helpers

    /**
     * MFW-2063
     * return interface address source (e.g. static, dhcp)
     * addressSource is usually an array ['static', 'static']
     * this is collected via ubus call and populates addressSource array based on interface "proto"
     * for some bridged interfaces this addressSource might look like ['none', 'static', 'static']
     */
    getAddressSource(intfStatus) {
      const addressSource = intfStatus.addressSource
      // null or undefined
      if (!addressSource) return this.$vuntangle.$t('unknown')
      // not an array (expected a string)
      if (!Array.isArray(addressSource)) return addressSource
      // empty array
      if (!addressSource.length) return this.$vuntangle.$t('unknown')

      let sourceDisplay = null
      addressSource.forEach(source => {
        if (sourceDisplay && sourceDisplay !== 'none') {
          return
        }
        if (source !== 'none') {
          sourceDisplay = source
        }
      })
      return sourceDisplay || this.$vuntangle.$t('unknown')
    },
  },
}
