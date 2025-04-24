import { CONFIG_TYPE } from '../../../shared/SettingsInterface/components/constants'

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
      const connected = this.$t(intf.enabled ? (status && status.connected ? 'connected' : 'disconnected') : 'disabled')
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
      if (!status?.ip4Addr?.length && !intf.v4StaticAddress) return '-'

      if (status?.ip4Addr?.length) {
        return `${status.ip4Addr[0]}/${status.v4PrefixLength || ''}`
      }

      if (intf.v4StaticAddress) {
        if (intf.v4ConfigType === CONFIG_TYPE.DISABLED) {
          return this.$vuntangle.$t('disabled')
        }
        const prefix = intf.v4StaticPrefix || ''
        return `${intf.v4StaticAddress}/${prefix}`
      }

      return ''
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
