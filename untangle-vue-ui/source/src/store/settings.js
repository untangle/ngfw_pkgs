import cloneDeep from 'lodash/cloneDeep'
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
  settings: state => state.settings || [],
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
      console.log('InterfaceWithStatus :', interfaceWithStatus)
      commit('SET_INTERFACES_STATUSES', interfaceWithStatus)
    } catch (err) {
      console.error('getInterfaces error:', err)
      Util.handleException(err)
    }
  },
  // async getInterfaceWithStatus(_, { device }) {
  //   try {
  //     const rpc = await Util.setRpcJsonrpc('admin')
  //     const interfacesList = rpc.networkManager.getNetworkSettings().interfaces.list
  //     const interfaceStatusList = rpc.networkManager.getInterfaceStatus().list
  //     const intf = interfacesList.find(j => j.physicalDev === device)
  //     const interfaceStatus = interfaceStatusList.find(i => i.interfaceId === intf.interfaceId)
  //     return { ...intf, ...interfaceStatus }
  //   } catch (err) {
  //     console.error('getInterfaces error:', err)
  //     Util.handleException(err)
  //   }
  // },
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
   * Interfaces are bulk updated
   * The save process works like:
   * - apply changes to the edited interface
   * - then save the entire set of interfaces
   */
  async setInterface({ state }, intf) {
    try {
      const rpc = await Util.setRpcJsonrpc('admin')

      const interfaces = cloneDeep(state.settings.network.interfaces)
      console.log('**********')
      const updatedInterface = interfaces.find(i => i.interfaceId === intf.interfaceId)
      console.log('**********')

      // apply changes made to the interface
      if (updatedInterface) {
        Object.assign(updatedInterface, { ...intf })
      } else {
        interfaces.push(intf)
      }
      console.log('****interfaces******', interfaces)
      // post new interfaces data
      const response = await rpc.networkManager.setNetworkSettings(interfaces)
      console.log('response setInterface:', response)
      return true
    } catch (ex) {
      Util.handleException(ex)
      return false
    }
  },

  // updates all interfaces
  async setInterfaces(interfaces) {
    try {
      const rpc = await Util.setRpcJsonrpc('admin')
      const response = rpc.networkManager.getNetworkSettings.setInterface(interfaces)
      console.log('response setInterfaces:', response)
      return true
    } catch (ex) {
      Util.handleException(ex)
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
