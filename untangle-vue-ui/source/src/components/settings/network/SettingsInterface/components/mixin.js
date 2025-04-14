export default {
  computed: {
    // just a shortcut to type as is reused a lot
    type: ({ intf }) => intf.type,

    // /** shows `wan` checkbox  if ADDRESSED */
    // showWan: ({ intf, type }) =>
    //   (intf.configType === 'ADDRESSED' || ['WWAN', 'VLAN', 'WIREGUARD', 'OPENVPN', 'IPSEC', 'BRIDGE'].includes(type)) &&
    //   !intf.management,

    /** disable `wan` */
    disableWan: ({ type }) => ['WWAN', 'VLAN', 'WIREGUARD', 'OPENVPN', 'IPSEC', 'BRIDGE'].includes(type),

    /** is WAN */
    isAddressed: ({ intf }) => intf.configType === 'ADDRESSED',
    /** is autov4 */
    isAutov4: ({ intf }) => intf.v4ConfigType === 'AUTO',
    /** is PPPoE */
    isPPPOEv4: ({ intf }) => intf.v4ConfigType === 'PPPOE',

    /** is v6 configType   */
    isStaticv6: ({ intf }) => intf.v6ConfigType === 'STATIC',

    /** shows `natEgress` checkbox */
    showNatEgress: ({ intf, type }) =>
      intf.wan &&
      type !== 'IPSEC' &&
      (intf.configType === 'ADDRESSED' || ['WWAN', 'VLAN', 'WIREGUARD', 'OPENVPN'].includes(type)),

    /** shows delete interface button */
    showDelete: ({ intf, type, isBridgedInterface }) =>
      intf.device && !['NIC', 'WIFI', 'WWAN'].includes(type) && !isBridgedInterface,

    /** shows Ipv4, Ipv6 for ADDRESSED config types */
    showAddressed: ({ intf, type }) => {
      return (
        (intf.configType === 'ADDRESSED' || type === 'BRIDGE') &&
        !['OPENVPN', 'WIREGUARD', 'WWAN', 'IPSEC'].includes(intf.type)
      )
    },

    /** shows interface config type based on interface type */
    showConfigType: ({ type }) => !['WWAN', 'OPENVPN', 'WIREGUARD', 'IPSEC', 'VLAN', 'BRIDGE'].includes(type),

    /** shows bound to options for specific types and `configType` not `BRIDGED` */
    showBoundToOptions: ({ type, intf }) =>
      ['OPENVPN', 'WIREGUARD', 'IPSEC'].includes(type) && intf.configType !== 'BRIDGED',

    /** shows bridged to options only if `configType` is `BRIDGED` */
    isBridged: ({ intf }) => intf.configType === 'BRIDGED',

    /** show tabs */
    showTabs: ({ tabs, intf, type, isBridgedInterface }) => {
      return (
        (tabs || []).length &&
        !(intf.configType === 'BRIDGED' && type !== 'WIFI' && type !== 'BRIDGE') &&
        !isBridgedInterface
      )
    },

    /** show DHCP Tab only if ADDRESSED interface is not WAN */
    showDhcp: ({ intf, isAddressed }) => isAddressed && !intf.isWan,

    /** show VRRP Tab for NIC, VLAN types and interface `ADDRESSED` */
    showVrrp: ({ intf, type, features }) =>
      features.hasVrrp &&
      (type === 'BRIDGE' || (['NIC', 'VLAN'].includes(type) && intf.configType === 'ADDRESSED' && !intf.management)),

    /** show NIC Options only if interface is `NIC` and `ADDRESSED` */
    showNICOptions: ({ intf, status }) =>
      intf.type === 'NIC' && intf.configType === 'ADDRESSED' && status?.ethSpeed > 0,

    /** show Qos Tab only for WANs and exclude specified interface types */
    // showQos: ({ intf }) => intf.wan && !['OPENVPN', 'WIREGUARD', 'WIFI', 'WWAN', 'IPSEC'].includes(intf.type),

    /** retuns interface names used for validation against duplicate names */
    interfaceNames: ({ intf, interfaces }) =>
      interfaces.filter(i => i.interfaceId !== intf.interfaceId).map(i => i.name),

    /**
     * interface name vaidation rules
     * - required, max 10 alphas
     * - no spaces
     * - unique among the all existing interfaces names
     */
    interfaceNameRules: ({ $vuntangle, interfaceNames }) => ({
      required: true,
      max: 10,
      regex: [
        /^[^!#$%^&]+$/,
        $vuntangle.$t(`This field can have alphanumerics or special characters other than ! # $ % ^ &`),
      ],
      unique_insensitive: { list: interfaceNames, message: $vuntangle.$t(`Interface name already exists.`) },
    }),

    /**
     * vaidation rules for the localGateway radio group
     */
    localGatewayRules: ({ ipsec, selectedWan }) => ({
      required: true,
      conflicting_any_gateways: { local: ipsec.local.gateway, remote: ipsec.remote.gateway },
      disconnected_wan: { boundWan: selectedWan },
      validate_gateways: { local: ipsec.local.gateway, remote: ipsec.remote.gateway },
    }),

    /**
     * vaidation rules for the remoteGateway radio group
     */
    remoteGatewayRules: ({ ipsec }) => ({
      required: true,
      conflicting_any_gateways: { local: ipsec.local.gateway, remote: ipsec.remote.gateway },
      validate_gateways: { local: ipsec.local.gateway, remote: ipsec.remote.gateway },
    }),

    /**
     * boundInterfaceId vaidation rules
     */
    boundInterfaceIdRules: ({ interfaces, intf }) => {
      return {
        required: true,
        vlan_duplicate: {
          interfaces,
          interfaceId: intf.interfaceId, // current interface id
          boundInterfaceId: null, // passed by field value
          vlanId: intf.vlanid,
        },
      }
    },

    /**
     * vlanID vaidation rules
     */
    vlanIdRules: ({ interfaces, intf }) => {
      return {
        required: true,
        numeric: true,
        min_value: 1,
        max_value: 4094,
        vlan_duplicate: {
          interfaces,
          interfaceId: intf.interfaceId, // current interface id
          boundInterfaceId: intf.boundInterfaceId,
          vlanId: null, // passed by field value
        },
      }
    },

    /**
     * return possible config types for an interface
     * - for WANs it's only `ADDRESSED`
     * - otherwise it's `ADDRESSED` or `BRIDGED`
     */
    configTypes: ({ $vuntangle, intf }) => {
      return [
        { text: $vuntangle.$t('addressed'), value: 'ADDRESSED' },
        ...(!intf.wan && !intf.management ? [{ text: $vuntangle.$t('bridged'), value: 'BRIDGED' }] : []),
      ]
    },

    /** returns interfaces options to be bound, based on interface type */
    boundToOptions: ({ intf, type, getBoundableNicsOptions, getBoundableInterfacesOptions }) => {
      if (type === 'VLAN') return getBoundableNicsOptions
      if (['OPENVPN', 'WIREGUARD', 'IPSEC'].includes(type)) {
        let includeAnyWan = true
        if (type === 'WIREGUARD' && intf.wireguardType === 'TUNNEL') includeAnyWan = false
        return getBoundableInterfacesOptions(includeAnyWan)
      }
      return []
    },

    // TODO
    /** returns interfaces options to be bridged */
    bridgedToOptions: ({ intf, interfaces }) => {
      // let filter = []
      // if (intf.configType === 'BRIDGE') {
      //   const alreadyBridgedToSet = new Set()
      //   interfaces
      //     .filter(i => i.interfaceId !== intf.interfaceId && i.configType === 'BRIDGE')
      //     .forEach(i => i.bridgedInterfaces.forEach(i => alreadyBridgedToSet.add(i)))
      //   filter = interfaces.filter(
      //     i =>
      //       i.interfaceId !== intf.interfaceId &&
      //       ['NIC', 'VLAN', 'WIFI'].includes(i.type) &&
      //       !i.wan &&
      //       !alreadyBridgedToSet.has(i.interfaceId),
      //   )
      // } else {
      //   filter = interfaces.filter(i => i.interfaceId !== intf.interfaceId && i.configType === 'ADDRESSED' && !i.wan)
      // }
      // if (!filter.length) return []
      console.log('intf :', intf)
      return interfaces.map(i => ({ value: i.interfaceId, text: i.name }))
    },

    /**
     * Returns select options available for boundable interfaces having conditions:
     * - interface type is `NIC` or `WWAN`
     * - interface is `wan`
     * - interface is `enabled`
     *
     * passing `includeAnyWan` true, adds `Any WAN` option
     */
    getBoundableInterfacesOptions() {
      return (includeAnyWan = false) => {
        const enabledWans = this.interfaces.filter(
          intf => ['NIC', 'WWAN'].includes(intf.type) && intf.wan && intf.enabled,
        )
        const options = enabledWans.map(wan => ({ value: wan.interfaceId, text: wan.name }))
        if (includeAnyWan) options.unshift({ value: 0, text: this.$vuntangle.$t('any_wan') })
        return options
      }
    },

    /**
     * Returns select options for all available NICs interfaces
     * used for VLAN bound interface
     * BUG? should NICs be `wan` & `enabled`
     */
    getBoundableNicsOptions: ({ interfaces }) => {
      const nics = interfaces.filter(intf => intf.type === 'NIC' || intf.type === 'BRIDGE')
      return nics.map(nic => ({ value: nic.interfaceId, text: nic.name }))
    },

    /**
     * checks if the given interface is part of a bridge or not
     *
     * @param intf
     * @param interfaces
     * @returns {boolean}
     */
    isBridgedInterface: ({ intf, interfaces }) => {
      const bridgedInterface = interfaces.filter(i => i.bridgedInterfaces?.includes(intf.interfaceId))
      return bridgedInterface.length > 0
    },
  },
}
