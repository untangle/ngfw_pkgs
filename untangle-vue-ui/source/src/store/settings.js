import { set } from 'vue'
import { cloneDeep } from 'lodash'
import Util from '@/util/setupUtil'
import vuntangle from '@/plugins/vuntangle'

const getDefaultState = () => ({
  editCallback: null,
  networkSetting: {
    interfaces: [],
  },
})

const getters = {
  networkSetting: state => state.networkSetting || [],
  interfaces: state => state?.networkSetting?.interfaces || [],
  interface: state => device => {
    return state.networkSetting.interfaces.find(intf => intf.device === device)
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
  async getNetworkSettings({ commit }) {
    try {
      const data = await window.rpc.networkManager.getNetworkSettingsV2()
      commit('SET_NETWORK_SETTINGS', data)
    } catch (err) {
      console.error('getNetworkSettings error:', err)
    }
  },
  async setNetworkSettings({ commit }, settings) {
    try {
      await window.rpc.networkManager.setNetworkSettingsV2(settings)
      vuntangle.toast.add('Network settings saved successfully!')
      const data = window.rpc.networkManager.getNetworkSettingsV2()
      commit('SET_NETWORK_SETTINGS', data)
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
  setInterface({ state, dispatch }, intf) {
    const interfaces = cloneDeep(state.networkSetting.interfaces)
    // Find the interface to update
    const updatedInterface = interfaces.find(i => i.interfaceId === intf.interfaceId)
    // apply changes made to the interface
    if (updatedInterface) {
      Object.assign(updatedInterface, { ...intf })
    } else {
      interfaces.push(intf)
    }
    const payload = {
      interfaces,
      javaClass: 'com.untangle.uvm.network.generic.NetworkSettingsGeneric',
    }
    // Save updated interface list
    return new Promise(resolve => {
      window.rpc.networkManager.setNetworkSettingsV2(async (ex, result) => {
        if (Util.isDestroyed(this, interfaces)) {
          return
        }
        if (ex) {
          Util.handleException(ex)
          return resolve({ success: false, message: ex?.toString()?.slice(0, 100) || 'Unknown error' })
        }
        if (result?.code && result?.message) {
          return resolve({
            success: false,
            message: result.message.slice(0, 100),
          })
        }
        await Promise.allSettled([dispatch('getInterfaces')])
        return resolve({ success: true })
      }, payload)
    })
  },
  // update all interfaces

  async setInterfaces({ state }, interfaces) {
    try {
      if (Util.isDestroyed(this, interfaces)) {
        return
      }
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
          if (Util.isDestroyed(this, networkSettings)) {
            return
          }
          if (ex) {
            Util.handleException(ex)
            return resolve({ success: false, message: ex?.toString()?.slice(0, 100) || 'Unknown error' })
          }
          // force a full settings load
          await Promise.allSettled([dispatch('getNetworkSettings')])
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
