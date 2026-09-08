<template>
  <interfaces
    :interfaces="interfaces"
    :interfaces-status="interfacesStatus"
    :features="features"
    @refresh="onRefresh"
    @refresh-status="onInterfaceStatusRefresh"
    @add-interface="onAddInterface"
    @edit-interface="onEditInterface"
    @delete-interface="onDelete"
    @get-arp-data="getInterfaceArp"
    @set-wireless-intf-logs="setWirelessIntfLogs"
    @set-remap-interfaces="setRemappedInterfaces"
  />
</template>
<script>
  import { Interfaces } from 'vuntangle'
  import settingsMixin from '../settingsMixin'
  import interfaceMixin from './interfaceMixin'
  import { directRpcCall, rpcCall } from '@/util/rpcHelpers'

  export default {
    components: { Interfaces },
    mixins: [interfaceMixin, settingsMixin],
    data: () => ({
      // all interfaces status, async fetched
      interfacesStatus: [],
      arpEntriesData: [],
      wirelessLogs: '',
      features: {
        hasWireguard: false,
        hasOpenVpn: false,
        hasStatusTable: true,
        hasNoIpsecTunnel: true,
        hasNoExportCsv: true,
      },
    }),

    computed: {
      // interfaces filered and grouped (by category)
      interfaces({ $store }) {
        return $store.getters['settings/networkSetting'].interfaces || []
      },
    },

    created() {
      this.$store.dispatch('settings/getNetworkSettings')
    },

    mounted() {
      this.getInterfacesStatus()
    },

    methods: {
      async getInterfacesStatus() {
        this.$store.commit('SET_LOADER', true)
        try {
          const fallback = Array.isArray(this.interfacesStatus) ? this.interfacesStatus : []
          const result = await rpcCall(window.rpc?.networkManager?.getAllInterfacesStatusV2, [], { fallback })
          this.interfacesStatus = Array.isArray(result) ? result : []
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      /**
       * Fetches ARP entries for the given symbolic device.
       * If no device is provided, clears the arpEntriesData.
       *
       * @param {string} symbolicDev - The symbolic device identifier.
       * @param {function} callback - Optional callback to handle the result.
       */
      async getInterfaceArp(symbolicDev, callback) {
        if (!symbolicDev) {
          this.arpEntriesData = []
          return
        }

        const result = await rpcCall(window.rpc?.networkManager?.getStatus, ['INTERFACE_ARP_TABLE', symbolicDev], {
          fallback: '',
        })
        if (result == null) return
        const connections = []
        const macAddressList = []

        result.split('\n').forEach(row => {
          if (row.trim() === '') return

          let address = null
          let macAddress = null

          row
            .trim()
            .split(/\s+/)
            .forEach((item, index) => {
              if (index === 0) {
                address = item
              } else if (index === 2) {
                macAddress = item
              }
            })

          if (macAddress) macAddressList.push(macAddress)

          connections.push({
            address,
            macAddress,
            vendor: null,
          })
        })

        if (macAddressList.length > 0) {
          const list = { javaClass: 'java.util.LinkedList', list: macAddressList }
          const lookUpResult = directRpcCall(window.rpc?.networkManager?.lookupMacVendorList, [list], { fallback: {} })
          const macVendorMap = lookUpResult?.map || {}

          connections.forEach(conn => {
            if (macVendorMap[conn.macAddress]) {
              conn.vendor = macVendorMap[conn.macAddress]
            }
          })
        }

        this.arpEntriesData = connections
        callback?.(connections) // Send back result
      },

      setWirelessIntfLogs(intfc, callback) {
        if (intfc?.type === 'WIFI') {
          this.wirelessLogs = directRpcCall(window.rpc?.networkManager?.getLogFile, [intfc.device], { fallback: '' })
        } else {
          this.wirelessLogs = ''
        }

        callback?.(this.wirelessLogs)
      },

      /** Updates the remapped interfaces and invokes a callback with the response. */
      async setRemappedInterfaces(interfaces) {
        this.$store.commit('SET_LOADER', true)
        const response = await this.$store
          .dispatch('settings/setInterfaces', interfaces)
          .finally(() => this.$store.commit('SET_LOADER', false))
        if (response?.success) {
          this.$vuntangle.toast.add(this.$t('interfaces_remapped_successfully'))
          this.getInterfacesStatus()
        } else {
          this.$vuntangle.toast.add(this.$t('rolled_back_settings', [response.message]))
        }
      },

      async onRefresh() {
        this.$store.commit('SET_LOADER', true)
        await this.$store.dispatch('settings/getInterfaces').finally(() => this.$store.commit('SET_LOADER', false))
        this.getInterfacesStatus()
      },

      async onInterfaceStatusRefresh(device) {
        if (!device) return

        const result = await rpcCall(window.rpc?.networkManager?.getInterfaceStatusV2, [device], { fallback: null })
        if (!result || !Array.isArray(this.interfacesStatus)) return

        this.interfacesStatus = this.interfacesStatus.map(intf => {
          if (intf.device === device) {
            return { ...intf, ...result }
          }
          return intf
        })
      },

      /**
       * Handle add interface
       *
       * @param {string} type intf type to add
       */
      onAddInterface(type) {
        this.$router.push(`/settings/network/interfaces/add/${type}`)
      },

      /**
       * handle edit interface
       *
       * @param {string} device intf Id to edit
       */
      onEditInterface(device) {
        this.$router.push(`/settings/network/interfaces/${device}`)
      },

      /**
       * Removes the interface
       *
       * @param deviceId device id of the interface to delete
       */
      onDelete(deviceId) {
        const intf = this.interfaces.find(intf => intf.device === deviceId)
        if (intf) {
          this.deleteInterfaceHandler(intf)
        }
      },

      /**
       * Optional hook triggered on browser refresh.
       * Fetches updated network settings and updates the store.
       */
      onBrowserRefresh() {
        this.$store.dispatch('settings/getNetworkSettings', true)
      },
    },
  }
</script>
