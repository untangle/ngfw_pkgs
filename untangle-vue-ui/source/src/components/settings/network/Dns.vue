<template>
  <settings-dns
    ref="dns"
    :settings="dnsSettings"
    :enable-export-settings="true"
    :enable-import-settings="true"
    :enable-export-csv="false"
  >
    <template #actions="{ newSettings, isDirty }">
      <u-btn :min-width="null" :disabled="!isDirty" @click="onSaveSettings(newSettings)">{{ $t('save') }}</u-btn>
    </template>
  </settings-dns>
</template>
<script>
  import { cloneDeep } from 'lodash'
  import { SettingsDns } from 'vuntangle'
  import settingsMixin from '../settingsMixin'

  export default {
    components: { SettingsDns },
    mixins: [settingsMixin],

    computed: {
      /**
       * dnsSettings is retrieved from the store.
       *
       * @returns {Object} dnsSettings - The DNS settings object from the store.
       * @property {Array} dnsSettings.localServers - List of local DNS servers.
       * @property {Array} dnsSettings.staticEntries - List of static DNS entries.
       */
      dnsSettings: ({ $store }) => $store.getters['settings/dnsSettings'],
      // the network settings from the store
      networkSettings: ({ $store }) => $store.getters['settings/networkSetting'],
    },

    created() {
      this.fetchSettings(false)
    },
    methods: {
      /**
       * Fetches the settings and updates the store.
       * If refetch is true, it forces a re-fetch of the settings.
       * @param {boolean} refetch - Whether to force a re-fetch of the settings.
       */
      async fetchSettings(refetch) {
        await this.$store.dispatch('settings/getNetworkSettings', refetch)
      },

      async onSaveSettings(newDnsSettings) {
        this.$store.commit('SET_LOADER', true)
        const networkSettingsCopy = cloneDeep(this.networkSettings)
        networkSettingsCopy.dnsSettings = newDnsSettings
        await Promise.all([this.$store.dispatch('settings/setNetworkSettingV2', networkSettingsCopy)]).finally(() => {
          this.$store.commit('SET_LOADER', false)
        })
      },

      /**
       * Optional hook triggered on browser refresh.
       * Fetches updated network settings and updates the store.
       */
      onBrowserRefresh() {
        this.fetchSettings(true)
      },
    },
  }
</script>
