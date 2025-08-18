import { set } from 'vue'
import { cloneDeep } from 'lodash'
import Util from '@/util/setupUtil'
import vuntangle from '@/plugins/vuntangle'

const getDefaultState = () => ({
  editCallback: null,
  networkSetting: {
    interfaces: [],
  },
  systemSetting: null,
  enabledWanInterfaces: [],
})

const getters = {
  networkSetting: state => state.networkSetting || [],
  interfaces: state => state?.networkSetting?.interfaces || [],
  interface: state => device => {
    return state.networkSetting?.interfaces?.find(intf => intf.device === device)
  },
  systemSetting: state => state.systemSetting || {},
  enabledWanInterfaces: state => state.enabledWanInterfaces,
}

const mutations = {
  setEditCallback(state, cb) {
    state.editCallback = cb
  },
  SET_INTERFACES: (state, value) => set(state.networkSetting, 'interfaces', value),
  SET_NETWORK_SETTINGS: (state, value) => set(state, 'networkSetting', value),
  SET_SYSTEM_SETTINGS: (state, value) => set(state, 'systemSetting', value),
  SET_ENABLED_WAN_INTERFACES: (state, value) => set(state, 'enabledWanInterfaces', value),
}

const actions = {
  async getInterfaces({ commit }) {
    try {
      const data = await window.rpc.networkManager.getNetworkSettingsV2().interfaces
      commit('SET_INTERFACES', await data)
    } catch (err) {
      Util.handleException(err)
    }
  },

  async getNetworkSettings({ state, commit }, refetch) {
    try {
      if (state.networkSetting && !refetch) {
        return
      }
      const data = await window.rpc.networkManager.getNetworkSettingsV2()
      commit('SET_NETWORK_SETTINGS', data)
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
   * Updates a single interface
   * The save process works like:
   * - apply changes to the edited interface
   * - then save the entire set of interfaces
   */
  async setInterface({ state, dispatch }, intf) {
    const networkSettings = cloneDeep(state.networkSetting)
    // Find the interface to update
    const updatedInterface = networkSettings.interfaces.find(i => i.interfaceId === intf.interfaceId)
    // apply changes made to the interface
    if (updatedInterface) {
      Object.assign(updatedInterface, { ...intf })
    } else {
      networkSettings.interfaces.push(intf)
    }
    // Save updated interface list
    return await dispatch('setNetworkSettingV2', networkSettings)
  },

  // update all interfaces
  async setInterfaces({ state }, interfaces) {
    try {
      const settings = state.networkSetting
      settings.interfaces.list = interfaces
      const vlanInterfaces = settings.interfaces.filter(intf => intf.isVlanInterface)
      await window.rpc.networkManager.setNetworkSettingsV2({
        ...settings,
        interfaces: {
          javaClass: 'java.util.LinkedList',
          list: [...interfaces, ...vlanInterfaces].map(intf => ({
            ...intf,
            javaClass: 'com.untangle.uvm.network.InterfaceSettings',
          })),
        },
      })
      vuntangle.toast.add('Successfully saved interface remapping.')
    } catch (ex) {
      vuntangle.toast.add('Rolling back settings to previous version.')
      Util.handleException(ex)
    }
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
}

export default {
  namespaced: true,
  state: getDefaultState,
  getters,
  mutations,
  actions,
}
