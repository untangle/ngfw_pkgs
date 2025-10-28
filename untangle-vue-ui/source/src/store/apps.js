import { set } from 'vue'
import Util from '@/util/setupUtil'

const getDefaultState = () => ({
  settings: {}, // all app settings stored by appName
})

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

const actions = {
  getApp(context, appName) {
    return window.rpc.appManager.app(appName)
  },

  async getAppSettings({ dispatch }, appName) {
    const app = await dispatch('getApp', appName)
    if (app) {
      return await app.getSettingsV2()
    }
    return null
  },

  /* setAppSettings will update system regarding configurations */
  async setAppSettings({ dispatch }, { appName, settings }) {
    if (!settings) {
      return
    }
    try {
      const app = await dispatch('getApp', appName)
      if (!app) {
        return
      }
      const result = await new Promise(resolve => {
        app.setSettingsV2(async (ex, res) => {
          if (ex) return resolve({ success: false, message: ex?.toString()?.slice(0, 100) || 'Unknown error' })
          if (res?.code && res?.message) return resolve({ success: false, message: res.message.slice(0, 100) })

          // Fetch updated settings after successful save
          await dispatch('getAndCommitAppSettings', appName)

          return resolve({ success: true })
        }, settings)
      })

      // Handle RPC-level errors (optional logging)
      if (!result.success) {
        Util.handleException(result.message)
      }

      return result
    } catch (err) {
      Util.handleException(err)
      return { success: false, message: err?.toString()?.slice(0, 100) || 'Unknown error' }
    }
  },

  async getAndCommitAppSettings({ commit, dispatch }, appName) {
    try {
      const data = await dispatch('getAppSettings', appName)
      commit('SET_SETTINGS', { appName, value: data })
      return { success: true, data }
    } catch (err) {
      Util.handleException(err)
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
