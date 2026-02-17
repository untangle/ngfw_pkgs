import { set } from 'vue'
import Util from '@/util/setupUtil'

/**
 * Constants for app installation status
 * @readonly
 * @enum {string}
 */
export const APP_INSTALL_STATUS = Object.freeze({
  PROGRESS: 'progress', // App is currently being installed
  FINISH: 'finish', // App installation completed successfully
  ERROR: 'error', // App installation failed
})

/**
 * Why do we need a Bootstrap Registry?
 *
 * The Bootstrap Registry defines API calls that are automatically invoked
 * when a screen loads or when a refresh operation is triggered, without
 * any specific user interaction.
 *
 * For example:
 * - The `smtp` app requires multiple API calls (safelists, inbox data, etc.)
 *   to fully initialize its UI when the screen loads.
 *   These bootstrap calls happen automatically to prepare the view.
 *
 * - Other apps (e.g. dynamic-blocklist) only need basic settings
 *   and do not require additional bootstrap entries.
 *
 * Important:
 * - This registry contains ONLY auto-load/refresh APIs
 * - APIs triggered by specific user actions (button clicks, form submissions)
 *   should NOT be added here
 *
 * Benefits:
 * - Centralizes initial data loading logic per app
 * - Keeps API logic organized and extensible
 * - Allows different apps to have different bootstrap requirements
 * - Clear separation between auto-load and user-triggered operations
 */
const APP_BOOTSTRAP_REGISTRY = {
  smtp: [
    {
      key: 'globalSafeList',
      call: app => app.getSafelistAdminView().getSafelistContents('GLOBAL'),
    },
    {
      key: 'userSafeList',
      call: app => app.getSafelistAdminView().getUserSafelistCountsV2(),
    },
    {
      key: 'inboxSummary',
      call: app => app.getQuarantineMaintenenceView().listInboxesV2(),
    },
  ],
}

/**
 * Apps store
 */
const getDefaultState = () => ({
  store: {}, // all app settings stored by appName
  appViews: null, // list of per-policy app view states (kept for backward compatibility)
  appViewsByPolicy: {}, // normalized app views by policyId for O(1) lookup
  installingApps: {}, // tracks apps currently being installed { appName: { policyId, status } }
  selectedPolicyId: null, // currently selected policy ID
  autoInstallApps: false, // tracks if recommended apps are being auto-installed on initial setup
})

/**
 * Getters
 */
const getters = {
  /**
   * Get settings for a given app name.
   * Usage: getters.getSettings('http')
   */
  getSettings: state => appName => state.store[appName] || null,
  /**
   * Get all app views (list of per-policy app view states)
   * Usage: getters['apps/appViews']
   */
  appViews: state => state.appViews || [],
  /**
   * Get all app views normalized by policyId (O(1) lookup)
   * Usage: getters['apps/appViewsByPolicy']
   */
  appViewsByPolicy: state => state.appViewsByPolicy || {},
  /**
   * Get app view for a specific policy (O(1) lookup)
   * Usage: getters['apps/getAppViewByPolicy'](policyId)
   */
  getAppViewByPolicy: state => policyId => state.appViewsByPolicy[policyId] || null,
  /**
   * Get installing apps
   * Usage: getters['apps/installingApps']
   */
  installingApps: state => state.installingApps || {},
  /**
   * Check if a specific app is installing
   * Usage: getters['apps/isAppInstalling'](appName)
   */
  isAppInstalling: state => appName => {
    const installing = state.installingApps[appName]
    return installing ? installing.status === 'progress' : false
  },
  /**
   * Get selected policy ID
   * Usage: getters['apps/selectedPolicyId']
   */
  selectedPolicyId: state => state.selectedPolicyId,
  /**
   * Check if auto install is currently running
   * Usage: getters['apps/autoInstallApps']
   */
  autoInstallApps: state => state.autoInstallApps,
}

const mutations = {
  /**
   * Dynamically set settings for an app
   * Usage: commit('SET_SETTINGS', { appName: 'http', value: data })
   */
  SET_SETTINGS(state, { appName, value }) {
    if (!state.store) {
      set(state, 'store', {})
    }
    set(state.store, appName, value)
  },
  /**
   * Set the list of app views for all policies
   * Usage: commit('SET_APP_VIEWS', appViews)
   */
  SET_APP_VIEWS: (state, appViews) => {
    set(state, 'appViews', appViews)
    // Normalize appViews by policyId for O(1) lookup
    const normalized = (appViews || []).reduce((acc, view) => {
      acc[view.policyId] = view
      return acc
    }, {})
    set(state, 'appViewsByPolicy', normalized)
  },
  /**
   * Set the app view for a specific policy
   * Usage: commit('SET_APP_VIEW', { policyId, appView })
   */
  SET_APP_VIEW: (state, { policyId, appView }) => {
    // Update array (backward compatibility)
    if (!state.appViews) {
      set(state, 'appViews', [])
    }
    const index = state.appViews.findIndex(av => String(av.policyId) === policyId)
    if (index >= 0) {
      state.appViews.splice(index, 1, appView)
    } else {
      state.appViews.push(appView)
    }
    // Update normalized object (O(1) lookup)
    if (!state.appViewsByPolicy) {
      set(state, 'appViewsByPolicy', {})
    }
    set(state.appViewsByPolicy, policyId, appView)
  },
  /**
   * Set app installation status
   * Usage: commit('SET_APP_INSTALL_STATUS', { appName: 'web-filter', policyId: 1, status: 'progress' })
   * Status can be: 'progress', 'finish', or null (to clear)
   */
  SET_APP_INSTALL_STATUS(state, { appName, policyId, status }) {
    if (!state.installingApps) {
      set(state, 'installingApps', {})
    }
    if (status === null) {
      // Clear the installation status
      const newInstallingApps = { ...state.installingApps }
      delete newInstallingApps[appName]
      set(state, 'installingApps', newInstallingApps)
    } else {
      set(state.installingApps, appName, { policyId, status })
    }
  },
  /**
   * Set selected policy ID
   * Usage: commit('SET_SELECTED_POLICY_ID', policyId)
   */
  SET_SELECTED_POLICY_ID(state, policyId) {
    set(state, 'selectedPolicyId', policyId)
  },
  /**
   * Set auto install apps flag
   * Usage: commit('SET_AUTO_INSTALL_APPS', true/false)
   */
  SET_AUTO_INSTALL_APPS(state, value) {
    set(state, 'autoInstallApps', value)
  },
}

/**
 * Actions
 */
const actions = {
  async getApp(_, appName) {
    try {
      const app = await window.rpc.appManager.app(appName)
      return app
    } catch (err) {
      Util.handleException(err)
      return null
    }
  },
  /**
   * Get settings for a given app using getSettingsV2().
   * @param {string} appName - The name of the app (e.g., 'smtp', 'http')
   * @param {Object|null} app - Optional app object. If not provided, it will be fetched via getApp
   * @returns {Promise<Object|null>} The app settings object or null if app is unavailable
   *
   * Usage:
   * - With app object: dispatch('getAppSettings', { appName: 'smtp', app: appObject })
   * - Without app object: dispatch('getAppSettings', { appName: 'smtp' })
   */
  async getAppSettings({ dispatch }, { appName, app = null }) {
    if (!app) {
      app = await dispatch('getApp', appName)
    }
    if (app) {
      return await app.getSettingsV2()
    }
    return null
  },
  /**
   * Load initial/bootstrap data for an app.
   * This includes the app's canonical settings plus any bootstrap APIs defined in APP_BOOTSTRAP_REGISTRY.
   * Typically called when a screen loads or when refresh is triggered.
   *
   * @param {string} appName - The name of the app (e.g., 'smtp')
   * @returns {Promise<Object>} Object containing settings and all bootstrap data
   */
  async loadAppData({ commit, dispatch }, appName) {
    const registry = APP_BOOTSTRAP_REGISTRY[appName]
    const app = await dispatch('getApp', appName)
    if (!app) return

    // ALWAYS load canonical backend settings
    const baseSettings = (await dispatch('getAppSettings', { appName, app })) || {}

    const result = { settings: baseSettings }

    // Optionally argument with bootstrap registry data
    if (registry) {
      for (const item of registry) {
        try {
          const value = await item.call(app)
          result[item.key] = value
        } catch (err) {
          result[item.key] = null
        }
      }
    }

    commit('SET_SETTINGS', { appName, value: result })
    return result
  },

  async setAppSettings({ dispatch }, { appName, settings }) {
    if (!settings) return
    const app = await dispatch('getApp', appName)
    if (!app) return

    return new Promise(resolve => {
      app.setSettingsV2(async (ex, res) => {
        if (ex || res?.code) {
          Util.handleException(ex || res.message)
          return resolve({ success: false })
        }

        await dispatch('loadAppData', appName)
        resolve({ success: true })
      }, settings)
    })
  },

  /**
   * Gets the app views for all policies.
   * @param {*} param0  commit
   * @returns Promise that resolves to the list of app views
   */
  getAppViews({ state, commit }, refetch) {
    try {
      if (state.appViews && !refetch) {
        return
      }
      const data = window.rpc.appManager.getAppsViewsV2()
      commit('SET_APP_VIEWS', data || [])
    } catch (err) {
      Util.handleException(err)
    }
  },

  /**
   * Gets the app views for policy with given Id.
   * Updates the appViews state with the fetched data.
   * @param {*} param0 commit
   * @param {*} policyId
   */
  getAppView({ commit }, policyId) {
    try {
      const data = window.rpc.appManager.getAppsViewV2(policyId)
      commit('SET_APP_VIEW', { policyId, appView: data || [] })
    } catch (err) {
      Util.handleException(err)
    }
  },

  /**
   * Install an app for a specific policy
   * @param {Object} context - Vuex context
   * @param {Object} payload - { appName, policyId }
   * @returns {Promise<Object>} - { success: boolean, instance?: Object, error?: string }
   */
  async installApp({ commit, dispatch }, { appName, policyId }) {
    try {
      // Set installing status to 'progress'
      commit('SET_APP_INSTALL_STATUS', { appName, policyId, status: 'progress' })

      // Call RPC to instantiate app
      const instance = await new Promise(resolve => {
        window.rpc.appManager.instantiate(
          res => {
            resolve(res)
          },
          appName,
          policyId,
        )
      })

      // Refresh app views to get updated data
      await dispatch('getAppViews', true)
      // Set installing status to 'finish'
      commit('SET_APP_INSTALL_STATUS', { appName, policyId, status: 'finish' })

      return { success: true, instance }
    } catch (error) {
      // Clear installing status on error
      commit('SET_APP_INSTALL_STATUS', { appName, policyId, status: null })
      Util.handleException(error)
      return { success: false, error: error.message || 'Installation failed' }
    }
  },

  /**
   * Check if auto install is currently running
   * Fetches the isAutoInstallAppsFlag from backend and updates state
   * @param {Object} context - Vuex context
   * @returns {boolean} - true if auto install is running, false otherwise
   */
  checkAutoInstallFlag({ commit }) {
    try {
      const isAutoInstalling = window.rpc.appManager.isAutoInstallAppsFlag()
      commit('SET_AUTO_INSTALL_APPS', isAutoInstalling)
      return isAutoInstalling
    } catch (err) {
      Util.handleException(err)
      commit('SET_AUTO_INSTALL_APPS', false)
      return false
    }
  },

  /**
   * Make a registry API call for a specific bootstrap API by key.
   * Looks up the registry for the given app and API key, then makes the corresponding API call.
   * Patches the result into the store, preserving existing data for other keys.
   *
   * @param {Object} context - Vuex context
   * @param {Object} payload - { appName, apiKey }
   * @param {string} payload.appName - The name of the app (e.g., 'smtp')
   * @param {string} payload.apiKey - The key from APP_BOOTSTRAP_REGISTRY (e.g., 'globalSafeList')
   * @returns {Promise<any>} - The result of the API call, or null if registry entry not found
   *
   * Usage:
   * dispatch('makeRegistryCall', { appName: 'smtp', apiKey: 'globalSafeList' })
   */
  async makeRegistryCall({ state, commit, dispatch }, { appName, apiKey }) {
    const registry = APP_BOOTSTRAP_REGISTRY[appName]
    if (!registry) {
      return null
    }

    const registryEntry = registry.find(item => item.key === apiKey)
    if (!registryEntry) {
      return null
    }

    const app = await dispatch('getApp', appName)
    if (!app) return null

    try {
      const result = await registryEntry.call(app)

      // Get existing settings for this app
      const existingSettings = state.store[appName] || {}

      // Merge the new result with existing settings
      const updatedSettings = {
        ...existingSettings,
        [apiKey]: result,
      }

      // Commit the merged settings to the store
      commit('SET_SETTINGS', { appName, value: updatedSettings })

      return result
    } catch (err) {
      Util.handleException(err)
      return null
    }
  },
}

export default {
  namespaced: true,
  state: getDefaultState,
  getters,
  mutations,
  actions,
}
