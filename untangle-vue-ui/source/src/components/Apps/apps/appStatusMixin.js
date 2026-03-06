import { mapGetters } from 'vuex'
import { getReportUrl, getReportIcon } from '@/util/reports'
import util from '@/util/util'

export default {
  data() {
    return {
      appManager: null,
      appSettings: null,
      loadingState: false,
      toggling: false,
    }
  },

  provide() {
    return {
      isReportsInstalled: this.isReportsInstalled,
    }
  },

  computed: {
    ...mapGetters('metrics', ['getFormattedMetrics', 'getLiveSessions']),
    ...mapGetters('apps', ['getAppPowerState']),

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
      if (!this.powerState?.on) return []
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

    /**
     * Get computed power state from Vuex
     * Merges Vuex state with local toggling state
     */
    powerState() {
      const vuexPowerState = this.getAppPowerState({
        policyId: this.appData?.policyId,
        appName: this.appName,
        appManager: this.appManager,
      })

      return {
        ...vuexPowerState,
        power: this.toggling, // Override with local toggling state
      }
    },
  },

  /**
   * Created lifecycle hook
   * Caches app manager and refreshes runtime state
   */
  async created() {
    if (!this.appData?.instance?.id) return

    try {
      this.appManager = await this.$store.dispatch('apps/getAppById', {
        appId: this.appData.instance.id,
      })
    } catch (err) {
      // Fallback to heavy getAppView call if needed
      this.$store.dispatch('apps/getAppView', this.appData.policyId)
    }
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

    /**
     * Toggle app state (start/stop)
     * @param {boolean} enabled - Target state (true = starting, false = stopping)
     */
    async toggleAppState(enabled) {
      if (!this.appManager) return
      this.toggling = true

      try {
        const rpcMethod = enabled ? 'start' : 'stop'

        await new Promise((resolve, reject) => {
          this.appManager[rpcMethod]((ex, res) => {
            if (ex || res?.code) {
              reject(ex || new Error(res?.message || `Failed to ${rpcMethod} app`))
            } else {
              resolve(res)
            }
          })
        })
        this.$store.dispatch('apps/getAppViews', true)
      } finally {
        this.toggling = false
      }
    },
  },
}
