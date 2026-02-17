export default {
  data() {
    return {
      appInstance: null,
      appSettings: null,
      metrics: null,
      sessionsData: [],
      metricsPollingInterval: null,
      loadingState: false,
      loadingMetrics: false,
    }
  },

  computed: {
    appName() {
      throw new Error('appName must be defined in component')
    },

    isAppRunning() {
      return this.appSettings?.enabled || false
    },

    formattedMetrics() {
      if (!this.metrics) return []

      return Object.entries(this.metrics).map(([key, value]) => ({
        key,
        value,
        formatter: this.getMetricFormatter(key),
      }))
    },
  },

  created() {
    this.loadAppData()
    this.startMetricsPolling()
  },

  beforeDestroy() {
    this.stopMetricsPolling()
  },

  methods: {
    loadAppData() {
      this.loadingState = true
      try {
        // For now, mock the app instance and settings
        // TODO: Replace with actual store dispatches when available
        this.appInstance = {
          appId: this.appName,
          displayName: this.$t(this.appName),
        }

        // Mock settings
        this.appSettings = {
          enabled: false,
        }
      } catch (err) {
        console.error('Failed to load app data:', err)
        this.$vuntangle.toast.add(this.$t('failed_to_load_app_data'), 'error')
      } finally {
        this.loadingState = false
      }
    },

    fetchMetrics() {
      if (!this.appInstance) return

      this.loadingMetrics = true
      try {
        // Mock metrics data for now
        // TODO: Replace with actual RPC call
        const metricsData = {
          liveSessions: Math.floor(Math.random() * 100),
          totalSessions: Math.floor(Math.random() * 1000),
          blockedSessions: Math.floor(Math.random() * 50),
        }

        this.metrics = metricsData

        if (metricsData.liveSessions !== undefined) {
          this.updateSessionsData(metricsData.liveSessions)
        }
      } catch (err) {
        console.error('Failed to fetch metrics:', err)
      } finally {
        this.loadingMetrics = false
      }
    },

    updateSessionsData(currentSessions) {
      const now = Date.now()
      const tenMinutesAgo = now - 10 * 60 * 1000

      this.sessionsData.push({
        timestamp: now,
        sessions: currentSessions,
      })

      // Remove data older than 10 minutes
      this.sessionsData = this.sessionsData.filter(d => d.timestamp > tenMinutesAgo)

      // Limit to max 60 data points (10 minutes at 10-second intervals)
      if (this.sessionsData.length > 60) {
        this.sessionsData = this.sessionsData.slice(-60)
      }
    },

    startMetricsPolling() {
      this.fetchMetrics() // Immediate fetch
      this.metricsPollingInterval = setInterval(() => {
        this.fetchMetrics()
      }, 10000) // 10 seconds
    },

    stopMetricsPolling() {
      if (this.metricsPollingInterval) {
        clearInterval(this.metricsPollingInterval)
        this.metricsPollingInterval = null
      }
    },

    toggleAppState() {
      this.loadingState = true
      try {
        const newSettings = {
          ...this.appSettings,
          enabled: !this.appSettings.enabled,
        }

        // TODO: Replace with actual store dispatch
        this.appSettings = newSettings

        this.$vuntangle.toast.add(this.$t(newSettings.enabled ? 'app_started' : 'app_stopped'), 'success')
      } catch (err) {
        console.error('Failed to toggle app state:', err)
        this.$vuntangle.toast.add(this.$t('failed_to_toggle_app'), 'error')
      } finally {
        this.loadingState = false
      }
    },

    removeApp() {
      this.loadingState = true
      try {
        // TODO: Replace with actual RPC call
        setTimeout(() => {
          this.$vuntangle.toast.add(this.$t('app_removed'), 'success')

          // Redirect to apps page
          this.$router.push({ name: 'apps' })
          this.loadingState = false
        }, 1000)
      } catch (err) {
        console.error('Failed to remove app:', err)
        this.$vuntangle.toast.add(this.$t('failed_to_remove_app'), 'error')
        this.loadingState = false
      }
    },

    getMetricFormatter(_key) {
      // Override in component for custom formatting
      console.log('No formatter defined for metric key:', _key)
      return null
    },

    getReportsList() {
      // Override in component
      return []
    },
  },
}
