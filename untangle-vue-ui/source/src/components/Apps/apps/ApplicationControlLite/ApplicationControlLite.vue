<template>
  <application-control-lite
    :app-data="consolidatedAppData"
    :loading="loading"
    :sessions-data="sessionsData"
    :metrics-data="formattedMetrics"
    :reports="appReports"
    :settings="settings"
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
  import appStatusMixin from '../appStatusMixin'
  import Rpc from '@/util/Rpc'

  export default {
    name: 'ApplicationControlLiteApp',

    components: {
      ApplicationControlLite,
    },

    mixins: [appStatusMixin],

    props: {
      appData: { type: Object, default: null },
    },

    data() {
      return {
        appName: 'application-control-lite',
        loading: false,
        learnMoreUrl: null,
      }
    },

    computed: {
      /**
       * App display name (overrides mixin's appDisplayName)
       */
      appDisplayName() {
        return this.appData?.appProperties?.displayName || 'Application Control Lite'
      },

      /**
       * Consolidated app data including original appData and fetched/computed app-related data
       */
      consolidatedAppData() {
        return {
          ...this.appData,
          learnMoreUrl: this.learnMoreUrl,
        }
      },

      /**
       * Settings from Vuex store
       */
      settings() {
        return this.$store.getters['apps/getSettings'](this.appName)?.settings || {}
      },
    },

    created() {
      this.fetchLearnMoreUrl()
    },

    methods: {
      /**
       * Load app data from Vuex store
       */
      async loadAppData() {
        this.loading = true
        try {
          await this.$store.dispatch('apps/loadAppData', this.appName)
        } catch (err) {
          this.$vuntangle.toast.add(this.$t('failed_to_load_app_data'), 'error')
        } finally {
          this.loading = false
        }
      },

      /**
       * Save settings to backend
       */
      async saveSettings(newSettings) {
        this.loading = true
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
        } finally {
          this.loading = false
        }
      },

      /**
       * Toggle app state (start/stop)
       */
      async toggleAppState(enabled) {
        this.loading = true
        try {
          const newSettings = {
            ...this.settings,
            enabled,
          }

          await this.$store.dispatch('apps/setAppSettings', {
            appName: this.appName,
            settings: newSettings,
          })

          this.$vuntangle.toast.add(this.$t(enabled ? 'app_started' : 'app_stopped'), 'success')
        } catch (err) {
          console.error('Failed to toggle app state:', err)
          this.$vuntangle.toast.add(this.$t('failed_to_toggle_app'), 'error')
        } finally {
          this.loading = false
        }
      },

      /**
       * Remove app
       */
      async removeApp() {
        this.loading = true
        try {
          // Get app instance from appData prop
          if (!this.appData?.instance?.id) {
            throw new Error('App instance ID not found')
          }

          await Rpc.asyncData('rpc.appManager.destroy', this.appData.instance.id)
          this.$vuntangle.toast.add(this.$t('app_removed'), 'success')
          this.$router.push({ name: 'apps' })
        } catch (err) {
          console.error('Failed to remove app:', err)
          this.$vuntangle.toast.add(this.$t('failed_to_remove_app'), 'error')
        } finally {
          this.loading = false
        }
      },

      /**
       * Fetch learn more URL from backend
       */
      async fetchLearnMoreUrl() {
        try {
          // Call RPC to get URI with path
          const url = 'https://edge.arista.com/shop/Application-Control'
          this.learnMoreUrl = await Rpc.asyncData('rpc.uriManager.getUriWithPath', url)
        } catch (err) {
          this.learnMoreUrl = 'https://edge.arista.com/shop/Application-Control'
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
