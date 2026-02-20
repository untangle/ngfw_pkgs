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
      appData: {
        type: Object,
        default: null,
      },
    },

    data() {
      return {
        appName: 'application-control-lite',
        loading: false,
        sessionsData: this.initializeSessionsData(),
        metrics: {},
        metricsPollingInterval: null,
        learnMoreUrl: null,
      }
    },

    computed: {
      /**
       * App display name for reports filtering
       * Required by appStatusMixin
       */
      appDisplayName() {
        return this.appData?.appProperties?.displayName || 'Application Control Lite'
      },

      /**
       * Consolidated app data including original appData and fetched/computed app-related data
       * Does NOT include transient UI state like 'loading'
       */
      consolidatedAppData() {
        return {
          // Original appData from parent (policyId, appName, license, instance, appProperties, appMetrics, iconPath)
          ...this.appData,
          // Additional fetched data about the app
          learnMoreUrl: this.learnMoreUrl,
        }
      },

      /**
       * Settings from Vuex store
       */
      settings() {
        return this.$store.getters['apps/getSettings'](this.appName)?.settings || {}
      },

      /**
       * Formatted metrics for the metrics grid
       * Metrics from backend already include displayUnits in the value
       */
      formattedMetrics() {
        if (!this.metrics) return []

        return Object.entries(this.metrics).map(([key, value]) => ({
          key,
          value,
          // No formatter needed - value already includes units from backend
          formatter: null,
        }))
      },
    },

    async created() {
      await this.loadAppData()
      // Fetch learn more URL from backend
      await this.fetchLearnMoreUrl()
      // Start metrics polling (fetches real data from backend every 10 seconds)
      this.startMetricsPolling()
    },

    beforeDestroy() {
      this.stopMetricsPolling()
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
          // Call RPC to get URI with path (matching ExtJS pattern)
          const url = 'https://edge.arista.com/shop/Application-Control'
          this.learnMoreUrl = await Rpc.asyncData('rpc.uriManager.getUriWithPath', url)
        } catch (err) {
          this.learnMoreUrl = 'https://edge.arista.com/shop/Application-Control'
        }
      },

      /**
       * Refresh data (reload settings and metrics)
       */
      refreshData() {
        this.loadAppData()
        this.fetchMetrics()
      },

      /**
       * Fetch metrics from backend (matching ExtJS pattern)
       * ExtJS: app.getMetrics() returns List<AppMetric>
       * Each metric has: name, displayName, value, displayUnits, expert
       */
      async fetchMetrics() {
        try {
          // Get the app instance through appManager (matching ExtJS pattern)
          const app = await Rpc.asyncData('rpc.appManager.app', this.appName)

          if (!app) {
            console.warn('App instance not available')
            return
          }

          // Get metrics list from app instance (matching ExtJS: app.getMetrics())
          const metricsResult = await Rpc.asyncData(app, 'getMetrics')

          if (!metricsResult || !metricsResult.list) {
            console.warn('No metrics returned from app')
            return
          }

          // Check if expert mode is enabled (matching ExtJS pattern)
          const expertMode = await window.rpc.isExpertMode

          // Find the "live-sessions" metric for the sessions chart
          // ExtJS: metrics.list.filter(m => m.name === 'live-sessions')[0].value
          const liveSessionsMetric = metricsResult.list.find(m => m.name === 'live-sessions')
          const liveSessionsValue = liveSessionsMetric ? liveSessionsMetric.value : 0

          // Transform metrics array to object format for UAppStatusMetrics
          // ExtJS filters expert metrics unless in expert mode
          const metricsObj = {}
          metricsResult.list.forEach(metric => {
            // Skip expert-only metrics unless in expert mode
            if (metric.expert && !expertMode) {
              return
            }

            // Use displayName as key (translated)
            const key = metric.displayName
            // Concatenate value with displayUnits if present
            const value = metric.value + (metric.displayUnits ? ' ' + metric.displayUnits : '')
            metricsObj[key] = value
          })
          this.metrics = metricsObj

          // Add new data point to sessions chart (matching ExtJS addPoint behavior)
          this.addSessionsDataPoint(liveSessionsValue)

          console.log('Fetched metrics from backend:', this.metrics)
        } catch (err) {
          console.error('Failed to fetch metrics:', err)
        }
      },

      /**
       * Start metrics polling (every 10 seconds)
       */
      startMetricsPolling() {
        this.fetchMetrics()
        this.metricsPollingInterval = setInterval(() => {
          this.fetchMetrics()
        }, 10000)
      },

      /**
       * Stop metrics polling
       */
      stopMetricsPolling() {
        if (this.metricsPollingInterval) {
          clearInterval(this.metricsPollingInterval)
          this.metricsPollingInterval = null
        }
      },

      /**
       * Initialize sessions chart data with 7 points (matching ExtJS pattern)
       * ExtJS creates 7 points from -60 seconds to now, all with value 0
       * This ensures the time axis is visible from the start
       */
      initializeSessionsData() {
        const data = []
        const now = Date.now()
        // Round to nearest second (matching ExtJS: Math.round(time/1000) * 1000)
        const roundedNow = Math.round(now / 1000) * 1000

        // Create 7 points: -60s, -50s, -40s, -30s, -20s, -10s, 0s
        for (let i = -6; i <= 0; i++) {
          data.push({
            timestamp: roundedNow + i * 10000, // 10 seconds apart
            sessions: 0,
          })
        }

        return data
      },

      /**
       * Add a new data point to sessions chart and maintain rolling window
       * Matching ExtJS: chart.series[0].addPoint({x, y}, true, true)
       * Third parameter true = shift (remove oldest point)
       */
      addSessionsDataPoint(sessions) {
        const now = Date.now()

        // Add new point
        this.sessionsData.push({
          timestamp: now,
          sessions,
        })

        // Shift out oldest point (maintain 7 points total)
        if (this.sessionsData.length > 7) {
          this.sessionsData.shift()
        }
      },
    },
  }
</script>
