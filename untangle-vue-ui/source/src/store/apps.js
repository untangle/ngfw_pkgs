import { set } from 'vue'
import Util from '@/util/setupUtil'
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
 * Apps store
 */
const getDefaultState = () => ({
  store: {}, // all app settings stored by appName
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
}

/**
 * Actions
 */
const actions = {
  async setSmtpSettingsWOSafeList({ dispatch }, smtpSettings) {
    const app = await dispatch('getApp', 'smtp')
    if (!app) return
    return new Promise(resolve => {
      app.setSmtpSettingsWithoutSafelistsV2((ex, res) => {
        if (ex || res?.code) {
          Util.handleException(ex || res.message)
          return resolve({ success: false })
        }
        resolve({ success: true })
      }, smtpSettings)
    })
  },
  async setGlobalSafeList({ dispatch }, safeList) {
    const app = await dispatch('getApp', 'smtp')
    if (!app) return
    return app
      .getSafelistAdminView()
      .replaceSafelist('GLOBAL', safeList)
      .then(res => {
        return { success: true, data: res }
      })
      .catch(err => {
        Util.handleException(err?.message || err?.cause || 'Unknown error occurred')
        return { success: false, error: err }
      })
  },

  async deleteSafelists({ dispatch }, userSafeList) {
    const app = await dispatch('getApp', 'smtp')
    if (!app) return
    return new Promise(resolve => {
      app.getSafelistAdminView().deleteSafelists((ex, res) => {
        if (ex || res?.code) {
          Util.handleException(ex || res.message)
          return resolve({ success: false })
        }
        resolve({ success: true })
      }, userSafeList)
    })
  },

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
}

export default {
  namespaced: true,
  state: getDefaultState,
  getters,
  mutations,
  actions,
}
