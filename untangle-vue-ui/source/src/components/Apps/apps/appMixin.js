import { mapGetters } from 'vuex'
import { getReportUrl, getReportIcon } from '@/util/reports'
import util from '@/util/util'

export default {
  data() {
    return {
      appManager: null, // Cached app manager instance for RPC calls
      toggling: false, // Local state to track if app is currently toggling (starting/stopping)
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
     * App display name for reports filtering. Must be overridden in component.
     * @throws Error if not defined in component
     */
    appDisplayName: () => {
      throw new Error('appDisplayName must be defined in component for reports filtering')
    },

    // App Instance ID.
    instanceId: ({ appData }) => appData?.instance?.id || null,

    /**
     * Check if Reports app is installed
     * @returns {Boolean} True if reports is installed, else false
     * TODO Remove Util Method Call Once Reports App and its flows are Fully Migrated
     */
    isReportsInstalled: ({ $store }) => $store.getters['reports/isReportsInstalled'] || !!util.isReportsInstalled(),

    /**
     * Power state of the app, derived from Vuex store with local toggling state overlay
     * @returns {Object} Power state object with 'on' boolean and 'toggling' boolean
     */
    powerState: ({ appData, getAppPowerState, toggling }) => {
      const vuexPowerState = getAppPowerState({
        policyId: appData?.policyId,
        appName: appData?.appName,
        appManager: appData?.appManager,
      })

      return {
        ...vuexPowerState,
        power: toggling,
      }
    },

    /**
     * Get reports for this app from global store
     * Filters by appDisplayName and transforms to UI format
     * @returns {Array} - Formatted reports array
     */
    appReports: ({ appDisplayName, $store }) => {
      if (!appDisplayName) return []

      const rawReports = $store.getters['reports/getReportsByCategory'](appDisplayName)

      return rawReports.map(report => ({
        key: report.uniqueId,
        label: report.title || report.uniqueId,
        url: getReportUrl(report.category, report.title),
        icon: getReportIcon(report.type),
      }))
    },

    /**
     * Formatted metrics for this app instance from Vuex store
     * @param {String} instanceId - App instance ID for metrics lookup
     * @returns {Array} - Formatted metrics array or empty array if no instanceId
     */
    formattedMetrics: ({ instanceId, getFormattedMetrics }) => (instanceId ? getFormattedMetrics(instanceId) : []),

    /**
     * Sessions chart data from Vuex store
     * Returns initial empty data if instanceId not available
     */
    sessionsData() {
      if (!this.powerState?.on) return []
      // If instanceId not available yet, return initialized sessions data with zeros to populate chart baseline
      if (!this.instanceId) {
        return this.initializeSessionsData()
      }
      const liveSessions = this.getLiveSessions(this.instanceId)
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
  },

  async created() {
    if (!this.appData?.instance?.id) return
    this.appManager = await this.$store.dispatch('apps/getAppById', {
      appId: this.appData.instance.id,
    })
  },

  methods: {
    /**
     * Toggle app state. Starts or stops the app based on the 'enabled' parameter.
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
        this.$store.dispatch('apps/getAppsViews', true)
      } finally {
        this.toggling = false
      }
    },

    /**
     * Remove/Uninstall the app
     */
    async removeApp() {
      this.$store.commit('SET_LOADER', true)
      try {
        await this.$store.dispatch('apps/destroyApp', {
          instanceId: this.appData?.instance?.id,
          policyId: this.appData?.policyId,
        })
        this.$router.push({ name: 'apps', params: { policyId: this.appData?.policyId } })
      } finally {
        this.$store.commit('SET_LOADER', false)
      }
    },

    /**
     * Initialize sessions chart with 7 zero points
     * Creates baseline data for chart display when no metrics available yet
     * @returns {Array} Array of 7 data points with timestamps and zero sessions
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
