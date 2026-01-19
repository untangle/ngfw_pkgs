import { set } from 'vue'
import Util from '@/util/setupUtil'
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
        .replaceSafelistV2('GLOBAL', safeList)
        .then(() => {
          resolve({ success: true })
        })
        .catch(() => {
          resolve({ success: false })
        })
    })
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
}

export default {
  namespaced: true,
  state: getDefaultState,
  getters,
  mutations,
  actions,
}
