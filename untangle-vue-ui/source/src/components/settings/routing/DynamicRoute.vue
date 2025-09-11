<template>
  <settings-dynamic ref="dynamicRoutes" :settings="dynamicRoutingSettings" @refresh="onRefresh">
    <template #actions="{ newSettings, isDirty }">
      <u-btn :min-width="null" :disabled="!isDirty" @click="onSaveSettings(newSettings)">{{ $t('save') }}</u-btn>
    </template>
  </settings-dynamic>
</template>
<script>
  import { SettingsDynamic } from 'vuntangle'
  import settingsMixin from '../settingsMixin'

  export default {
    components: { SettingsDynamic },
    mixins: [settingsMixin],

    data: () => ({
      dynamicRoutingSettings: undefined,
    }),
    created() {
      const routingEnabled = window.rpc.networkManager.getNetworkSettings().dynamicRoutingSettings.enabled
      if (routingEnabled) {
        this.onRefresh()
      }
    },
    methods: {
      async onRefresh() {
        this.$store.commit('SET_LOADER', true)
        const [tableStatus, bgpStatus, ospfStatus] = await Promise.all([
          window.rpc.networkManager.getStatus('DYNAMIC_ROUTING_TABLE', null),
          window.rpc.networkManager.getStatus('DYNAMIC_ROUTING_BGP', null),
          window.rpc.networkManager.getStatus('DYNAMIC_ROUTING_OSPF', null),
        ]).finally(() => {
          this.$store.commit('SET_LOADER', false)
        })

        this.dynamicRoutingSettings = {
          tableStatus,
          bgpStatus,
          ospfStatus,
        }
      },
      // TODO will be implemented in API intergration ticket
      // async onSaveSettings(newSettings) {
      //   this.$store.commit('SET_LOADER', true)
      //   await this.$store
      //     .dispatch('settings/setNetworkSettingV2', newSettings)
      //     .finally(() => this.$store.commit('SET_LOADER', false))
      // },

      /**
       * Optional hook triggered on browser refresh.
       * Fetches updated settings.
       */
      onBrowserRefresh() {
        this.onRefresh()
      },
    },
  }
</script>
