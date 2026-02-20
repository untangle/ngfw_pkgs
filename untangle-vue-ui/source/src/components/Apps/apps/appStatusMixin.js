import { getReportUrl, getReportIcon } from '@/util/reports'

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
    /**
     * App display name for reports filtering
     * Must be overridden in component
     */
    appDisplayName() {
      throw new Error('appDisplayName must be defined in component for reports filtering')
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

    /**
     * Get reports for this app from global store
     * Filters by appDisplayName and transforms to UI format
     * @returns {Array} - Formatted reports array
     */
    appReports() {
      if (!this.appDisplayName) {
        return []
      }

      const rawReports = this.$store.getters['reports/getReportsByCategory'](this.appDisplayName)

      return rawReports.map(report => ({
        key: report.uniqueId,
        label: report.title || report.uniqueId,
        url: getReportUrl(report.category, report.title),
        icon: getReportIcon(report.type),
      }))
    },

    /**
     * Check if Reports app is installed
     * @returns {Boolean}
     */
    isReportsInstalled() {
      return this.$store.getters['reports/isReportsInstalled']
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
        this.$vuntangle.toast.add(this.$t('failed_to_remove_app'), 'error')
        this.loadingState = false
      }
    },

    getMetricFormatter(_key) {
      // Override in component for custom formatting
      console.log(`No custom formatter for metric key: ${_key}`)
      return null
    },

    /**
     * Get reports list
     * @deprecated Use computed property 'appReports' instead
     * @returns {Array}
     */
    getReportsList() {
      return this.appReports
    },
  },
}
