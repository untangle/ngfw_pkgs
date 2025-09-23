<template>
  <settings-advanced ref="advanced" :is-expert-mode="isExpertMode" :settings="networkSettings">
    <template #actions="{ newSettings, isDirty }">
      <u-btn :min-width="null" :disabled="!isDirty" @click="onSaveSettings(newSettings)">{{ $t('save') }}</u-btn>
    </template>
  </settings-advanced>
</template>

<script>
  import { SettingsAdvanced } from 'vuntangle'
  import settingsMixin from '../settingsMixin'

  export default {
    components: { SettingsAdvanced },
    mixins: [settingsMixin],

    computed: {
      /* network settings from the store */
      networkSettings: ({ $store }) => $store.getters['settings/networkSetting'],
      /** Gets the expert mode status from the settings store */
      isExpertMode: ({ $store }) => $store.getters['settings/isExpertMode'],
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

      async onSaveSettings(advancedSettings) {
        this.$store.commit('SET_LOADER', true)
        await Promise.all([this.$store.dispatch('settings/setNetworkSettingV2', advancedSettings)]).finally(() => {
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
