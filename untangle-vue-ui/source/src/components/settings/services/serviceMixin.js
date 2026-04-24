import { mapGetters } from 'vuex'
import { getReportUrl, getReportIcon } from '@/util/reports'
import util from '@/util/util'
import uris from '@/util/uris'
import { EVENT_ACTIONS } from '@/constants/actions'
import { sendEvent } from '@/utils/event'

export default {
  inject: ['embedded'],

  data() {
    return {
      isLicensed: undefined,
      manageLicenseUri: undefined,
      appManager: null,
      instanceId: null,
      toggling: false,
      // Controls whether app settings are loaded via getSettingsV2 RPC on mount.
      // Set to false in components whose appManager does not support getSettingsV2 (e.g. LiveSupport).
      hasAppSettings: true,
      displayNameFallback: '',
    }
  },

  provide() {
    return {
      isReportsInstalled: this.isReportsInstalled,
    }
  },

  computed: {
    ...mapGetters('apps', ['getServiceAppStatus']),
    ...mapGetters('metrics', ['getFormattedMetrics']),

    formattedMetrics: ({ instanceId, getFormattedMetrics }) => (instanceId ? getFormattedMetrics(instanceId) : []),

    // Get the apps view for the selected policy from the store
    appsViewByPolicy: ({ $store }) => $store.getters['apps/getAppsViewByPolicy'](1),

    // Determine if the app is currently installed based on the apps view for the selected policy
    isInstalled() {
      return this.appsViewByPolicy?.instances?.some(i => i.appName === this.serviceName) ?? false
    },

    settings: ({ $store, licenseNodeName }) => $store.getters['apps/getSettings'](licenseNodeName)?.settings || {},

    /**
     * Check if Reports app is installed
     * @returns {Boolean} True if reports is installed, else false
     * TODO Remove Util Method Call Once Reports App and its flows are Fully Migrated
     */
    isReportsInstalled: ({ $store }) => $store.getters['reports/isReportsInstalled'] || !!util.isReportsInstalled(),

    /**
     * Display name sourced from the app manager; falls back to displayNameFallback set by each component.
     * @returns {string}
     */
    appDisplayName: ({ appManager, displayNameFallback }) =>
      appManager?.getAppProperties?.()?.displayName || displayNameFallback,

    /**
     * Bundles powerState, appDisplayName, and iconPath into the shape expected by u-app-status-state.
     * @returns {{ powerState: Object, appDisplayName: string, iconPath: string|null }}
     */
    consolidatedAppData: ({ powerState, appDisplayName, iconPath }) => ({
      powerState: powerState || {},
      appDisplayName,
      iconPath,
    }),

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
     * Icon path for the app using webpack require
     * @returns {string|null} Icon path or null if appName is not available
     */
    iconPath: ({ serviceName }) => (serviceName ? require(`@/assets/icons/apps/${serviceName}.svg`) : null),

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
    await this.setAppManager()
    const app = await this.$store.dispatch('apps/getApp', { appName: this.licenseNodeName })
    this.appManager = app || null
    await this.loadInstanceId()
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
     * Fetches the app instance ID from the app manager and stores it in the component's state.
     * Used to link metrics polling to the correct app instance via formattedMetrics.
     * Called on initial load and after reinstall to ensure instanceId stays current.
     */
    async loadInstanceId() {
      if (!this.appManager) return
      try {
        const appSettings = await this.appManager.getAppSettings()
        this.instanceId = appSettings?.id || null
      } catch (err) {
        util.handleException(err)
      }
    },

    /**
     * Fetches the app manager instance for the licensed app and stores it in the component's state.
     * This allows the component to interact with the app manager for operations like starting/stopping the app and fetching settings.
     */
    async setAppManager() {
      const app = await this.$store.dispatch('apps/getApp', { appName: this.licenseNodeName })
      this.appManager = app || null
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
      if (!this.hasAppSettings) return
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

    /** Installs the apps */
    async onInstallService() {
      this.$store.commit('SET_LOADER', true)
      try {
        await this.$store.dispatch('apps/installApp', { appName: this.serviceName })
        await this.setAppManager()
        await this.loadInstanceId()
        await this.checkLicense()
        await this.loadAppSettings()
        await this.$store.dispatch('reports/loadReports')
      } catch (error) {
      } finally {
        this.$store.commit('SET_LOADER', false)
      }
    },

    /**
     * Handles the removal of the service app. It first sets a loader state to true, then finds the app instance
     * corresponding to the serviceName in the current policy's apps view. It dispatches an action to destroy the app instance,
     * and if the component is embedded, it sends an event to the parent indicating that the app has been removed. Finally, it sets the loader state back to false.
     */
    async onRemoveService() {
      this.$store.commit('SET_LOADER', true)
      try {
        const instance = this.appsViewByPolicy?.instances?.find(i => i.appName === this.serviceName)
        await this.$store.dispatch('apps/destroyApp', {
          instanceId: instance?.id,
          policyId: 1,
        })
        if (this.embedded) {
          // If embedded, just send event to parent
          // TODO Remove this once all apps are migrated to Vue UI and Parent Layout is changed
          sendEvent({ type: EVENT_ACTIONS.REMOVE_APP, appName: this.serviceName })
        }
      } catch (error) {
      } finally {
        this.$store.commit('SET_LOADER', false)
      }
    },
  },
}
