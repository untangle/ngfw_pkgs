import { set } from 'vue'
import { cloneDeep } from 'lodash'
import Util from '@/util/setupUtil'
import util from '@/util/util'
import { EVENT_ACTIONS } from '@/constants/actions'
import { sendEvent } from '@/utils/event'

const getDefaultState = () => ({
  editCallback: null,
  networkSetting: null,
  systemSetting: null,
  deviceTemperatureInfo: null,
  enabledWanInterfaces: [],
  uriSettings: null,
  systemTimeZones: [],
  shieldSettings: null,
  languageSettings: null,
  accessRuleSshEnabled: false,
})

const getters = {
  languageSettings: state => state.languageSettings,
  networkSetting: state => state.networkSetting || [],
  interfaces: state => state?.networkSetting?.interfaces || [],
  interface: state => device => {
    return state.networkSetting?.interfaces?.find(intf => intf.device === device)
  },
  systemSetting: state => state.systemSetting || {},
  deviceTemperatureInfo: state => state.deviceTemperatureInfo || {},
  systemTimeZones: state => state.systemTimeZones || [],
  enabledWanInterfaces: state => state.enabledWanInterfaces || [],
  staticRoutes: state => state?.networkSetting?.staticRoutes || [],
  dnsSettings: state => state?.networkSetting?.dnsSettings || {},
  uriSettings: state => state?.uriSettings || {},
  /**
   * Check expert mode is enabled via RPC.
   * Avoids using Rpc.directData method by getting the value directly from window.rpc.
   */
  isExpertMode: () => window?.rpc?.isExpertMode || false,
  dynamicRoutingSettings: state => state?.networkSetting?.dynamicRoutingSettings || {},
  shieldSettings: state => state?.shieldSettings || {},
  accessRuleSshEnabled: state => state.accessRuleSshEnabled,
}

const mutations = {
  setEditCallback(state, cb) {
    state.editCallback = cb
  },
  SET_INTERFACES: (state, value) => set(state.networkSetting, 'interfaces', value),
  SET_NETWORK_SETTINGS: (state, value) => set(state, 'networkSetting', value),
  SET_SYSTEM_SETTINGS: (state, value) => set(state, 'systemSetting', value),
  SET_DEVICE_TEMP_INFO: (state, value) => set(state, 'deviceTemperatureInfo', value),
  SET_SYSTEM_TIMEZONES: (state, value) => set(state, 'systemTimeZones', value),
  SET_ENABLED_WAN_INTERFACES: (state, value) => set(state, 'enabledWanInterfaces', value),
  SET_URI_SETTINGS: (state, value) => set(state, 'uriSettings', value),
  SET_SHIELD_SETTINGS: (state, value) => set(state, 'shieldSettings', value),
  SET_LANGUAGE_SETTINGS: (state, value) => set(state, 'languageSettings', value),
  SET_ACCESS_RULE_SSH_ENABLED: (state, value) => set(state, 'accessRuleSshEnabled', value),
}

const actions = {
  async getLanguageSettings({ commit }) {
    if (!window.rpc || !window.rpc.languageManager) {
      return
    }
    try {
      const data = await window.rpc.languageManager.getLanguageSettings()
      commit('SET_LANGUAGE_SETTINGS', data)
    } catch (err) {
      Util.handleException(err)
    }
  },

  async getInterfaces({ commit }) {
    try {
      const data = await window.rpc.networkManager.getNetworkSettingsV2().interfaces
      commit('SET_INTERFACES', await data)
    } catch (err) {
      Util.handleException(err)
    }
  },

  async getNetworkSettings({ state, commit, dispatch }, refetch) {
    try {
      if (state.networkSetting && !refetch) {
        return
      }
      const data = await window.rpc.networkManager.getNetworkSettingsV2()
      commit('SET_NETWORK_SETTINGS', data)
      dispatch('setAccessRuleSshEnabled')
    } catch (err) {
      Util.handleException(err)
    }
  },

  /* get system settings configuration */
  getSystemSettings({ state, commit }, refetch) {
    try {
      if (state.systemSetting && !refetch) {
        return
      }
      const data = window.rpc.systemManager.getSystemSettingsV2()
      commit('SET_SYSTEM_SETTINGS', data)
      return { success: true, message: null, data } //  success
    } catch (err) {
      Util.handleException(err)
    }
  },

  /* get device temperature information configuration */
  async getDeviceTemperatureInfo({ commit }) {
    try {
      const data = await window.rpc.systemManager.getDeviceTemperatureInfo()
      commit('SET_DEVICE_TEMP_INFO', data)
      return { success: true, message: null, data } //  success
    } catch (err) {
      Util.handleException(err)
    }
  },

  /*
   * Retrieve system timezones and transform them into the list item format
   * required by Vuntangle components.
   */
  getSystemTimeZones({ commit }) {
    try {
      const timeZones = []
      const systemTimeZones = window.rpc.systemManager.getTimeZones()
      const jsonStr = systemTimeZones.replace(/'/g, '"')
      const timezonesArray = JSON.parse(jsonStr)

      if (timezonesArray && Array.isArray(timezonesArray)) {
        for (let i = 0; i < timezonesArray.length; i++) {
          const [zone, offset] = timezonesArray[i]

          const tzObject = {
            text: `(${offset}) ${zone}`,
            value: zone,
          }
          timeZones.push(tzObject)
        }
      }
      commit('SET_SYSTEM_TIMEZONES', timeZones)
      return { success: true, message: null, timeZones }
    } catch (err) {
      Util.handleException(err)
    }
  },

  /*
   * get list of all enabled interfaces
   * it is used in the hostname for listing interface list
   */
  async getEnabledInterfaces({ commit }) {
    try {
      const enabledWanname = ['Default']
      const interfaces = await window.rpc.networkManager.getEnabledInterfaces()
      interfaces.list.forEach(intf => {
        if (intf.isWan) {
          enabledWanname.push(intf.name)
        }
      })
      commit('SET_ENABLED_WAN_INTERFACES', enabledWanname)
      return { success: true, message: null, enabledWanname } //  success
    } catch (err) {
      Util.handleException(err)
    }
  },

  /* setSystemSettings will update system regarding configurations */
  setSystemSettings({ dispatch }, systemSettings) {
    try {
      const data = new Promise(resolve => {
        window.rpc.systemManager.setSystemSettingsV2(async (ex, result) => {
          if (ex) {
            Util.handleException(ex)
            return resolve({ success: false, message: ex?.toString()?.slice(0, 100) || 'Unknown error' })
          }

          if (result?.code && result?.message) {
            Util.handleException(result.message)
            return resolve({ success: false, message: result.message.slice(0, 100) })
          }
          // fetch updated settings after successful save
          await dispatch('getSystemSettings', true)
          sendEvent(EVENT_ACTIONS.REFRESH_SYSTEM_SETTINGS)
          return resolve({ success: true })
        }, systemSettings)
      })
      return data
    } catch (err) {
      Util.handleException(err)
      return { success: false, message: err?.toString()?.slice(0, 100) || 'Unknown error' }
    }
  },
  /**
   * Persists the updated list of network interfaces to the backend using RPC.
   * This action sends a payload to the backend containing all network interfaces
   * and a required Java class identifier. It handles errors from both RPC exceptions
   * and response objects with error codes. On success, it commits the updated interfaces
   * to the Vuex state.
   */
  setNetworkSettingV2({ dispatch }, payload) {
    try {
      payload.javaClass = 'com.untangle.uvm.network.generic.NetworkSettingsGeneric'
      const data = new Promise(resolve => {
        window.rpc.networkManager.setNetworkSettingsV2((ex, result) => {
          if (ex) {
            Util.handleException(ex)
            return resolve({ success: false, message: ex?.toString()?.slice(0, 100) || 'Unknown error' })
          }
          if (result?.code && result?.message) {
            Util.handleException(result.message)
            return resolve({
              success: false,
              message: result.message.slice(0, 100),
            })
          }
          dispatch('getNetworkSettings', true)
          return resolve({ success: true })
        }, payload)
      })
      return data
    } catch (err) {
      Util.handleException(err)
    }
  },
  /**
   * Synchronize the system time using the NTP (Network Time Protocol) service
   */
  async doForceTimeSync() {
    try {
      return await new Promise(resolve => {
        window.rpc.UvmContext.forceTimeSync((ex, result) => {
          if (ex) {
            Util.handleException(ex)
            return resolve({ success: false, message: ex?.toString()?.slice(0, 100) || 'Unknown error' })
          }
          if (result?.code && result?.message) {
            Util.handleException(result.message)
            return resolve({
              success: false,
              message: result.message.slice(0, 100),
            })
          }
          return resolve({ success: true })
        })
      })
    } catch (err) {
      Util.handleException(err)
      return { success: false, message: err?.toString()?.slice(0, 100) || 'Unknown error' }
    }
  },

  /* factory reset */
  factoryReset() {
    try {
      window.rpc.UvmContext.configManager().doFactoryReset()
      return { success: true }
    } catch (err) {
      Util.handleException(err)
      return { success: false, message: err?.toString()?.slice(0, 100) || 'Unknown error' }
    }
  },

  /* reboot */
  reboot() {
    try {
      window.rpc.UvmContext.rebootBox()
      return { success: true }
    } catch (err) {
      Util.handleException(err)
      return { success: false, message: err?.toString()?.slice(0, 100) || 'Unknown error' }
    }
  },

  /* shutdown */
  shutdown() {
    try {
      window.rpc.UvmContext.shutdownBox()
      return { success: true }
    } catch (err) {
      Util.handleException(err)
      return { success: false, message: err?.toString()?.slice(0, 100) || 'Unknown error' }
    }
  },

  /** update all interfaces */
  async setInterfaces({ state, dispatch }, interfaces) {
    const networkSettings = cloneDeep(state.networkSetting)

    interfaces.forEach(intf => {
      const existing = networkSettings.interfaces.find(i => i.interfaceId === intf.interfaceId)
      if (existing) {
        Object.assign(existing, intf) // update existing
      } else {
        networkSettings.interfaces.push(intf) // add new
      }
    })
    // Save updated interface list
    return await dispatch('setNetworkSettingV2', networkSettings)
  },

  /* Delete selected Interface and update all interfaces */
  async deleteInterface({ state, dispatch }, intf) {
    try {
      const networkSettings = cloneDeep(state.networkSetting)
      const index = networkSettings.interfaces.findIndex(i => i.interfaceId === intf.interfaceId)

      /* Selected interfaces will be removed from the list of interfaces */
      if (index >= 0) {
        networkSettings.interfaces.splice(index, 1)
      }
      return await dispatch('setNetworkSettingV2', networkSettings)
    } catch (err) {
      Util.handleException(err)
      return false
    }
  },

  // fetch uri settings
  async getUriSettings({ state, commit }, refetch) {
    try {
      if (state.uriSettings && !refetch) {
        return
      }
      const data = await window.rpc.uriManager.getSettings()
      commit('SET_URI_SETTINGS', data)
    } catch (err) {
      Util.handleException(err)
      return false
    }
  },

  // Fetch Shield Settings
  async getShieldSettings({ state, commit }, refetch) {
    try {
      if (state.shieldSettings && !refetch) {
        return
      }
      const data = await window.rpc.appManager.app('shield').getSettingsV2()
      commit('SET_SHIELD_SETTINGS', data)
    } catch (err) {
      Util.handleException(err)
      return false
    }
  },

  /* setShieldSettings will update system regarding configurations */
  async setShieldSettings({ dispatch }, shieldSettings) {
    try {
      const result = await new Promise(resolve => {
        window.rpc.appManager.app('shield').setSettingsV2(async (ex, res) => {
          if (ex) return resolve({ success: false, message: ex?.toString()?.slice(0, 100) || 'Unknown error' })
          if (res?.code && res?.message) return resolve({ success: false, message: res.message.slice(0, 100) })

          // Fetch updated settings after successful save
          await dispatch('getShieldSettings', true)
          return resolve({ success: true })
        }, shieldSettings)
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

  setAccessRuleSshEnabled({ state, commit }) {
    const accessRules = state?.networkSetting?.access_rules || []
    commit('SET_ACCESS_RULE_SSH_ENABLED', util.getRuleEnabledStatus(accessRules, 'Allow SSH'))
  },
}

export default {
  namespaced: true,
  state: getDefaultState,
  getters,
  mutations,
  actions,
}
