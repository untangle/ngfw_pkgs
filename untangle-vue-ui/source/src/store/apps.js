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
 * Why do we need an RPC Registry?
 *
 * The RPC registry centralizes all runtime API calls required to build
 * complete application settings without permanently storing large or
 * infrequently used data in Vuex/state.
 *
 * For example:
 * - The `smtp` app requires multiple API calls (settings, safelists,
 *   inbox data, company name, etc.) to fully initialize its UI.
 *   Instead of storing all this data upfront, we load it dynamically
 *   at runtime using this registry.
 *
 * - Other apps (e.g. dynamic-blocklist) only need basic get/set settings
 *   calls and do not require additional registry entries.
 *
 * Benefits:
 * - Reduces storage/state size by avoiding unnecessary persistence
 * - Loads only what is required for a specific app
 * - Keeps API logic organized and extensible per app
 * - Allows different apps to have different initialization needs
 *
 * In short, the registry defines *what extra data* an app needs at runtime
 * beyond its canonical backend settings.
 */
const APP_RPC_REGISTRY = {
  smtp: [
    {
      key: 'smtpSettings',
      call: app => app.getSettingsV2(),
    },
    {
      key: 'globalSafeList',
      call: app => app.getSafelistAdminView().getSafelistContents('GLOBAL'),
    },
    {
      key: 'userSafeList',
      call: app => app.getSafelistAdminView().getUserSafelistCountsV2(),
    },
    {
      key: 'inboxesList',
      call: app => app.getQuarantineMaintenenceView().listInboxes(),
    },
    {
      key: 'inboxesTotalSize',
      call: app => app.getQuarantineMaintenenceView().getInboxesTotalSize(),
    },
  ],
}

/**
 * State
 */
const getDefaultState = () => ({
  settings: {}, // all app settings stored by appName
  appViews: null, // list of per-policy app view states (kept for backward compatibility)
  appViewsByPolicy: {}, // normalized app views by policyId for O(1) lookup
  installingApps: {}, // tracks apps currently being installed { appName: { policyId, status } }
  selectedPolicyId: null, // currently selected policy ID
})

/**
 * Getters
 */
const getters = {
  /**
   * Get settings for a given app name.
   * Usage: getters.getSettings('http')
   */
  getSettings: state => appName => state.settings[appName] || null,
  appViews: state => state.appViews || [], // list of per-policy app view states
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
}

const mutations = {
  /**
   * Dynamically set settings for an app
   * Usage: commit('SET_SETTINGS', { appName: 'http', value: data })
   */
  SET_SETTINGS(state, { appName, value }) {
    if (!state.settings) {
      set(state, 'settings', {})
    }
    set(state.settings, appName, value)
  },
  SET_APP_VIEWS: (state, appViews) => {
    set(state, 'appViews', appViews)
    // Normalize appViews by policyId for O(1) lookup
    const normalized = (appViews || []).reduce((acc, view) => {
      acc[view.policyId] = view
      return acc
    }, {})
    set(state, 'appViewsByPolicy', normalized)
  },
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
}

/**
 * Actions
 */
const actions = {
  setGlobalSafeList(_, safeList) {
    const app = window.rpc.appManager.app('smtp')
    if (!app) return
    return new Promise(resolve => {
      // Wrap callback inside params or try this:
      app
        .getSafelistAdminView()
        .replaceSafelist('GLOBAL', safeList)
        .then(() => {
          resolve({ success: true })
        })
        .catch(() => {
          resolve({ success: false })
        })
    })
  },

  deleteSafelists(_, userSafeList) {
    const app = window.rpc.appManager.app('smtp')
    if (!app) return Promise.resolve({ success: false })
    app.getSafelistAdminView().deleteSafelists(userSafeList)
    return Promise.resolve({ success: true })
  },

  getApp(_, appName) {
    try {
      const app = window.rpc.appManager.app(appName)
      return app
    } catch (err) {
      Util.handleException(err)
      return null
    }
  },
  async getAppSettings({ dispatch }, appName) {
    const app = await dispatch('getApp', appName)
    if (app) {
      return await app.getSettingsV2()
    }
    return null
  },
  async loadAppData({ commit, dispatch }, appName) {
    const registry = APP_RPC_REGISTRY[appName]
    const app = await dispatch('getApp', appName)
    if (!app) return

    // ALWAYS load canonical backend settings
    const baseSettings = (await dispatch('getAppSettings', appName)) || {}

    const result = { ...baseSettings }

    // Optionally augment with registry data
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
      await dispatch('getAppView', policyId)

      // Set installing status to 'finish'
      // Status will be cleared when user navigates to installed apps view
      commit('SET_APP_INSTALL_STATUS', { appName, policyId, status: 'finish' })

      return { success: true, instance }
    } catch (error) {
      // Clear installing status on error
      commit('SET_APP_INSTALL_STATUS', { appName, policyId, status: null })
      Util.handleException(error)
      return { success: false, error: error.message || 'Installation failed' }
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
