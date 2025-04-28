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

    /** isDisabledv6 */
    isDisabledv6: ({ intf }) => intf.v6ConfigType === 'DISABLED',

    /** isAutov6 */
    isAutov6: ({ intf }) => intf.v6ConfigType === 'AUTO',

    /** RouterWarning */
    showRouterWarning: ({ intf }) => intf.v6StaticPrefixLength !== 64,

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

    /** shows bound to options for specific types and `configType` not `BRIDGED` */
    // showBoundToOptions: ({ type, intf }) =>
    //   ['OPENVPN', 'WIREGUARD', 'IPSEC'].includes(type) && intf.configType !== 'BRIDGED',

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

    /** returns interfaces options to be bridged */
    bridgedToOptions: ({ intf, interfaces }) => {
      const record = intf

      const fields = []
      interfaces.forEach(intf => {
        if (
          intf.interfaceId === record.interfaceId ||
          intf.bridged !== false ||
          intf.disabled !== false ||
          intf.configType !== 'ADDRESSED'
        ) {
          return
        }
        fields.push(intf)
      })
      return fields
        .slice()
        .sort((a, b) => a.name.localeCompare(b.name))
        .map(i => ({ value: i.interfaceId, text: i.name }))
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
