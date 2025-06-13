// import cloneDeep from 'lodash/cloneDeep'
import { set } from 'vue'
import Util from '@/util/setupUtil'
import vuntangle from '@/plugins/vuntangle'

const getDefaultState = () => ({
  editCallback: null,
  networkSetting: {
    interfaces: [],
    interfaceStatuses: [],
  },
  dynamicLists: {},
})

const getters = {
  networkSetting: state => state.networkSetting || [],
  interfaces: state => state?.networkSetting?.interfaces || [],
  interfaceStatuses: state => state?.networkSetting?.interfaceStatuses || [],
  interface: state => device => {
    return state.networkSetting.interfaces.find(intf => intf.physicalDev === device)
  },
  dynamicLists: state => state.dynamicLists || [],
}

const mutations = {
  setEditCallback(state, cb) {
    state.editCallback = cb
  },
  SET_INTERFACES: (state, value) => set(state.networkSetting, 'interfaces', value),
  SET_INTERFACES_STATUSES: (state, value) => set(state.networkSetting, 'interfaceStatuses', value),
  SET_NETWORK_SETTINGS: (state, value) => set(state, 'networkSetting', value),
  SET_DYNAMIC_LISTS: (state, value) => {
    state.dynamicLists = { dynamicLists: value }
  },
}

const actions = {
  async getInterfaces({ commit }) {
    try {
      const data = await window.rpc.networkManager.getNetworkSettings().interfaces.list
      const sortedData = await [...data].sort((a, b) => a.interfaceId - b.interfaceId)
      commit('SET_INTERFACES', sortedData)
    } catch (err) {
      console.error('getInterfaces error:', err)
    }
  },
  async getInterfaceStatuses({ commit }) {
    try {
      const interfaces = await window.rpc.networkManager.getNetworkSettings().interfaces.list
      const intfStatusList = await window.rpc.networkManager.getInterfaceStatus()
      const interfaceWithStatus = interfaces.map(intf => {
        const status = intfStatusList.list.find(j => j.interfaceId === intf.interfaceId)
        return { ...intf, ...status }
      })
      commit('SET_INTERFACES_STATUSES', interfaceWithStatus)
    } catch (err) {
      console.error('getInterfaces error:', err)
      Util.handleException(err)
    }
  },
  async getNetworkSettings({ commit }) {
    try {
      const data = await window.rpc.networkManager.getNetworkSettings()
      commit('SET_NETWORK_SETTINGS', data)
    } catch (err) {
      console.error('getNetworkSettings error:', err)
    }
  },
  async setNetworkSettings({ commit }, settings) {
    try {
      await window.rpc.networkManager.setNetworkSettings(settings)
      vuntangle.toast.add('Network settings saved successfully!')
      const data = window.rpc.networkManager.getNetworkSettings()
      commit('SET_SETTINGS', data)
    } catch (err) {
      Util.handleException(err)
    }
  },
  async getDynamicBlockList({ commit }) {
    try {
      const data = await window.rpc.appManager.app('dynamic-blocklists').getSettings()
      commit('SET_DYNAMIC_LISTS', data)
    } catch (err) {
      console.error('getDynamicBlockList error:', err)
    }
  },
  async saveDynamicLists({ commit }, data) {
    try {
      await window.rpc.appManager.app('dynamic-blocklists').setSettings(data, true)
      const response = await window.rpc.appManager.app('dynamic-blocklists').getSettings()
      commit('SET_DYNAMIC_LISTS', response)
      return { success: true }
    } catch (ex) {
      Util.handleException(ex)
      return { success: false }
    }
  },
  async startDynamicLists({ commit }, data) {
    try {
      await window.rpc.appManager.app('dynamic-blocklists').setSettings(data, false)
      await window.rpc.appManager.app('dynamic-blocklists').start()
      const response = await window.rpc.appManager.app('dynamic-blocklists').getSettings()
      commit('SET_DYNAMIC_LISTS', response)
      return { success: true }
    } catch (ex) {
      Util.handleException(ex)
      return { success: false }
    }
  },
  async stopDynamicLists({ commit }, data) {
    try {
      await window.rpc.appManager.app('dynamic-blocklists').setSettings(data, true)
      await window.rpc.appManager.app('dynamic-blocklists').stop()
      const response = await window.rpc.appManager.app('dynamic-blocklists').getSettings()
      commit('SET_DYNAMIC_LISTS', response)
      return { success: true }
    } catch (ex) {
      Util.handleException(ex)
      return { success: false }
    }
  },
  async runJobsByConfigIds({ commit }, data) {
    try {
      const response = await window.rpc.appManager.app('dynamic-blocklists').runJobsByConfigIds(data)
      commit('SET_DYNAMIC_LISTS', response)
      return { success: true }
    } catch (ex) {
      Util.handleException(ex)
      return { success: false }
    }
  },
  async getdynamicListsDefaultSettings({ commit }) {
    try {
      const data = await window.rpc.appManager.app('dynamic-blocklists').onResetDefaults()
      console.log('SET STOP RESPONSE : ', data)
      commit('SET_DYNAMIC_LISTS', data)
      return { success: true }
    } catch (ex) {
      Util.handleException(ex)
      return { success: false }
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
        return await window.rpc.networkManager.setNetworkSettings({
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

      await window.rpc.networkManager.setNetworkSettings({
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
      await window.rpc.networkManager.setNetworkSettings(settings)
      vuntangle.toast.add('Successfully saved interface remapping.')
    } catch (ex) {
      vuntangle.toast.add('Rolling back settings to previous version.')
      Util.handleException(ex)
    }
  },
  // Delete selected Interface and update all interfaces
  deleteInterfaces({ state }, interfaces) {
    try {
      const fullSettings = JSON.parse(JSON.stringify(state.networkSetting))

      fullSettings.interfaces = {
        javaClass: 'java.util.LinkedList',
        list: interfaces.map(intf => ({
          ...intf,
          javaClass: 'com.untangle.uvm.network.InterfaceSettings',
        })),
      }

      return new Promise((resolve, reject) => {
        window.rpc.networkManager.setNetworkSettings((response, exception) => {
          if (Util.isDestroyed(this)) return

          if (exception) {
            Util.handleException(exception)
            return reject(exception)
          }

          resolve(response)
        }, fullSettings)
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
