<template>
  <interfaces
    :interfaces="interfaces"
    :interfaces-status="interfacesStatus"
    :features="features"
    @refresh="onRefresh"
    @add-interface="onAddInterface"
    @edit-interface="onEditInterface"
    @delete-interface="onDelete"
  />
</template>
<script>
  import { Interfaces } from 'vuntangle'
  import interfaceMixin from './interfaceMixin'

  export default {
    components: { Interfaces },
    mixins: [interfaceMixin],
    data: () => ({
      // all interfaces status, async fetched
      interfacesStatus: undefined,
      features: {
        hasWireguard: false,
        hasOpenVpn: false,
        hasBridged: false,
      },
    }),

    computed: {
      // interfaces filered and grouped (by category)
      interfaces() {
        return this.$store.getters['settings/interfaces']
      },
    },

    mounted() {
      this.setFeatures()
      this.getInterfacesStatus()
    },

    methods: {
      setFeatures() {
        this.features.hasBridged = true
      },

      async getInterfacesStatus() {
        const interfaces = await window.rpc.networkManager.getNetworkSettings().interfaces.list
        const intfStatusList = await window.rpc.networkManager.getInterfaceStatus()

        const interfaceWithStatus = interfaces.map(intf => {
          const status = intfStatusList.list.find(j => j.interfaceId === intf.interfaceId)
          return { ...intf, ...status }
        })
        this.interfacesStatus = interfaceWithStatus
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
