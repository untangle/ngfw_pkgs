import { set } from 'vue'
// import api from '@/plugins/api'
import Util from '@/util/setupUtil'

const getDefaultState = () => ({
  settings: {
    network: {
      interfaces: [],
    },
  },
})

const getters = {
  settings: state => state.settings,
  interfaces: state => state.settings?.network?.interfaces || [],

  interface: state => device => {
    return state.settings.network.interfaces.find(intf => intf.device === device)
  },
}

const mutations = {
  SET_INTERFACES: (state, value) => set(state.settings.network, 'interfaces', value),
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
}

export default {
  namespaced: true,
  state: getDefaultState,
  getters,
  mutations,
  actions,
}
