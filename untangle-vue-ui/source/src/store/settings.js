// import cloneDeep from 'lodash/cloneDeep'
import { set } from 'vue'
// import api from '@/plugins/api'
import Util from '@/util/setupUtil'

const getDefaultState = () => ({
  settings: {
    network: {
      interfaces: [],
      interfaceStatuses: [],
    },
  },
})

const getters = {
  settings: state => state.settings.network || [],
  interfaces: state => state.settings?.network?.interfaces || [],
  interfaceStatuses: state => state.settings?.network?.interfaceStatuses || [],

  interface: state => device => {
    return state.settings.network.interfaces.find(intf => intf.physicalDev === device)
  },
}

const mutations = {
  SET_INTERFACES: (state, value) => set(state.settings.network, 'interfaces', value),
  SET_INTERFACES_STATUSES: (state, value) => set(state.settings.network, 'interfaceStatuses', value),
  SET_SETTINGS: (state, value) => set(state.settings, 'settings', value),
}

const actions = {
  async getInterfaces({ commit }) {
    try {
      const rpc = await Util.setRpcJsonrpc('admin')
      const data = rpc.networkManager.getNetworkSettings().interfaces.list
      commit('SET_INTERFACES', data)
    } catch (err) {
      console.error('getInterfaces error:', err)
    }
  },
  async getInterfaceStatuses({ commit }) {
    try {
      const rpc = await Util.setRpcJsonrpc('admin')
      const interfaces = rpc.networkManager.getNetworkSettings().interfaces.list
      const intfStatusList = rpc.networkManager.getInterfaceStatus()
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
      const rpc = await Util.setRpcJsonrpc('admin')
      const data = rpc.networkManager.getNetworkSettings()
      commit('SET_SETTINGS', data)
    } catch (err) {
      console.error('getNetworkSettings error:', err)
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
      const rpc = await Util.setRpcJsonrpc('admin')
      const settings = state.settings.settings
      const updatedIntf = settings.interfaces.list.find(i => i.interfaceId === updatedInterface.interfaceId)
      Object.keys(updatedIntf).forEach(key => {
        if (Object.prototype.hasOwnProperty.call(updatedInterface, key)) {
          updatedIntf[key] = updatedInterface[key]
        }
      })
      await rpc.networkManager.setNetworkSettings(settings)
      return true
    } catch (ex) {
      Util.handleException(ex)
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
