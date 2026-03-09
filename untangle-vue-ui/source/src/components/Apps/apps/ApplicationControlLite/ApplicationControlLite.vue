<template>
  <application-control-lite
    :settings="settings"
    :app-data="consolidatedAppData"
    :sessions-data="sessionsData"
    :metrics-data="formattedMetrics"
    :reports="appReports"
    @toggle-state="toggleAppState"
    @remove-app="removeApp"
  >
    <!-- Custom action buttons slot -->
    <template #actions="{ newSettings, isDirty }">
      <u-btn class="mr-2" @click="refreshData">
        {{ $t('refresh') }}
      </u-btn>
      <u-btn :disabled="!isDirty" @click="saveSettings(newSettings)">
        {{ $t('save') }}
      </u-btn>
    </template>
  </application-control-lite>
</template>

<script>
  import { ApplicationControlLite } from 'vuntangle'
  import appMixin from '../appMixin'
  import Rpc from '@/util/Rpc'

  export default {
    name: 'ApplicationControlLiteApp',

    components: {
      ApplicationControlLite,
    },

    mixins: [appMixin],

    props: {
      appData: { type: Object, default: null },
    },

    data() {
      return {
        appName: this.appData?.appName || 'application-control-lite',
        learnMoreUrl: undefined,
      }
    },

    computed: {
      /**
       * Application display name, derived from appData properties or defaults to a static string
       * @param param0 - Destructured appData from component's props
       * @returns {string} Display name for the application
       */
      appDisplayName: ({ appData }) => appData?.appProperties?.displayName || 'Application Control Lite',

      /**
       * Consolidates app data with additional properties like learnMoreUrl and powerState
       * @param param0 - Destructured properties including appData, learnMoreUrl, and powerState
       * @returns {Object} Consolidated app data object to be passed to the component
       */
      consolidatedAppData: ({ appData, learnMoreUrl, powerState }) => {
        return {
          ...appData,
          learnMoreUrl,
          powerState: powerState || {},
        }
      },

      /**
       * Gets the app settings from the Vuex store using the appName as a key
       * @param param0 - appName from the component's data and $store for accessing Vuex getters
       * @returns {Object} Sessions data object
       */
      settings: ({ $store, appName }) => $store.getters['apps/getSettings'](appName)?.settings || {},
    },

    created() {
      this.fetchLearnMoreUrl()
      this.loadAppSettings()
    },

    methods: {
      /**
       * Fetches the "Learn More" URL for the application from the backend via RPC
       * If the RPC call fails, it falls back to a default URL
       */
      async fetchLearnMoreUrl() {
        const defaultUrl = 'https://edge.arista.com/shop/Application-Control'
        this.learnMoreUrl = await Rpc.asyncData('rpc.uriManager.getUriWithPath', defaultUrl).catch(() => defaultUrl)
      },

      /**
       * Loads the app settings by dispatching a Vuex action to fetch data from the backend.
       */
      async loadAppSettings() {
        this.$store.commit('SET_LOADER', true)
        await this.$store.dispatch('apps/loadAppData', this.appName).finally(() => {
          this.$store.commit('SET_LOADER', false)
        })
      },

      /**
       * Save settings to backend
       */
      async saveSettings(newSettings) {
        try {
          await this.$store.dispatch('apps/setAppSettings', {
            appName: this.appName,
            settings: newSettings,
          })
          this.$vuntangle.toast.add(this.$t('settings_saved'), 'success')
          await this.loadAppData()
        } catch (err) {
          console.error('Failed to save settings:', err)
          this.$vuntangle.toast.add(this.$t('failed_to_save_settings'), 'error')
        }
      },

      /**
       * Refresh data (reload settings)
       * Metrics are automatically updated via MetricsPollingService
       */
      refreshData() {
        this.loadAppData()
      },
    },
  }
</script>
