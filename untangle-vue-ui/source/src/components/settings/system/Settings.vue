<template>
  <appliance-system
    :system-settings="systemSettings"
    :company-name="companyName"
    :support-access-enabled="true"
    :all-wan-interface-names="enabledWanInterfaces"
    @save-settings="onSaveSettings"
    @refresh-settings="onRefreshSettings"
  />
</template>
<script>
  import { ApplianceSystem } from 'vuntangle'
  import settingsMixin from '../settingsMixin'

  export default {
    components: { ApplianceSystem },
    mixins: [settingsMixin],

    computed: {
      systemSettings: ({ $store }) => $store.getters['settings/systemSetting'],
      networkSetting: ({ $store }) => $store.getters['settings/networkSetting'],
      enabledWanInterfaces: ({ $store }) => $store.getters['settings/enabledWanInterfaces'],
      companyName() {
        return window?.rpc?.companyName || null
      },
    },
    created() {
      // update current system setting from store store
      this.$store.dispatch('settings/getSystemSettings', false)
      // get list of all wan interfaces which is used to show in the hostname interface selection
      this.$store.dispatch('settings/getEnabledInterfaces')
    },

    methods: {
      /*
       *Saving system changes with particular tab
       * This function commanly used saving all settings configurations
       */
      async onSaveSettings({ system, cb }) {
        this.$store.commit('SET_LOADER', true)
        const response = await this.$store
          .dispatch('settings/setSystemSettings', system)
          .finally(() => this.$store.commit('SET_LOADER', false))
        cb(response.success)
      },

      /* Handler to refresh settings */
      async onRefreshSettings() {
        this.$store.commit('SET_LOADER', true)

        const [response] = await Promise.all([
          this.$store.dispatch('settings/getSystemSettings', true),
          this.$store.dispatch('settings/getEnabledInterfaces'),
        ]).finally(() => {
          this.$store.commit('SET_LOADER', false)
        })
        if (response.success && !response.message) {
          this.$vuntangle.toast.add(this.$vuntangle.$t('refresh_settings_success'))
        } else {
          this.$vuntangle.toast.add(this.$vuntangle.$t('error_refresh_settings'), 'error')
        }
      },

      /**
       * Optional hook triggered on browser refresh.
       * Fetches updated system settings and updates the store.
       */
      onBrowserRefresh() {
        this.$store.dispatch('settings/getSystemSettings', true)
      },
    },
  }
</script>
