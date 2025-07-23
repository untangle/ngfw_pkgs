// import cloneDeep from 'lodash/cloneDeep'
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
  async setInterface({ state }, updatedInterface) {
    try {
      if (Util.isDestroyed(this, updatedInterface)) return

      const settings = state.networkSetting
      const interfaces = Array.isArray(settings.interfaces) ? settings.interfaces : []

      const updatedIntf = interfaces.find(i => i.interfaceId === updatedInterface.interfaceId)
      //     // Handle new interface creation
      if (!updatedIntf) {
        const updatedInterfaces = [...interfaces, updatedInterface]
        return await window.rpc.networkManager.setNetworkSettingsV2({
          ...settings,
          interfaces: {
            javaClass: 'java.util.LinkedList',
            list: updatedInterfaces.map(intf => ({
              ...intf,
              javaClass: 'com.untangle.uvm.network.InterfaceSettings',
            })),
          },
        })
      }

      // Update in place
      Object.keys(updatedIntf).forEach(key => {
        if (Object.prototype.hasOwnProperty.call(updatedInterface, key)) {
          updatedIntf[key] = updatedInterface[key]
        }
      })

      await window.rpc.networkManager.setNetworkSettingsV2({
        ...settings,
        interfaces: {
          javaClass: 'java.util.LinkedList',
          list: settings.interfaces.map(intf => ({
            ...intf,
            javaClass: 'com.untangle.uvm.network.InterfaceSettings',
          })),
        },
      })

      await vuntangle.toast.add('Network settings saved successfully!')
    } catch (ex) {
      vuntangle.toast.add('Rolling back settings to previous version.')
      Util.handleException(ex)
    }
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
      const interfaces = cloneDeep(state.networkSetting.interfaces)
      const index = interfaces.findIndex(i => i.interfaceId === intf.interfaceId)

      /* Selected interfaces will be removed from the list of interfaces */
      if (index >= 0) {
        interfaces.splice(index, 1)
      }
      return new Promise(resolve => {
        window.rpc.networkManager.setNetworkSettingsV2(async ex => {
          if (Util.isDestroyed(this, interfaces)) {
            return
          }
          if (ex) {
            Util.handleException(ex)
            return resolve({ success: false, message: ex?.toString()?.slice(0, 100) || 'Unknown error' })
          }
          // force a full settings load
          await Promise.allSettled([dispatch('getNetworkSettings')])
          return resolve({ success: true })
        }, interfaces)
      })
    } catch (err) {
      Util.handleException(err)
      return false
    }
  },

  /**
   * Check if settings are rolled back due to some reason
   * Return the reason to present in the toast.
   */
  settingsRollBackReason(response) {
    const condition = 'rolled_back_settings'
    const output = response?.data?.output || ''
    if (output.includes(condition)) {
      const conditionIndex = output.indexOf(condition)
      let errMessage = ''
      if (conditionIndex !== -1) {
        const startIndex = conditionIndex + condition.length
        const endIndex = output.indexOf('\n', startIndex)

        // Extract the substring
        const result =
          endIndex === -1 ? output.substring(startIndex).trim() : output.substring(startIndex, endIndex).trim()

        errMessage = result
      }
      return errMessage
    }
    return null
  },
}

export default {
  namespaced: true,
  state: getDefaultState,
  getters,
  mutations,
  actions,
}
