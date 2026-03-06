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
        appName: this.appData?.appName || 'application-control-lite',
        loading: false, // TODO Check uasage and remove if not needed
        learnMoreUrl: null,
        powerLoading: false, // Track power state loading separately
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
        const powerState = {
          ...(this.powerState || {}),
          power: this.powerLoading, // Merge loading state
        }
        return {
          ...this.appData,
          learnMoreUrl: this.learnMoreUrl,
          powerState,
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
      this.loadAppSettings()
    },

    methods: {
      /**
       * Load app data from Vuex store
       */
      async loadAppSettings() {
        this.loading = true
        this.$store.commit('SET_LOADER', true)
        await this.$store.dispatch('apps/loadAppData', this.appName).finally(() => {
          this.loading = false
          this.$store.commit('SET_LOADER', false)
        })
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
       * @param {boolean} enabled - Target state (true = starting, false = stopping)
       */
      async toggleAppState(enabled) {
        if (!this.appInstance) {
          console.error('Cannot toggle - app instance not cached')
          return
        }

        this.cachedTargetState = enabled ? 'RUNNING' : 'INITIALIZED'
        this.powerLoading = true
        console.log(`Toggling app state to ${enabled ? 'ON' : 'OFF'}...`)
        try {
          const rpcMethod = enabled ? 'start' : 'stop'

          await new Promise((resolve, reject) => {
            this.appInstance[rpcMethod]((ex, res) => {
              if (ex || res?.code) {
                reject(ex || new Error(res?.message || `Failed to ${rpcMethod} app`))
              } else {
                resolve(res)
              }
            })
          })

          // Refresh runState from cached instance
          this.refreshRunState()
        } finally {
          this.powerLoading = false
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
