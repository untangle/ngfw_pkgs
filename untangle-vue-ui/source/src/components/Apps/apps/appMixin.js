import { mapGetters } from 'vuex'
import { getReportUrl, getReportIcon } from '@/util/reports'
import util from '@/util/util'
import Util from '@/util/setupUtil'
import Rpc from '@/util/Rpc'
import { EVENT_ACTIONS } from '@/constants/actions'
import { sendEvent } from '@/utils/event'

export default {
  data() {
    return {
      appManager: null, // Cached app manager instance for RPC calls
      toggling: false, // Local state to track if app is currently toggling (starting/stopping)
      settings: undefined, // App settings loaded from backend
      saveDisabled: false, // Flag to disable save button on settings error
    }
  },

  provide() {
    return {
      isReportsInstalled: this.isReportsInstalled,
      isRestricted: this.isRestricted,
    }
  },

  inject: ['embedded'],

  /**
   * Common computed properties and methods related to app management, metrics, and reports integration.
   * Can be overridden in individual app components as needed, but provides a shared baseline implementation for all apps
   * to reduce code duplication and ensure consistent behavior across app components.
   */
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
     * Check if the license instance is restricted
     * @returns {Boolean} True if restricted, else false
     */
    isRestricted: () => !!util.isRestricted(),

    /**
     * Power state of the app, derived from Vuex store with local toggling state overlay
     * @returns {Object} Power state object with 'on' boolean and 'toggling' boolean
     */
    powerState: ({ appData, appManager, getAppPowerState, toggling }) => {
      const vuexPowerState = getAppPowerState({
        policyId: appData?.policyId,
        appName: appData?.appName,
        appManager,
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
    appReports: ({ $store, appDisplayName }) => {
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
    this.loadAppSettings()
  },

  /**
   * Common methods for app components - toggleAppState, removeApp, initializeSessionsData, loadAppSettings, saveSettings
   * These methods can be overridden or extended in individual app components as needed, but provide a shared baseline implementation
   * for all apps to reduce code duplication and ensure consistent behavior across app components.
   */
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
        this.refreshLicenseStatus()
        if (this.embedded) {
          // Send event to parent window to refresh app status.
          // TODO Remove this once all apps are migrated to Vue UI and Parent Layout is changed
          this.sendEventToParentWindow(EVENT_ACTIONS.REFRESH_APP_STATUS)
        }
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
        if (this.embedded) {
          // If embedded, just send event to parent
          // TODO Remove this once all apps are migrated to Vue UI and Parent Layout is changed
          this.sendEventToParentWindow(EVENT_ACTIONS.REMOVE_APP)
        } else {
          this.$router.push({ name: 'apps', params: { policyId: this.appData?.policyId } })
        }
      } finally {
        this.$store.commit('SET_LOADER', false)
      }
    },

    /**
     * Send event to parent window
     * @param {String} type - Event type from EVENT_ACTIONS
     */
    sendEventToParentWindow(type) {
      const eventData = {
        appName: this.appData?.appName,
        type,
      }

      if (type === EVENT_ACTIONS.REFRESH_APP_STATUS) {
        eventData.targetState = this.powerState.on ? 'RUNNING' : 'INITIALIZED'
      }

      sendEvent(eventData)
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

    /**
     * Load app settings from backend via RPC call to app manager
     * @returns {Promise} Resolves when settings are loaded and stored in component state
     */
    loadAppSettings() {
      this.$store.commit('SET_LOADER', true)
      Rpc.asyncData(this.appManager, 'getSettingsV2')
        .then(settings => {
          this.settings = settings
        })
        .catch(error => {
          Util.handleException(error, 'Failed to load app settings')
        })
        .finally(() => {
          this.$store.commit('SET_LOADER', false)
        })
    },

    /**
     * Save app settings to backend via RPC call to app manager
     * @param {Object} newSettings - Settings object to save
     * @returns {Promise} Resolves when settings are saved and reloaded, or rejects on error
     */
    saveSettings(newSettings) {
      this.$store.commit('SET_LOADER', true)
      Rpc.asyncData(this.appManager, 'setSettingsV2', newSettings)
        .then(() => {
          this.loadAppSettings()
        })
        .catch(error => {
          this.saveDisabled = true
          Util.handleException(error, 'Failed to save app settings')
        })
        .finally(() => {
          this.$store.commit('SET_LOADER', false)
        })
    },

    /**
     * Refresh app data - reload settings and app view data.
     * Triggers computed properties (powerState and appReports) to update with latest data.
     * Also refreshes license status in case app state change affects licensing.
     */
    refreshData() {
      this.refreshLicenseStatus()
      this.loadAppSettings()
      this.$store.dispatch('apps/getAppsView', this.appData?.policyId)
    },

    /**
     * Emit event to refresh license status in parent component
     */
    refreshLicenseStatus() {
      this.$emit('refreshLicenseStatus')
    },
  },
}
