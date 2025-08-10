<template>
  <interfaces
    :interfaces="interfaces"
    :interfaces-status="interfacesStatus"
    :features="features"
    @refresh="onRefresh"
    @add-interface="onAddInterface"
    @edit-interface="onEditInterface"
    @delete-interface="onDelete"
    @get-arp-data="getInterfaceArp"
    @set-wireless-intf-logs="setWirelessIntfLogs"
  />
</template>
<script>
  import { Interfaces } from 'vuntangle'
  import interfaceMixin from './interfaceMixin'
  import Rpc from '@/util/Rpc'

  export default {
    components: { Interfaces },
    mixins: [interfaceMixin],
    data: () => ({
      // all interfaces status, async fetched
      interfacesStatus: undefined,
      arpEntriesData: [],
      wirelessLogs: '',
      features: {
        hasWireguard: false,
        hasOpenVpn: false,
        hasStatusTable: true,
      },
    }),

    computed: {
      // interfaces filered and grouped (by category)
      interfaces() {
        return this.$store.getters['settings/networkSetting'].interfaces
      },
    },

    created() {
      this.$store.dispatch('settings/getNetworkSettings') // update interfaces in the store
    },

    mounted() {
      this.getInterfacesStatus()
    },

    methods: {
      async getInterfacesStatus() {
        const intfStatusList = await window.rpc.networkManager.getAllInterfacesStatusV2()
        this.interfacesStatus = intfStatusList
      },

      async getInterfaceArp(symbolicDev, callback) {
        if (!symbolicDev) {
          this.arpEntriesData = []
          return
        }

        const result = await Rpc.asyncData('rpc.networkManager.getStatus', 'INTERFACE_ARP_TABLE', symbolicDev)
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
          const lookUpResult = await Rpc.directData('rpc.networkManager.lookupMacVendorList', list)
          const macVendorMap = lookUpResult.map || {}

          connections.forEach(conn => {
            if (macVendorMap[conn.macAddress]) {
              conn.vendor = macVendorMap[conn.macAddress]
            }
          })
        }

        this.arpEntriesData = connections
        callback?.(connections) // Send back result
      },
      async setWirelessIntfLogs(intfc, callback) {
        if (intfc.type === 'WIFI') {
          this.wirelessLogs = await window.rpc.networkManager.getLogFile(intfc.device)
        } else {
          this.wirelessLogs = ''
        }

        callback?.(this.wirelessLogs)
      },

      onRefresh() {
        this.$store.commit('SET_LOADER', true)
        this.$store.dispatch('settings/getInterfaces')
        this.getInterfacesStatus()
        this.$store.commit('SET_LOADER', false)
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
    },
  }
</script>
