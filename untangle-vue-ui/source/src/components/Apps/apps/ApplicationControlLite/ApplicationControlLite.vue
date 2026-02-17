<template>
  <application-control-lite
    :settings="settings"
    :icon-path="iconPath"
    :loading="loading"
    :sessions-data="sessionsData"
    :metrics-data="formattedMetrics"
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
  import Rpc from '@/util/Rpc'

  export default {
    name: 'ApplicationControlLiteApp',

    components: {
      ApplicationControlLite,
    },

    data() {
      return {
        appName: 'application-control-lite',
        loading: false,
        sessionsData: this.generateDummySessionsData(),
        metrics: this.generateDummyMetrics(),
        metricsPollingInterval: null,
        liveSessionsInterval: null,
      }
    },

    computed: {
      /**
       * Settings from Vuex store
       */
      settings() {
        return this.$store.getters['apps/getSettings'](this.appName)?.settings || {}
      },

      /**
       * Icon path using webpack require
       */
      iconPath() {
        try {
          return require(`@/assets/icons/apps/${this.appName}.svg`)
        } catch (e) {
          return null
        }
      },

      /**
       * Formatted metrics for the metrics grid
       */
      formattedMetrics() {
        if (!this.metrics) return []

        return Object.entries(this.metrics).map(([key, value]) => ({
          key,
          value,
          formatter: this.getMetricFormatter(key),
        }))
      },
    },

    async created() {
      await this.loadAppData()
      // Start polling with dummy data updates
      this.startMetricsPolling()
      // Simulate live sessions updates
      this.startLiveSessionsSimulation()
    },

    beforeDestroy() {
      this.stopMetricsPolling()
      this.stopLiveSessionsSimulation()
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
          console.error('Failed to load app data:', err)
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
          // Get app instance from store
          const appData = this.$store.state.apps?.appsData?.[this.appName]
          if (!appData?.instance?.id) {
            throw new Error('App instance ID not found')
          }

          await Rpc.asyncData('rpc.appManager.destroy', appData.instance.id)
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
       * Refresh data (reload settings and metrics)
       */
      refreshData() {
        this.loadAppData()
        this.fetchMetrics()
      },

      /**
       * Fetch metrics from backend
       */
      async fetchMetrics() {
        if (!this.appName || !this.settings) return

        try {
          const metricsData = await Rpc.asyncData('rpc.metricManager.getMetricsAndStats', this.appName)

          this.metrics = metricsData?.stats || {}

          if (metricsData?.liveSessions !== undefined) {
            this.updateSessionsData(metricsData.liveSessions)
          }
        } catch (err) {
          console.error('Failed to fetch metrics:', err)
        }
      },

      /**
       * Update sessions chart data
       */
      updateSessionsData(currentSessions) {
        const now = Date.now()
        const tenMinutesAgo = now - 10 * 60 * 1000

        this.sessionsData.push({
          timestamp: now,
          sessions: currentSessions,
        })

        // Remove data older than 10 minutes
        this.sessionsData = this.sessionsData.filter(d => d.timestamp > tenMinutesAgo)
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
       * Start live sessions simulation (updates every 10 seconds)
       */
      startLiveSessionsSimulation() {
        this.liveSessionsInterval = setInterval(() => {
          const now = Date.now()
          const tenMinutesAgo = now - 10 * 60 * 1000

          // Add new data point
          const newSessions = Math.floor(Math.random() * 50) + 10 // Random between 10-60
          this.sessionsData.push({
            timestamp: now,
            sessions: newSessions,
          })

          // Update live sessions metric
          this.metrics.liveSessions = newSessions

          // Remove data older than 10 minutes
          this.sessionsData = this.sessionsData.filter(d => d.timestamp > tenMinutesAgo)
        }, 10000) // Every 10 seconds
      },

      /**
       * Stop live sessions simulation
       */
      stopLiveSessionsSimulation() {
        if (this.liveSessionsInterval) {
          clearInterval(this.liveSessionsInterval)
          this.liveSessionsInterval = null
        }
      },

      /**
       * Get custom formatter for specific metrics
       */
      getMetricFormatter(key) {
        // Format session counts with thousand separators
        if (key.toLowerCase().includes('sessions') || key.toLowerCase().includes('requests')) {
          return value => value.toLocaleString()
        }

        // Format bytes as human-readable
        if (key.toLowerCase().includes('bytes')) {
          return value => this.formatBytes(value)
        }

        return null
      },

      /**
       * Format bytes to human-readable format
       */
      formatBytes(bytes) {
        if (bytes === 0) return '0 Bytes'

        const k = 1024
        const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB']
        const i = Math.floor(Math.log(bytes) / Math.log(k))

        return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i]
      },

      /**
       * Generate dummy sessions data for the chart (last 10 minutes)
       */
      generateDummySessionsData() {
        const now = Date.now()
        const data = []

        // Generate 60 data points (1 per 10 seconds for 10 minutes)
        for (let i = 59; i >= 0; i--) {
          const timestamp = now - i * 10 * 1000 // 10 seconds apart
          const sessions = Math.floor(Math.random() * 50) + 10 // Random between 10-60
          data.push({ timestamp, sessions })
        }

        return data
      },

      /**
       * Generate dummy metrics data
       */
      generateDummyMetrics() {
        return {
          liveSessions: 42,
          scannedSessions: 15234,
          blockedSessions: 856,
          flaggedSessions: 342,
          passedSessions: 14378,
          scannedBytes: 8589934592, // ~8.59 GB
          blockedRequests: 1024,
          flaggedRequests: 512,
        }
      },
    },
  }
</script>
