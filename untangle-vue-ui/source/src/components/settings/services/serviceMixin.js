import { mapGetters } from 'vuex'
import { getReportUrl, getReportIcon } from '@/util/reports'
import util from '@/util/util'
import uris from '@/util/uris'
import { EVENT_ACTIONS } from '@/constants/actions'
import { sendEvent } from '@/utils/event'

export default {
  data() {
    return {
      isLicensed: undefined,
      manageLicenseUri: undefined,
      appManager: null,
      toggling: false,
      // Controls whether app settings are loaded via getSettingsV2 RPC on mount.
      // Set to false in components whose appManager does not support getSettingsV2 (e.g. LiveSupport).
      hasAppSettings: true,
    }
  },

  provide() {
    return {
      isReportsInstalled: this.isReportsInstalled,
    }
  },

  inject: ['embedded'],

  computed: {
    ...mapGetters('apps', ['getServiceAppStatus']),

    settings: ({ $store, licenseNodeName }) => $store.getters['apps/getSettings'](licenseNodeName)?.settings || {},

    /**
     * Check if Reports app is installed
     * @returns {Boolean} True if reports is installed, else false
     * TODO Remove Util Method Call Once Reports App and its flows are Fully Migrated
     */
    isReportsInstalled: ({ $store }) => $store.getters['reports/isReportsInstalled'] || !!util.isReportsInstalled(),

    powerState: ({ appManager, getServiceAppStatus, toggling }) => {
      const vuexPowerState = getServiceAppStatus({
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
  },

  async created() {
    this.checkLicense()
    this.getManageLicenseUri()
    const app = await this.$store.dispatch('apps/getApp', { appName: this.licenseNodeName })
    this.appManager = app || null
    if (this.hasAppSettings) {
      this.loadAppSettings()
    }
    if (!this.$store.getters['reports/isLoaded'] && !this.$store.getters['reports/loading']) {
      this.$store.dispatch('reports/loadReports')
    }
  },

  methods: {
    /**
     * Refresh app data - reload settings.
     */
    refreshData() {
      this.loadAppSettings()
    },

    /**
     * Save app settings via Vuex dispatch
     * @param {Object} newSettings - Settings object to save
     */
    async saveSettings(newSettings) {
      this.$store.commit('SET_LOADER', true)
      try {
        await this.$store.dispatch('apps/setAppSettings', {
          appName: this.licenseNodeName,
          settings: newSettings,
        })
      } catch (error) {
        util.handleException(error)
      } finally {
        this.$store.commit('SET_LOADER', false)
      }
    },

    /**
     * Load app settings from backend via RPC call to app manager and store in Vuex
     */
    loadAppSettings() {
      this.$store.commit('SET_LOADER', true)
      this.$store
        .dispatch('apps/loadAppData', {
          appName: this.licenseNodeName,
          app: this.appManager,
        })
        .finally(() => {
          this.$store.commit('SET_LOADER', false)
        })
    },

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
        // Re-fetch so getRunState() reflects the updated state
        const app = await this.$store.dispatch('apps/getApp', { appName: this.licenseNodeName })
        this.appManager = app || this.appManager
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
     * Send event to parent window
     * @param {String} type - Event type from EVENT_ACTIONS
     */
    sendEventToParentWindow(type) {
      const eventData = {
        appName: this.licenseNodeName,
        type,
      }

      if (type === EVENT_ACTIONS.REFRESH_APP_STATUS) {
        eventData.targetState = this.powerState.on ? 'RUNNING' : 'INITIALIZED'
      }

      sendEvent(eventData)
    },

    /**
     * PROP: is-licensed
     * Checks for TP license status
     */
    async checkLicense() {
      if (!this.licenseNodeName) return
      this.isLicensed = await this.$store.dispatch('apps/checkLicenseStatus', this.licenseNodeName)
    },

    /**
     * PROP: manage-license-uri
     * Fetches the URI for license management
     */
    async getManageLicenseUri() {
      this.manageLicenseUri = await this.$store.dispatch('apps/fetchManageLicenseUri', uris.list.subscriptions)
    },

    /**
     * Check if a specific app's license is valid
     * @param {String} appName - The app name to check
     * @returns {Boolean} true if license is valid, false otherwise
     */
    isAppLicenseValid(appName) {
      return this.$store.dispatch('apps/checkAppLicense', appName)
    },
    /**
     * Check if a daemon is running
     * @param {String} daemonName - The daemon name to check
     * @returns {Boolean} true if daemon is running, false otherwise
     */
    isDaemonRunning(daemonName) {
      return this.$store.dispatch('apps/checkDaemonStatus', daemonName)
    },
  },
}
