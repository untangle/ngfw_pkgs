import { mapGetters } from 'vuex'
import { getReportUrl, getReportIcon } from '@/util/reports'
import util from '@/util/util'

export default {
  data() {
    return {
      appInstance: null,
      appSettings: null,
      loadingState: false,
    }
  },

  provide() {
    return {
      isReportsInstalled: this.isReportsInstalled,
    }
  },

  computed: {
    ...mapGetters('metrics', ['getFormattedMetrics', 'getLiveSessions']),

    /**
     * App display name for reports filtering
     * Must be overridden in component
     */
    appDisplayName() {
      throw new Error('appDisplayName must be defined in component for reports filtering')
    },

    /**
     * Instance ID for metrics lookup
     * Override in component to provide actual instanceId from appData
     */
    instanceId() {
      return this.appData?.instance?.id || null
    },

    /**
     * Formatted metrics from Vuex store
     * Returns empty array if instanceId not available (apps without metrics)
     */
    formattedMetrics() {
      if (!this.instanceId) return []
      return this.getFormattedMetrics(this.instanceId) || []
    },

    /**
     * Sessions chart data from Vuex store
     * Returns initial empty data if instanceId not available
     */
    sessionsData() {
      const liveSessions = this.getLiveSessions(this.instanceId)
      if (!this.instanceId || liveSessions === null) {
        return this.initializeSessionsData()
      }
      // Build rolling window with current value
      const now = Date.now()
      const data = []

      for (let i = -6; i <= 0; i++) {
        data.push({
          timestamp: now + i * 10000,
          sessions: i === 0 ? liveSessions : 0,
        })
      }

      return data
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
      // TODO Remove Util Method Call Once Reports App and its flows are Fully Migrated
      return this.$store.getters['reports/isReportsInstalled'] || !!util.isReportsInstalled()
    },
  },

  methods: {
    /**
     * Initialize sessions chart with 7 zero points
     * Creates baseline data for chart display when no metrics available yet
     */
    initializeSessionsData() {
      const data = []
      const now = Date.now()
      const roundedNow = Math.round(now / 1000) * 1000

      for (let i = -6; i <= 0; i++) {
        data.push({
          timestamp: roundedNow + i * 10000,
          sessions: 0,
        })
      }

      return data
    },
  },
}
