import { set } from 'vue'
import { cloneDeep } from 'lodash'
import Util from '@/util/setupUtil'
import vuntangle from '@/plugins/vuntangle'

const getDefaultState = () => ({
  editCallback: null,
  networkSetting: null,
})

const getters = {
  networkSetting: state => state.networkSetting || [],
  interfaces: state => state?.networkSetting?.interfaces || [],
  interface: state => device => {
    return state.networkSetting?.interfaces?.find(intf => intf.device === device)
  },
}

const mutations = {
  setEditCallback(state, cb) {
    state.editCallback = cb
  },
  SET_INTERFACES: (state, value) => set(state.networkSetting, 'interfaces', value),
  SET_NETWORK_SETTINGS: (state, value) => set(state, 'networkSetting', value),
}

const actions = {
  async getInterfaces({ commit }) {
    try {
      const data = await window.rpc.networkManager.getNetworkSettingsV2().interfaces
      commit('SET_INTERFACES', await data)
    } catch (err) {
      console.error('getInterfaces error:', err)
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
      console.error('getNetworkSettings error:', err)
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
      console.error('setInterfaces error:', err)
    }
  },

  /**
   * Updates a single interface
   * The save process works like:
   * - apply changes to the edited interface
   * - then save the entire set of interfaces
   */
  async setInterface({ state, dispatch }, intf) {
    const interfaces = cloneDeep(state.networkSetting.interfaces)
    // Find the interface to update
    const updatedInterface = interfaces.find(i => i.interfaceId === intf.interfaceId)
    // apply changes made to the interface
    if (updatedInterface) {
      Object.assign(updatedInterface, { ...intf })
    } else {
      interfaces.push(intf)
    }
    // Save updated interface list
    return await dispatch('setNetworkSettingV2', { interfaces })
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
  deleteInterface({ state, dispatch }, intf) {
    try {
      const networkSettings = cloneDeep(state.networkSetting)
      const interfaces = cloneDeep(state.networkSetting.interfaces)
      const index = interfaces.findIndex(i => i.interfaceId === intf.interfaceId)

      /* Selected interfaces will be removed from the list of interfaces */
      if (index >= 0) {
        interfaces.splice(index, 1)
      }
      networkSettings.interfaces = interfaces
      return new Promise(resolve => {
        window.rpc.networkManager.setNetworkSettingsV2(async ex => {
          if (ex) {
            Util.handleException(ex)
            return resolve({ success: false, message: ex?.toString()?.slice(0, 100) || 'Unknown error' })
          }
          // force a full settings load
          await Promise.allSettled([dispatch('getNetworkSettings', true)])
          return resolve({ success: true })
        }, networkSettings)
      })
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
